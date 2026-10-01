import Foundation
import CallCaptureCore

/// Plain-language copy for StatusMessage (section 14.5). One idea per line; known first, then
/// what is not known. Never "verified", "100%", "guaranteed" or "both speakers" (section 14.12).
enum StatusCopy {
    static func text(_ message: StatusMessage) -> String {
        switch message {
        case .chooseWhatToRecord: return String(localized: "Choose what to record")
        case .preparing: return String(localized: "Getting ready…")
        case .startingCapture: return String(localized: "Checking audio availability…")
        case .recording: return String(localized: "Recording")
        case .stoppingCapture: return String(localized: "Stopping…")
        case .savingFile: return String(localized: "Recording stopped. Saving your file…")
        case .savedNoKnownGaps: return String(localized: "Saved — no known gaps")
        case .savedWithMissingSections: return String(localized: "Saved with missing sections")
        case .recoveredNoKnownGaps: return String(localized: "Recovered — the end may be missing")
        case .recoveredWithMissingSections: return String(localized: "Recovered with missing sections")
        case .saveFailedRecoveryKept: return String(localized: "Couldn't finish saving. Your media is kept for recovery.")
        case .cancelled: return String(localized: "Recording didn't start")
        case .permissionDenied: return String(localized: "Screen recording wasn't allowed")
        case .unsupported: return String(localized: "Screen recording isn't available here")
        case .notEnoughStorage: return String(localized: "Not enough free space to record safely")
        case .captureEndedBySystem: return String(localized: "iOS stopped the recording. Saving what was captured…")
        case .mediaServicesReset: return String(localized: "Audio services restarted. Recording stopped safely.")
        case .storageLowStopped: return String(localized: "Storage is almost full. Stopped safely and saving what was captured.")
        case .requiredSourceMissingStopped: return String(localized: "A required audio source wasn't confirmed. Stopped safely and saving what was captured.")
        case .sourceChecking: return String(localized: "Checking…")
        case .sourceDetected(.screen): return String(localized: "Capturing")
        case .sourceDetected: return String(localized: "Detected")
        case .sourceUnconfirmed: return String(localized: "Unconfirmed")
        case .sourceStale: return String(localized: "No audio received just now")
        case .sourceSuspiciousSilence: return String(localized: "Only silence received")
        case .sourceClipping: return String(localized: "Too loud — may distort")
        case .screenIdle: return String(localized: "Screen unchanged")
        case .screenBlank: return String(localized: "Screen content hidden")
        case .screenPaused: return String(localized: "Screen capture paused")
        case .sourceUnavailable: return String(localized: "Not available")
        case .statusNotUpdated: return String(localized: "Status not updated")
        case .earlierPartMissing(let s, let r):
            return String(localized: "\(s.displayName) audio missing \(r.description). This stays in the report.")
        }
    }

    /// Short detail line under a source row.
    static func sourceDetail(_ s: SourceStatus, lifecycle: Lifecycle) -> String {
        guard lifecycle == .capturing || lifecycle == .starting else { return "" }
        switch s.health {
        case .checking:
            return String(localized: "Waiting for the first audio")
        case .checksPassing:
            if let age = s.secondsSinceProgress, age > 1.5 {
                return String(localized: "Updated \(Int(age)) s ago")
            }
            return s.source == .screen ? String(localized: "Updated just now") : String(localized: "Receiving input")
        case .limited:
            if s.reason == .allZeroAudio { return String(localized: "Buffers contain no sound. Conversation audio unconfirmed.") }
            if let age = s.secondsSinceProgress { return String(localized: "Last audio \(Int(age)) s ago") }
            return String(localized: "Limited")
        case .unavailable:
            if s.requirement == .optional { return String(localized: "No audio received yet") }
            return String(localized: "iOS didn't provide this source")
        case .unknown:
            return String(localized: "Status unavailable")
        }
    }

    static func outcome(_ o: FinalOutcome) -> String {
        switch o {
        case .saved: return String(localized: "Saved")
        case .savedPartial: return String(localized: "Partial")
        case .recovered: return String(localized: "Recovered")
        case .recoveredPartial: return String(localized: "Recovered, partial")
        case .failed: return String(localized: "Failed")
        }
    }

    static func outcomeTone(_ o: FinalOutcome) -> StatusTone {
        switch o {
        case .saved: return .pass
        case .savedPartial, .recoveredPartial, .failed: return .warning
        case .recovered: return .neutral
        }
    }

    static func validation(_ v: FileValidation) -> String {
        switch v {
        case .pending: return String(localized: "File checks pending")
        case .basicChecksPassed: return String(localized: "Basic file checks passed · full checks pending")
        case .fullChecksPassed: return String(localized: "Full media checks passed")
        case .failed: return String(localized: "File checks found a problem")
        }
    }

    static func duration(_ seconds: Double) -> String {
        Duration.seconds(max(0, seconds.rounded())).formatted(.time(pattern: seconds >= 3_600 ? .hourMinuteSecond : .minuteSecond))
    }

    static func bytes(_ count: Int64) -> String {
        count.formatted(.byteCount(style: .file))
    }
}
