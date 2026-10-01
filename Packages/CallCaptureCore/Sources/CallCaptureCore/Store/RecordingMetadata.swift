import Foundation

public struct Bookmark: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var time: Double
    public var label: String

    public init(id: UUID = UUID(), time: Double, label: String) {
        self.id = id
        self.time = time
        self.label = label
    }
}

public struct SourceSummary: Codable, Sendable, Hashable {
    public var source: SourceKind
    public var requirement: SourceRequirement
    public var receivedSeconds: Double
    public var everReceived: Bool
    public var openAnomalySeconds: Double

    public init(source: SourceKind, requirement: SourceRequirement, receivedSeconds: Double, everReceived: Bool, openAnomalySeconds: Double) {
        self.source = source
        self.requirement = requirement
        self.receivedSeconds = receivedSeconds
        self.everReceived = everReceived
        self.openAnomalySeconds = openAnomalySeconds
    }
}

/// Derived artifacts (exports, audio-only copies) are separate objects; masters stay immutable (rule 19).
public struct DerivedArtifact: Codable, Sendable, Hashable, Identifiable {
    public enum Kind: String, Codable, Sendable { case audioOnly, shareCopy }
    public var id: UUID
    public var kind: Kind
    public var fileName: String
    public var createdAt: Date

    public init(id: UUID = UUID(), kind: Kind, fileName: String, createdAt: Date) {
        self.id = id
        self.kind = kind
        self.fileName = fileName
        self.createdAt = createdAt
    }
}

/// metadata.json — the mutable record beside an immutable master.
public struct RecordingMetadata: Codable, Sendable, Hashable, Identifiable {
    public static let currentSchemaVersion = 2

    public var schemaVersion: Int
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var duration: Double
    public var masterFileName: String?
    public var byteCount: Int
    public var contract: CaptureContract
    public var outcome: FinalOutcome
    public var completeness: CaptureCompleteness
    public var validation: FileValidation
    public var libraryState: LibraryState
    public var sources: [SourceSummary]
    public var anomalies: [Anomaly]
    public var bookmarks: [Bookmark]
    public var derived: [DerivedArtifact]
    /// Why capture ended when it was not an ordinary user Stop.
    public var endReason: ReasonCode?
    /// Set for Important Recording mode when a requirement was not met, kept in the report (section 14.4).
    public var unmetRequirements: [SourceKind]

    public init(id: UUID, title: String, createdAt: Date, duration: Double, masterFileName: String?, byteCount: Int,
                contract: CaptureContract, outcome: FinalOutcome, completeness: CaptureCompleteness, validation: FileValidation,
                libraryState: LibraryState, sources: [SourceSummary], anomalies: [Anomaly], bookmarks: [Bookmark] = [],
                derived: [DerivedArtifact] = [], endReason: ReasonCode? = nil, unmetRequirements: [SourceKind] = []) {
        self.schemaVersion = Self.currentSchemaVersion
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.duration = duration
        self.masterFileName = masterFileName
        self.byteCount = byteCount
        self.contract = contract
        self.outcome = outcome
        self.completeness = completeness
        self.validation = validation
        self.libraryState = libraryState
        self.sources = sources
        self.anomalies = anomalies
        self.bookmarks = bookmarks
        self.derived = derived
        self.endReason = endReason
        self.unmetRequirements = unmetRequirements
    }

    public var openAnomalies: [Anomaly] { anomalies.filter(\.isOpen) }
    public var hasKnownGaps: Bool { !openAnomalies.isEmpty }
}
