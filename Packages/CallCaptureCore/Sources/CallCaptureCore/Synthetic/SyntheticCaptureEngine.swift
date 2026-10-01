#if DEBUG
import Foundation

/// Deterministic synthetic capture adapter (P03). Compiled only in DEBUG so it can never be
/// selected in a shipping build; its results are SYNTHETIC_TESTED, never device evidence.
public final class SyntheticCaptureEngine: CaptureEngine, @unchecked Sendable {
    public enum PickerResponse: Sendable, Equatable {
        case accept(microphone: Bool)
        case cancel
        case deny
        case unsupported
        /// The test drives the response manually with `respondToPicker`.
        case manual
    }

    private let lock = NSLock()
    private var sink: CaptureEventSink?
    private var generation = -1
    private var stopped = true
    private var runner: Task<Void, Never>?
    public var pickerResponse: PickerResponse
    public var scenario: SyntheticScenario?
    /// Builds real media payloads (e.g. CMSampleBuffers) when the media layer provides one.
    public var payloadFactory: (@Sendable (SampleObservation) -> (any SamplePayload)?)?
    public var isAvailable: Bool = true
    public private(set) var startCount = 0
    public private(set) var stopCount = 0

    public init(pickerResponse: PickerResponse = .accept(microphone: true), scenario: SyntheticScenario? = nil) {
        self.pickerResponse = pickerResponse
        self.scenario = scenario
    }

    public func presentPicker(contract: CaptureContract, generation: Int, sink: @escaping CaptureEventSink) {
        lock.lock()
        self.sink = sink
        self.generation = generation
        let response = pickerResponse
        lock.unlock()
        switch response {
        case .accept(let mic): sink(generation, .selectionAccepted(microphoneEnabled: mic))
        case .cancel: sink(generation, .selectionCancelled)
        case .deny: sink(generation, .permissionDenied)
        case .unsupported: sink(generation, .unsupported("synthetic"))
        case .manual: break
        }
    }

    public func respondToPicker(_ response: PickerResponse) {
        lock.lock(); let s = sink; let g = generation; lock.unlock()
        switch response {
        case .accept(let mic): s?(g, .selectionAccepted(microphoneEnabled: mic))
        case .cancel: s?(g, .selectionCancelled)
        case .deny: s?(g, .permissionDenied)
        case .unsupported: s?(g, .unsupported("synthetic"))
        case .manual: break
        }
    }

    public func startCapture(generation: Int) async {
        let scenario: SyntheticScenario? = lock.withLock {
            guard generation == self.generation else { return nil }
            stopped = false
            startCount += 1
            return self.scenario ?? SyntheticScenario(name: "manual", duration: 0, sources: [])
        }
        if let scenario, scenario.duration > 0 { run(scenario, generation: generation) }
    }

    public func stopCapture(generation: Int) async {
        let (wasRunning, s): (Bool, CaptureEventSink?) = lock.withLock {
            let running = !stopped && generation == self.generation
            stopped = true
            stopCount += 1
            runner?.cancel()
            return (running, sink)
        }
        if wasRunning { s?(generation, .stopped(nil)) }
    }

    /// Emits a sample for the current generation (manual tests).
    public func deliver(_ source: SourceKind, start: Double, duration: Double, audio: AudioContentSummary? = nil,
                        frame: FrameStatus? = nil, epoch: Int = 0, bytes: Int = 4_096, generation g: Int? = nil) {
        lock.lock(); let s = sink; let gen = g ?? generation; lock.unlock()
        let obs = SampleObservation(source: source, range: MediaRange(startSeconds: start, endSeconds: start + duration),
                                    formatEpoch: epoch, audio: audio, frame: frame, byteCount: bytes)
        s?(gen, .sample(CapturedSample(observation: obs, payload: payloadFactory?(obs))))
    }

    public func emit(_ event: CaptureEngineEvent, generation g: Int? = nil) {
        lock.lock(); let s = sink; let gen = g ?? generation; lock.unlock()
        s?(gen, event)
    }

    public var currentGeneration: Int { lock.lock(); defer { lock.unlock() }; return generation }

    private func run(_ scenario: SyntheticScenario, generation: Int) {
        runner = Task { [weak self] in
            let start = DispatchTime.now().uptimeNanoseconds
            var t = 0.0
            var screenNext = 0.0
            let base = 1_000.0   // host-clock style PTS origin
            while !Task.isCancelled, t < scenario.duration {
                guard let self else { return }
                for event in scenario.events where event.at >= t && event.at < t + scenario.tick {
                    self.emit(event.event, generation: generation)
                }
                for source in scenario.sources where !scenario.isMissing(source, at: t) {
                    if source == .screen {
                        if t >= screenNext {
                            self.deliver(.screen, start: base + t, duration: 1.0 / 30, frame: scenario.frameStatus(at: t),
                                         epoch: 0, bytes: 60_000, generation: generation)
                            screenNext = t + scenario.screenInterval
                        }
                    } else {
                        self.deliver(source, start: base + t, duration: scenario.tick, audio: scenario.audio(source, at: t),
                                     epoch: 0, bytes: Int(scenario.tick * 48_000 * 4), generation: generation)
                    }
                }
                t += scenario.tick
                let target = start + UInt64(t * 1_000_000_000 / scenario.speed)
                let now = DispatchTime.now().uptimeNanoseconds
                if target > now { try? await Task.sleep(nanoseconds: target - now) }
            }
        }
    }
}

/// A scripted synthetic recording for tests and simulator UI fixtures.
public struct SyntheticScenario: Sendable {
    public struct Gap: Sendable { public var source: SourceKind; public var from: Double; public var to: Double }
    public struct TimedEvent: Sendable { public var at: Double; public var event: CaptureEngineEvent }

    public var name: String
    public var duration: Double
    public var tick: Double = 0.1
    public var screenInterval: Double = 0.5
    public var speed: Double = 1
    public var sources: [SourceKind]
    public var gaps: [Gap] = []
    public var zeroAudio: [Gap] = []
    public var events: [TimedEvent] = []

    public init(name: String, duration: Double, sources: [SourceKind], gaps: [Gap] = [], zeroAudio: [Gap] = [], events: [TimedEvent] = []) {
        self.name = name
        self.duration = duration
        self.sources = sources
        self.gaps = gaps
        self.zeroAudio = zeroAudio
        self.events = events
    }

    func isMissing(_ s: SourceKind, at t: Double) -> Bool { gaps.contains { $0.source == s && t >= $0.from && t < $0.to } }

    func audio(_ s: SourceKind, at t: Double) -> AudioContentSummary {
        if zeroAudio.contains(where: { $0.source == s && t >= $0.from && t < $0.to }) { return .allZero }
        return .speech(level: Float(0.15 + 0.25 * abs(sin(t * 3.1))))
    }

    func frameStatus(at t: Double) -> FrameStatus { Int(t * 2) % 7 == 0 ? .complete : .idle }

    /// Named fixtures used by simulator UI tests (`-UITestScenario <name>`).
    public static func named(_ name: String) -> SyntheticScenario? {
        switch name {
        case "normal":
            return SyntheticScenario(name: name, duration: 3_600, sources: [.screen, .microphone])
        case "micGap":
            return SyntheticScenario(name: name, duration: 3_600, sources: [.screen, .microphone],
                                     gaps: [Gap(source: .microphone, from: 4, to: 14)])
        case "allZero":
            return SyntheticScenario(name: name, duration: 3_600, sources: [.screen, .microphone],
                                     zeroAudio: [Gap(source: .microphone, from: 2, to: 3_600)])
        case "systemStop":
            return SyntheticScenario(name: name, duration: 3_600, sources: [.screen, .microphone],
                                     events: [TimedEvent(at: 8, event: .stopped(.streamStoppedBySystem))])
        case "noAudio":
            return SyntheticScenario(name: name, duration: 3_600, sources: [.screen])
        default:
            return nil
        }
    }
}

/// Test writer that produces real segment files through the real commit transaction,
/// with synthetic bytes. Behaviour switches cover T08, T21 and T24.
public final class FixtureMediaWriter: MediaWriter, @unchecked Sendable {
    public enum Behaviour: Sendable { case normal, rejectAll, rejectSource(SourceKind), hangOnFinish, notReadyTimes(Int) }

    private let lock = NSLock()
    private var committer: SegmentCommitter?
    private var onCheckpoint: (@Sendable (CheckpointReport) -> Void)?
    private var pendingStart: Double?
    private var pendingEnd: Double = 0
    private var pendingSources: Set<SourceKind> = []
    private var pendingBytes = 0
    private var notReadyRemaining = 0
    public var behaviour: Behaviour
    public var segmentSeconds: Double
    public private(set) var appended = 0

    public init(behaviour: Behaviour = .normal, segmentSeconds: Double = 2) {
        self.behaviour = behaviour
        self.segmentSeconds = segmentSeconds
        if case .notReadyTimes(let n) = behaviour { notReadyRemaining = n }
    }

    public func open(identity: SessionIdentity, contract: CaptureContract, recoveryDirectory: URL,
                     onCheckpoint: @escaping @Sendable (CheckpointReport) -> Void) throws {
        let c = try SegmentCommitter(files: RecoveryFiles(directory: recoveryDirectory), sessionID: identity.sessionID)
        try c.commitInitialization(Data("FIXTURE-INIT".utf8))
        lock.lock(); committer = c; self.onCheckpoint = onCheckpoint; lock.unlock()
    }

    public func append(_ sample: CapturedSample, sessionTime: MediaRange) -> WriterAppendResult {
        lock.lock(); defer { lock.unlock() }
        switch behaviour {
        case .rejectAll: return .rejected(.writerRejected)
        case .rejectSource(let s) where s == sample.observation.source: return .rejected(.writerRejected)
        default: break
        }
        if notReadyRemaining > 0 { notReadyRemaining -= 1; return .notReady }
        appended += 1
        if pendingStart == nil { pendingStart = sessionTime.start.seconds }
        pendingEnd = max(pendingEnd, sessionTime.end.seconds)
        pendingSources.insert(sample.observation.source)
        pendingBytes += max(1, sample.observation.byteCount / 100)
        if pendingEnd - (pendingStart ?? 0) >= segmentSeconds { commitPending() }
        return .accepted
    }

    private func commitPending() {
        guard let start = pendingStart, let committer else { return }
        let data = Data(repeating: 0x5A, count: max(16, pendingBytes))
        if let report = try? committer.commitSegment(data, sessionRange: MediaRange(startSeconds: start, endSeconds: pendingEnd),
                                                      sources: pendingSources.sorted()) {
            onCheckpoint?(report)
        }
        pendingStart = nil
        pendingSources = []
        pendingBytes = 0
    }

    public func finish() async -> WriterFinishReport {
        if case .hangOnFinish = behaviour {
            try? await Task.sleep(nanoseconds: 3_600 * 1_000_000_000)
        }
        let m: RecoveryManifest? = lock.withLock {
            commitPending()
            return committer?.currentManifest
        }
        return WriterFinishReport(lastCheckpointSequence: m?.segments.last?.sequence ?? -1,
                                  writtenRange: m.flatMap { $0.segments.isEmpty ? nil : MediaRange(startSeconds: 0, endSeconds: $0.committedEnd) })
    }

    public func cancel() async {
        // A hung backend takes a moment to confirm closure; the lease must be held meanwhile.
        if case .hangOnFinish = behaviour { try? await Task.sleep(nanoseconds: 300_000_000) }
    }
}

/// Assembles fixture segments into a master by concatenation and reports BASIC coverage
/// from the manifest. Real media validation lives in the media layer.
public struct FixtureAssembler: RecordingAssembler {
    public var failing: Bool
    public init(failing: Bool = false) { self.failing = failing }

    public func assemble(recoveryDirectory: URL, manifest: RecoveryManifest, into recordingDirectory: URL) async throws -> FinalizedMedia {
        if failing { throw SegmentCommitter.CommitError.injectedFault }
        let files = RecoveryFiles(directory: recoveryDirectory)
        var data = Data()
        if let i = manifest.initializationFileName { data.append(try Data(contentsOf: files.initializationDirectory.appendingPathComponent(i))) }
        var durations: [String: Double] = [:]
        for seg in manifest.segments.sorted(by: { $0.sequence < $1.sequence }) {
            data.append(try Data(contentsOf: files.segmentsDirectory.appendingPathComponent(seg.fileName)))
            for s in seg.sources { durations[s.rawValue] = max(durations[s.rawValue] ?? 0, seg.sessionRange.end.seconds) }
        }
        let name = "master.fixture"
        let url = recordingDirectory.appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        let duration = manifest.committedEnd
        let report = ValidationReport(fileName: name, byteCount: data.count, sha256: SHA256Hasher.hex(of: data), coverage: .basic,
                                      result: .basicChecksPassed, durations: durations, notes: ["synthetic fixture"])
        return FinalizedMedia(masterFileName: name, duration: duration, byteCount: data.count,
                              tracks: durations.keys.compactMap(SourceKind.init(rawValue:)), validation: report)
    }
}
#endif
