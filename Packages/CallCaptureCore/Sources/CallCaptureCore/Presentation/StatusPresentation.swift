import Foundation

/// Visual tone tokens (section 14.2). Green is reserved for narrowly supported passing checks.
public enum StatusTone: String, Sendable, Codable {
    case recording   // red: active recording / Stop only
    case warning     // amber: limited, partial, missing
    case pass        // green: a specific check passed
    case neutral     // grey: checking, unconfirmed, stale, unknown
    case accent      // indigo: ordinary information
}

/// Plain-language message identifiers. The app maps them to localized strings; tests check
/// that each state can only produce copy its evidence supports (UX06).
public enum StatusMessage: Hashable, Sendable {
    // Lifecycle
    case chooseWhatToRecord
    case preparing
    case startingCapture
    case recording
    case stoppingCapture
    case savingFile
    case savedNoKnownGaps
    case savedWithMissingSections
    case recoveredNoKnownGaps
    case recoveredWithMissingSections
    case saveFailedRecoveryKept
    case cancelled
    case permissionDenied
    case unsupported
    case notEnoughStorage
    case captureEndedBySystem
    case mediaServicesReset
    case requiredSourceMissingStopped
    // Sources
    case sourceChecking(SourceKind)
    case sourceDetected(SourceKind)
    case sourceUnconfirmed(SourceKind)
    case sourceStale(SourceKind)
    case sourceSuspiciousSilence(SourceKind)
    case sourceClipping(SourceKind)
    case screenIdle
    case screenBlank
    case screenPaused
    case sourceUnavailable(SourceKind)
    case statusNotUpdated
    // Persistent notices
    case earlierPartMissing(SourceKind, MediaRange)
}

public struct StatusLine: Hashable, Sendable {
    public var tone: StatusTone
    public var message: StatusMessage
    public init(_ tone: StatusTone, _ message: StatusMessage) {
        self.tone = tone
        self.message = message
    }
}

/// Evidence-to-copy mapping. Only copy supported by the precise state is produced.
public enum StatusPresenter {
    public static func source(_ s: SourceStatus, lifecycle: Lifecycle) -> StatusLine {
        guard lifecycle == .capturing || lifecycle == .starting else {
            return StatusLine(.neutral, .sourceUnconfirmed(s.source))
        }
        switch s.health {
        case .checking:
            return StatusLine(.neutral, .sourceChecking(s.source))
        case .checksPassing:
            if s.source == .screen { return StatusLine(.pass, .sourceDetected(.screen)) }
            return StatusLine(.pass, .sourceDetected(s.source))
        case .limited:
            switch s.reason {
            case .allZeroAudio?: return StatusLine(.warning, .sourceSuspiciousSilence(s.source))
            case .clipping?: return StatusLine(.warning, .sourceClipping(s.source))
            case .blankFrames?: return StatusLine(.warning, .screenBlank)
            case .suspendedFrames?: return StatusLine(.warning, .screenPaused)
            default: return StatusLine(.warning, .sourceStale(s.source))
            }
        case .unavailable:
            // An optional source that never arrived is "unconfirmed", not a failure.
            if s.requirement == .optional && s.reason == .sourceNeverArrived {
                return StatusLine(.neutral, .sourceUnconfirmed(s.source))
            }
            return StatusLine(.warning, .sourceUnavailable(s.source))
        case .unknown:
            return StatusLine(.neutral, .sourceUnconfirmed(s.source))
        }
    }

    public static func headline(lifecycle: Lifecycle, nonCapture: NonCaptureOutcome?, outcome: FinalOutcome?,
                                endReason: ReasonCode?) -> StatusLine {
        switch lifecycle {
        case .idle: return StatusLine(.accent, .chooseWhatToRecord)
        case .preparing: return StatusLine(.neutral, .preparing)
        case .awaitingUserSelection: return StatusLine(.neutral, .chooseWhatToRecord)
        case .starting: return StatusLine(.neutral, .startingCapture)
        case .capturing: return StatusLine(.recording, .recording)
        case .stopping:
            if endReason == .streamStoppedBySystem { return StatusLine(.warning, .captureEndedBySystem) }
            if endReason == .mediaServicesReset { return StatusLine(.warning, .mediaServicesReset) }
            if endReason == .sourceNeverArrived { return StatusLine(.warning, .requiredSourceMissingStopped) }
            return StatusLine(.neutral, .stoppingCapture)
        case .finalizing: return StatusLine(.neutral, .savingFile)
        case .finalized, .failed:
            switch outcome {
            case .saved?: return StatusLine(.pass, .savedNoKnownGaps)
            case .savedPartial?: return StatusLine(.warning, .savedWithMissingSections)
            case .recovered?: return StatusLine(.warning, .recoveredNoKnownGaps)
            case .recoveredPartial?: return StatusLine(.warning, .recoveredWithMissingSections)
            case .failed?, nil:
                if nonCapture == .insufficientStorage { return StatusLine(.warning, .notEnoughStorage) }
                if nonCapture == .unsupported { return StatusLine(.warning, .unsupported) }
                return StatusLine(.warning, .saveFailedRecoveryKept)
            }
        case .cancelled:
            if nonCapture == .permissionDenied { return StatusLine(.neutral, .permissionDenied) }
            return StatusLine(.neutral, .cancelled)
        }
    }

    /// Persistent notices for every open required-source gap; resumed audio never removes them.
    public static func persistentNotices(_ ledger: AnomalyLedger) -> [StatusLine] {
        ledger.open().map { StatusLine(.warning, .earlierPartMissing($0.source, $0.range)) }
    }

    /// Projected status (Live Activity, active-session strip) older than the threshold is stale.
    public static func freshness(lastUpdate: MonotonicInstant, now: MonotonicInstant, profile: AcceptanceProfile = .v1) -> StatusLine? {
        now.seconds(since: lastUpdate) > profile.statusStaleAfter ? StatusLine(.neutral, .statusNotUpdated) : nil
    }
}
