import Foundation

/// Identity bound to every accepted event (rule 8).
public struct SessionIdentity: Codable, Sendable, Hashable {
    public var sessionID: UUID
    public var generation: Int
    public var contractVersion: Int

    public init(sessionID: UUID, generation: Int, contractVersion: Int) {
        self.sessionID = sessionID
        self.generation = generation
        self.contractVersion = contractVersion
    }
}

public enum PipelineStage: String, Codable, Sendable, Comparable, CaseIterable {
    case received, accepted, checkpointed, validated

    public static func < (lhs: Self, rhs: Self) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

public enum EvidenceOutcome: String, Codable, Sendable {
    case passed, missing, inconclusive, failed, notRequired
}

/// Machine-readable reasons. Main screens map these to plain language; raw codes stay in diagnostics.
public enum ReasonCode: String, Codable, Sendable, CaseIterable {
    case sourceNeverArrived
    case sourceStale
    case ptsDiscontinuity
    case ptsBackward
    case ptsDuplicate
    case ptsInvalid
    case allZeroAudio
    case clipping
    case formatChanged
    case selectionChanged
    case writerRejected
    case queueOverflow
    case drainTimeout
    case finalizationTimeout
    case mediaServicesReset
    case streamStoppedBySystem
    case processTerminated
    case startupTruncation
    case tailTruncation
    case checkpointMissing
    case segmentCorrupt
    case manifestMismatch
    case protectedDataUnavailable
    case diskFull
    case blankFrames
    case suspendedFrames
    case stoppedFrames
}

/// Section 6.2. Range summaries, not one record per sample.
public struct EvidenceRecord: Codable, Sendable, Hashable {
    public var identity: SessionIdentity
    public var source: SourceKind
    public var formatEpoch: Int
    public var range: MediaRange
    public var observedAt: MonotonicInstant
    public var stage: PipelineStage
    public var outcome: EvidenceOutcome
    public var reason: ReasonCode?

    public init(identity: SessionIdentity, source: SourceKind, formatEpoch: Int, range: MediaRange,
                observedAt: MonotonicInstant, stage: PipelineStage, outcome: EvidenceOutcome, reason: ReasonCode? = nil) {
        self.identity = identity
        self.source = source
        self.formatEpoch = formatEpoch
        self.range = range
        self.observedAt = observedAt
        self.stage = stage
        self.outcome = outcome
        self.reason = reason
    }
}
