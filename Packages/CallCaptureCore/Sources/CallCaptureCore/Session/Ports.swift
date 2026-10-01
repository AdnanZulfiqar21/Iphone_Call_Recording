import Foundation

/// Events from a capture adapter. Every event is tagged with the generation it was started for.
public enum CaptureEngineEvent: Sendable {
    case selectionAccepted(microphoneEnabled: Bool)
    case selectionCancelled
    case permissionDenied
    case unsupported(String)
    case sample(CapturedSample)
    case formatChanged(SourceKind)
    case stopped(ReasonCode?)
    case mediaServicesReset
}

public typealias CaptureEventSink = @Sendable (_ generation: Int, _ event: CaptureEngineEvent) -> Void

/// CaptureEngine (section 5): public capture APIs, picker events, samples and observations.
/// It owns no storage, purchase or health decisions.
public protocol CaptureEngine: AnyObject, Sendable {
    /// Whether this device/OS can offer capture at all (used before showing Start).
    var isAvailable: Bool { get }
    /// Presents the genuine system picker for `generation`; never imitates it.
    func presentPicker(contract: CaptureContract, generation: Int, sink: @escaping CaptureEventSink)
    /// Starts the stream for the accepted selection.
    func startCapture(generation: Int) async
    /// Stops the stream. Idempotent; late callbacks after this are tagged with the old generation.
    func stopCapture(generation: Int) async
}

public enum WriterAppendResult: Equatable, Sendable {
    case accepted
    case notReady
    case rejected(ReasonCode)
}

/// A durable checkpoint: segment data and manifest committed (CHECKPOINT_COMMITTED).
public struct CheckpointReport: Codable, Sendable, Hashable {
    public var sequence: Int
    public var sessionRange: MediaRange
    public var sources: [SourceKind]
    public var fileName: String
    public var byteCount: Int
    public var sha256: String

    public init(sequence: Int, sessionRange: MediaRange, sources: [SourceKind], fileName: String, byteCount: Int, sha256: String) {
        self.sequence = sequence
        self.sessionRange = sessionRange
        self.sources = sources
        self.fileName = fileName
        self.byteCount = byteCount
        self.sha256 = sha256
    }
}

public struct WriterFinishReport: Sendable {
    public var lastCheckpointSequence: Int
    public var writtenRange: MediaRange?
    public var error: String?

    public init(lastCheckpointSequence: Int, writtenRange: MediaRange?, error: String? = nil) {
        self.lastCheckpointSequence = lastCheckpointSequence
        self.writtenRange = writtenRange
        self.error = error
    }
}

/// MediaWriter (section 5): one backend per session, bounded inputs, receipts and checkpoints.
public protocol MediaWriter: AnyObject, Sendable {
    /// Prepares a writer whose segments go to `recoveryDirectory`.
    func open(identity: SessionIdentity, contract: CaptureContract, recoveryDirectory: URL,
              onCheckpoint: @escaping @Sendable (CheckpointReport) -> Void) throws
    /// Appends one sample. Must be quick; called from the writer drain queue only.
    func append(_ sample: CapturedSample, sessionTime: MediaRange) -> WriterAppendResult
    /// Finishes writing up to the accepted cutoff and commits the final checkpoint.
    func finish() async -> WriterFinishReport
    /// Abandons writing; committed checkpoints remain on disk for recovery.
    func cancel() async
}

public struct FinalizedMedia: Sendable {
    public var masterFileName: String
    public var duration: Double
    public var byteCount: Int
    public var tracks: [SourceKind]
    public var validation: ValidationReport

    public init(masterFileName: String, duration: Double, byteCount: Int, tracks: [SourceKind], validation: ValidationReport) {
        self.masterFileName = masterFileName
        self.duration = duration
        self.byteCount = byteCount
        self.tracks = tracks
        self.validation = validation
    }
}

/// Assembles committed segments into a master and runs BASIC validation.
/// Implemented by the media layer; runs outside the active capture path (rule 3).
public protocol RecordingAssembler: Sendable {
    func assemble(recoveryDirectory: URL, manifest: RecoveryManifest, into recordingDirectory: URL) async throws -> FinalizedMedia
}

/// Deadline scheduling, injectable for deterministic tests.
public protocol SessionScheduler: Sendable {
    func schedule(after seconds: Double, _ action: @escaping @Sendable () async -> Void) -> any ScheduledWork
}

public protocol ScheduledWork: Sendable {
    func cancel()
}

public struct TaskScheduler: SessionScheduler {
    public init() {}
    public func schedule(after seconds: Double, _ action: @escaping @Sendable () async -> Void) -> any ScheduledWork {
        let task = Task {
            try? await Task.sleep(nanoseconds: UInt64(max(0, seconds) * 1_000_000_000))
            if !Task.isCancelled { await action() }
        }
        return TaskWork(task: task)
    }

    struct TaskWork: ScheduledWork {
        let task: Task<Void, Never>
        func cancel() { task.cancel() }
    }
}
