import Foundation

/// Summary of one audio buffer computed by the media layer from actual samples.
public struct AudioContentSummary: Codable, Sendable, Hashable {
    public var peak: Float
    public var rms: Float
    public var isAllZero: Bool
    public var clippedFraction: Float

    public init(peak: Float, rms: Float, isAllZero: Bool, clippedFraction: Float = 0) {
        self.peak = peak
        self.rms = rms
        self.isAllZero = isAllZero
        self.clippedFraction = clippedFraction
    }

    public static let silentNoiseFloor = AudioContentSummary(peak: 0.0008, rms: 0.0002, isAllZero: false)
    public static let allZero = AudioContentSummary(peak: 0, rms: 0, isAllZero: true)
    public static func speech(level: Float = 0.3) -> AudioContentSummary {
        AudioContentSummary(peak: level, rms: level / 4, isAllZero: false)
    }
}

/// Mirrors the platform's frame status so idle is not mistaken for frozen video (T11, T12).
public enum FrameStatus: String, Codable, Sendable {
    case complete, idle, blank, suspended, started, stopped
}

public struct SampleObservation: Sendable, Hashable {
    public var source: SourceKind
    /// Range in source PTS (host-clock based for both capture paths).
    public var range: MediaRange
    public var formatEpoch: Int
    public var audio: AudioContentSummary?
    public var frame: FrameStatus?
    public var byteCount: Int

    public init(source: SourceKind, range: MediaRange, formatEpoch: Int = 0, audio: AudioContentSummary? = nil,
                frame: FrameStatus? = nil, byteCount: Int = 0) {
        self.source = source
        self.range = range
        self.formatEpoch = formatEpoch
        self.audio = audio
        self.frame = frame
        self.byteCount = byteCount
    }
}

public enum SampleVerdict: Equatable, Sendable {
    case accept
    case reject(ReasonCode)
}

/// Current observation for one source, with the reason when not passing.
public struct SourceStatus: Codable, Sendable, Hashable {
    public var source: SourceKind
    public var requirement: SourceRequirement
    public var health: CurrentSourceHealth
    public var reason: ReasonCode?
    /// Seconds since the last real progress, if any progress has been observed.
    public var secondsSinceProgress: Double?
    /// Latest input level (0...1) from real samples, for the optional meter. Nil if unavailable.
    public var inputLevel: Float?
    public var receivedSeconds: Double
    public var hasEverReceived: Bool

    public init(source: SourceKind, requirement: SourceRequirement, health: CurrentSourceHealth, reason: ReasonCode? = nil,
                secondsSinceProgress: Double? = nil, inputLevel: Float? = nil, receivedSeconds: Double = 0, hasEverReceived: Bool = false) {
        self.source = source
        self.requirement = requirement
        self.health = health
        self.reason = reason
        self.secondsSinceProgress = secondsSinceProgress
        self.inputLevel = inputLevel
        self.receivedSeconds = receivedSeconds
        self.hasEverReceived = hasEverReceived
    }
}

/// Per-source evidence. Separates received, accepted and checkpointed coverage (rule 13).
struct SourceMonitor: Sendable {
    let policy: SourcePolicy
    var formatEpoch = 0
    var lastEnd: MediaTime?
    var lastProgressAt: MonotonicInstant?
    var received = CoverageSet()
    var accepted = CoverageSet()
    var checkpointed = CoverageSet()
    var zeroRunSeconds = 0.0
    var zeroRunStart: MediaTime?
    var lastAudio: AudioContentSummary?
    var lastFrame: FrameStatus?
    var awaitingFirstAfterEpoch = false

    init(policy: SourcePolicy) { self.policy = policy }
}

/// HealthVerifier (section 5): fresh per-source evidence plus cumulative anomaly evaluation.
/// It never mutates media and never attributes speakers.
public struct HealthVerifier: Sendable {
    public let contract: CaptureContract
    public let profile: AcceptanceProfile
    public private(set) var ledger = AnomalyLedger()
    /// Session timeline origin: PTS of the first accepted sample from any source.
    public private(set) var timelineOrigin: MediaTime?
    private var monitors: [SourceKind: SourceMonitor] = [:]
    private var captureStartedAt: MonotonicInstant?

    public init(contract: CaptureContract, profile: AcceptanceProfile = .v1) {
        self.contract = contract
        self.profile = profile
        for p in contract.sources { monitors[p.kind] = SourceMonitor(policy: p) }
    }

    /// Called when the user's selection is accepted and capture begins (picker wait excluded).
    public mutating func captureStarted(at instant: MonotonicInstant) {
        captureStartedAt = instant
    }

    /// Maps a source PTS to session time (seconds from the first accepted sample).
    public func sessionTime(_ t: MediaTime) -> MediaTime {
        guard let origin = timelineOrigin else { return .zero }
        return MediaTime(seconds: t.seconds - origin.seconds)
    }

    public func sessionRange(_ r: MediaRange) -> MediaRange {
        MediaRange(start: sessionTime(r.start), end: sessionTime(r.end))
    }

    /// Validates timing and records coverage. Returns whether the sample should go to the writer.
    public mutating func observe(_ sample: SampleObservation, at now: MonotonicInstant) -> SampleVerdict {
        guard var m = monitors[sample.source] else { return .reject(.selectionChanged) }
        guard sample.range.start.seconds.isFinite, sample.range.end.seconds.isFinite,
              !(sample.range.end < sample.range.start) else { return .reject(.ptsInvalid) }
        if sample.formatEpoch > m.formatEpoch { m.formatEpoch = sample.formatEpoch }

        if let last = m.lastEnd {
            let delta = sample.range.start.seconds - last.seconds
            let overlapTolerance = 0.005
            if delta < -overlapTolerance {
                // Overlaps media already received: a repeated buffer, or time moving backward (T15).
                monitors[sample.source] = m
                let span = max(sample.range.duration, 0.001)
                return .reject(delta >= -(span + overlapTolerance) ? .ptsDuplicate : .ptsBackward)
            }
            if m.policy.expectsContinuousDelivery && delta > profile.gapTolerance {
                // Known coverage hole between the last sample and this one (T06). Kept even though
                // the source has resumed (T07).
                if timelineOrigin != nil {
                    ledger.record(Anomaly(source: sample.source,
                                          range: sessionRange(MediaRange(start: last, end: sample.range.start)),
                                          kind: .missing, reason: .ptsDiscontinuity))
                }
            }
        }

        if timelineOrigin == nil { timelineOrigin = sample.range.start }
        m.lastEnd = max(m.lastEnd ?? sample.range.end, sample.range.end)
        m.lastProgressAt = now
        // New media after a route/format change re-establishes current evidence for the new epoch.
        m.awaitingFirstAfterEpoch = false
        m.received.insert(sessionRange(sample.range))

        if let audio = sample.audio {
            m.lastAudio = audio
            if audio.isAllZero {
                if m.zeroRunStart == nil { m.zeroRunStart = sessionTime(sample.range.start) }
                m.zeroRunSeconds += sample.range.duration
            } else {
                if m.zeroRunSeconds >= profile.suspiciousZeroAudioSeconds, let start = m.zeroRunStart {
                    // All-zero buffers during capture: content inconclusive, not proven speech (T09).
                    ledger.record(Anomaly(source: sample.source, range: MediaRange(start: start, end: sessionTime(sample.range.start)),
                                          kind: .inconclusive, reason: .allZeroAudio))
                }
                m.zeroRunSeconds = 0
                m.zeroRunStart = nil
            }
        }
        if let frame = sample.frame { m.lastFrame = frame }
        monitors[sample.source] = m
        return .accept
    }

    /// Writer acknowledged the sample range (WRITER_ACCEPTED).
    public mutating func writerAccepted(_ source: SourceKind, range: MediaRange) {
        let r = sessionRange(range)
        monitors[source]?.accepted.insert(r)
    }

    /// Writer refused data that capture delivered: visible source-to-file mismatch (T08).
    public mutating func writerRejected(_ source: SourceKind, range: MediaRange, reason: ReasonCode = .writerRejected) {
        ledger.record(Anomaly(source: source, range: sessionRange(range), kind: .missing, reason: reason))
    }

    /// Ingress dropped media under the queue policy; never silent (T17).
    public mutating func ingressDropped(_ source: SourceKind, range: MediaRange) {
        ledger.record(Anomaly(source: source, range: sessionRange(range), kind: .missing, reason: .queueOverflow))
    }

    /// Checkpoint committed for a session-time range (CHECKPOINT_COMMITTED).
    public mutating func checkpointCommitted(_ source: SourceKind, sessionRange range: MediaRange) {
        monitors[source]?.checkpointed.insert(range)
    }

    /// Route/format/selection change: old proof expires, new epoch must be re-proven (T05, T16).
    public mutating func formatChanged(_ source: SourceKind) {
        guard var m = monitors[source] else { return }
        m.formatEpoch += 1
        m.awaitingFirstAfterEpoch = true
        monitors[source] = m
    }

    public func currentEpoch(_ source: SourceKind) -> Int { monitors[source]?.formatEpoch ?? 0 }

    /// Current observation per requested source at `now`.
    public func status(at now: MonotonicInstant) -> [SourceStatus] {
        contract.sources.map { policy in
            let m = monitors[policy.kind] ?? SourceMonitor(policy: policy)
            var s = SourceStatus(source: policy.kind, requirement: policy.requirement, health: .checking,
                                 receivedSeconds: m.received.coveredSeconds, hasEverReceived: m.lastProgressAt != nil)
            if let p = m.lastProgressAt { s.secondsSinceProgress = now.seconds(since: p) }
            if let a = m.lastAudio { s.inputLevel = min(1, max(0, a.peak)) }

            guard let started = captureStartedAt else { return s }
            guard let progress = m.lastProgressAt else {
                if now.seconds(since: started) >= profile.startupDeadline {
                    s.health = .unavailable
                    s.reason = .sourceNeverArrived
                }
                return s
            }
            if m.awaitingFirstAfterEpoch {
                s.health = .checking
                s.reason = .formatChanged
                return s
            }
            let age = now.seconds(since: progress)
            if policy.expectsContinuousDelivery && age > profile.audioStaleThreshold {
                s.health = .limited
                s.reason = .sourceStale
                s.inputLevel = nil
                return s
            }
            if let a = m.lastAudio {
                if m.zeroRunSeconds >= profile.suspiciousZeroAudioSeconds {
                    s.health = .limited
                    s.reason = .allZeroAudio
                    return s
                }
                if a.clippedFraction > 0.05 {
                    s.health = .limited
                    s.reason = .clipping
                    return s
                }
            }
            switch m.lastFrame {
            case .blank?: s.health = .limited; s.reason = .blankFrames; return s
            case .suspended?: s.health = .limited; s.reason = .suspendedFrames; return s
            case .stopped?: s.health = .unavailable; s.reason = .stoppedFrames; return s
            default: break
            }
            s.health = .checksPassing
            return s
        }
    }

    /// Closes the session: records startup/tail truncation and never-arrived sources.
    /// `captureEnd` is the accepted cutoff in session time.
    public mutating func finish(captureEnd: MediaTime) -> CaptureCompleteness {
        let bounds = MediaRange(start: .zero, end: captureEnd)
        for policy in contract.sources {
            guard let m = monitors[policy.kind] else { continue }
            if m.lastProgressAt == nil {
                if bounds.duration > 0 {
                    ledger.record(Anomaly(source: policy.kind, range: bounds, kind: .missing, reason: .sourceNeverArrived))
                }
                continue
            }
            if m.zeroRunSeconds >= profile.suspiciousZeroAudioSeconds, let start = m.zeroRunStart {
                ledger.record(Anomaly(source: policy.kind, range: MediaRange(start: start, end: captureEnd),
                                      kind: .inconclusive, reason: .allZeroAudio))
            }
            guard policy.expectsContinuousDelivery else { continue }
            if let first = m.received.first, first.seconds > profile.gapTolerance {
                ledger.record(Anomaly(source: policy.kind, range: MediaRange(start: .zero, end: first),
                                      kind: .missing, reason: .startupTruncation))
            }
            if let last = m.received.last, captureEnd.seconds - last.seconds > profile.gapTolerance {
                ledger.record(Anomaly(source: policy.kind, range: MediaRange(start: last, end: captureEnd),
                                      kind: .missing, reason: .tailTruncation))
            }
        }
        return completeness
    }

    /// Completeness considers required sources only; optional-source gaps stay in the report.
    /// No evidence at all is UNKNOWN, never complete (rule 17).
    public var completeness: CaptureCompleteness {
        let required = Set(contract.requiredSources)
        if required.isEmpty { return .unknown }
        if ledger.open().contains(where: { required.contains($0.source) }) { return .partial }
        let anyEvidence = required.contains { monitors[$0]?.lastProgressAt != nil }
        return anyEvidence ? .noKnownGaps : .unknown
    }

    public func coverage(_ source: SourceKind, stage: PipelineStage) -> CoverageSet {
        guard let m = monitors[source] else { return CoverageSet() }
        switch stage {
        case .received: return m.received
        case .accepted: return m.accepted
        case .checkpointed, .validated: return m.checkpointed
        }
    }
}
