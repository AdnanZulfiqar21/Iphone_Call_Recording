import Foundation

// Section 7: separate truth models. There is deliberately no single "verified" flag.

public enum Lifecycle: String, Codable, Sendable, CaseIterable {
    case idle = "IDLE"
    case preparing = "PREPARING"
    case awaitingUserSelection = "AWAITING_USER_SELECTION"
    case starting = "STARTING"
    case capturing = "CAPTURING"
    case stopping = "STOPPING"
    case finalizing = "FINALIZING"
    case finalized = "FINALIZED"
    case cancelled = "CANCELLED"
    case failed = "FAILED"

    /// States in which a session holds capture/writer resources.
    public var isActive: Bool {
        switch self {
        case .preparing, .awaitingUserSelection, .starting, .capturing, .stopping, .finalizing: return true
        case .idle, .finalized, .cancelled, .failed: return false
        }
    }

    /// States in which media is being captured (the timer runs only here).
    public var isCapturing: Bool { self == .capturing }
}

public enum CurrentSourceHealth: String, Codable, Sendable, CaseIterable {
    case checking = "CHECKING"
    case checksPassing = "CHECKS_PASSING"
    case limited = "LIMITED"
    case unavailable = "UNAVAILABLE"
    case unknown = "UNKNOWN"
}

public enum CaptureCompleteness: String, Codable, Sendable, CaseIterable {
    case noKnownGaps = "NO_KNOWN_GAPS"
    case partial = "PARTIAL"
    case unknown = "UNKNOWN"
}

public enum FileValidation: String, Codable, Sendable, CaseIterable {
    case pending = "PENDING"
    case basicChecksPassed = "BASIC_CHECKS_PASSED"
    case fullChecksPassed = "FULL_CHECKS_PASSED"
    case failed = "FAILED"
}

public enum HistoricalCompatibility: String, Codable, Sendable, CaseIterable {
    case untested = "UNTESTED"
    case observedWorking = "OBSERVED_WORKING"
    case observedLimited = "OBSERVED_LIMITED"
    case observedFailed = "OBSERVED_FAILED"
    case stale = "STALE"
}

public enum LibraryState: String, Codable, Sendable, CaseIterable {
    case validating = "VALIDATING"
    case available = "AVAILABLE"
    case recovering = "RECOVERING"
    case quarantined = "QUARANTINED"
    case deletePending = "DELETE_PENDING"
}

public enum FinalOutcome: String, Codable, Sendable, CaseIterable {
    case saved = "SAVED"
    case savedPartial = "SAVED_PARTIAL"
    case recovered = "RECOVERED"
    case recoveredPartial = "RECOVERED_PARTIAL"
    case failed = "FAILED"

    public var isPartial: Bool { self == .savedPartial || self == .recoveredPartial }
    public var isRecovered: Bool { self == .recovered || self == .recoveredPartial }

    /// Combines how the file was produced with what is known about completeness.
    /// Unknown completeness is never promoted to a complete outcome.
    public static func make(recovered: Bool, completeness: CaptureCompleteness, playable: Bool) -> FinalOutcome {
        guard playable else { return .failed }
        let complete = completeness == .noKnownGaps
        switch (recovered, complete) {
        case (false, true): return .saved
        case (false, false): return .savedPartial
        case (true, true): return .recovered
        case (true, false): return .recoveredPartial
        }
    }
}

/// How a session ended before producing media, kept distinct (rule 23).
public enum NonCaptureOutcome: String, Codable, Sendable {
    case userCancelled = "USER_CANCELLED"
    case permissionDenied = "PERMISSION_DENIED"
    case unsupported = "UNSUPPORTED"
    case insufficientStorage = "INSUFFICIENT_STORAGE"
    case captureUnavailable = "CAPTURE_UNAVAILABLE"
}
