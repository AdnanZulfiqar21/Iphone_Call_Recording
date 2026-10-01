import Foundation

/// journal.json — session transaction state, written at start and at each lifecycle step.
public struct RecoveryJournal: Codable, Sendable, Hashable {
    public static let currentSchemaVersion = 1

    public enum State: String, Codable, Sendable {
        /// Capture or writing may have been in progress.
        case active
        /// Capture ended; finalization in progress.
        case finalizing
        /// Master validated and committed; recovery material may be removed.
        case committed
        /// Finalization failed or timed out; material preserved for recovery.
        case needsRecovery
    }

    public var schemaVersion: Int
    public var identity: SessionIdentity
    public var contract: CaptureContract
    public var createdAt: Date
    public var state: State
    /// Last session time known to have been captured, updated with checkpoints.
    public var lastKnownCaptureEnd: Double
    /// Anomalies known at the last journal write, so a crash cannot erase known gaps.
    public var anomalies: [Anomaly]
    public var recoveryAttempts: Int
    public var lastAttemptLaunchID: UUID?
    public var title: String

    public init(identity: SessionIdentity, contract: CaptureContract, createdAt: Date, title: String) {
        self.schemaVersion = Self.currentSchemaVersion
        self.identity = identity
        self.contract = contract
        self.createdAt = createdAt
        self.state = .active
        self.lastKnownCaptureEnd = 0
        self.anomalies = []
        self.recoveryAttempts = 0
        self.title = title
    }
}

/// manifest.json — ordered committed segments with checksums (section 10.3).
public struct RecoveryManifest: Codable, Sendable, Hashable {
    public static let currentSchemaVersion = 1

    public struct Segment: Codable, Sendable, Hashable {
        public var sequence: Int
        public var fileName: String
        public var sessionRange: MediaRange
        public var sources: [SourceKind]
        public var byteCount: Int
        public var sha256: String

        public init(sequence: Int, fileName: String, sessionRange: MediaRange, sources: [SourceKind], byteCount: Int, sha256: String) {
            self.sequence = sequence
            self.fileName = fileName
            self.sessionRange = sessionRange
            self.sources = sources
            self.byteCount = byteCount
            self.sha256 = sha256
        }
    }

    public var schemaVersion: Int
    public var sessionID: UUID
    public var format: String
    /// Initialization data (fMP4 "ftyp+moov"); fragments are not playable without it.
    public var initializationFileName: String?
    public var initializationSHA256: String?
    public var segments: [Segment]

    public init(sessionID: UUID, format: String = "fmp4-hls") {
        self.schemaVersion = Self.currentSchemaVersion
        self.sessionID = sessionID
        self.format = format
        self.segments = []
    }

    public var committedEnd: Double { segments.map(\.sessionRange.end.seconds).max() ?? 0 }
}

/// Writes journal/manifest atomically in the session's recovery directory.
public struct RecoveryFiles: Sendable {
    public let directory: URL

    public init(directory: URL) { self.directory = directory }

    public var journalURL: URL { directory.appendingPathComponent("journal.json") }
    public var manifestURL: URL { directory.appendingPathComponent("manifest.json") }
    public var segmentsDirectory: URL { directory.appendingPathComponent("segments", isDirectory: true) }
    public var initializationDirectory: URL { directory.appendingPathComponent("initialization", isDirectory: true) }

    public func prepare() throws {
        try FileManager.default.createDirectory(at: segmentsDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: initializationDirectory, withIntermediateDirectories: true)
    }

    public func writeJournal(_ j: RecoveryJournal) throws {
        try AtomicJSON.write(j, to: journalURL, protection: .completeUntilFirstUserAuthentication)
    }

    public func readJournal() throws -> RecoveryJournal { try AtomicJSON.read(RecoveryJournal.self, from: journalURL) }

    public func writeManifest(_ m: RecoveryManifest) throws {
        try AtomicJSON.write(m, to: manifestURL, protection: .completeUntilFirstUserAuthentication)
    }

    public func readManifest() throws -> RecoveryManifest { try AtomicJSON.read(RecoveryManifest.self, from: manifestURL) }
}
