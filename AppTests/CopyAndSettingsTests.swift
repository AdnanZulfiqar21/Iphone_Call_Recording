import Testing
import Foundation
@testable import CallCapture
import CallCaptureCore

@MainActor
@Suite("App copy and settings (UX06, section 14.12)")
struct CopyAndSettingsTests {
    static let forbidden = ["verified", "100%", "guarantee", "both speakers", "perfect", "everyone was recorded"]

    static var allMessages: [StatusMessage] {
        var m: [StatusMessage] = [.chooseWhatToRecord, .preparing, .startingCapture, .recording, .stoppingCapture, .savingFile,
                                  .savedNoKnownGaps, .savedWithMissingSections, .recoveredNoKnownGaps, .recoveredWithMissingSections,
                                  .saveFailedRecoveryKept, .cancelled, .permissionDenied, .unsupported, .notEnoughStorage,
                                  .captureEndedBySystem, .mediaServicesReset, .requiredSourceMissingStopped,
                                  .screenIdle, .screenBlank, .screenPaused, .statusNotUpdated]
        for s in SourceKind.allCases {
            m += [.sourceChecking(s), .sourceDetected(s), .sourceUnconfirmed(s), .sourceStale(s), .sourceSuspiciousSilence(s),
                  .sourceClipping(s), .sourceUnavailable(s), .earlierPartMissing(s, MediaRange(startSeconds: 250, endSeconds: 260))]
        }
        return m
    }

    @Test("No status copy makes an unsupported promise")
    func noForbiddenClaims() {
        for message in Self.allMessages {
            let text = StatusCopy.text(message).lowercased()
            #expect(!text.isEmpty)
            for word in Self.forbidden { #expect(!text.contains(word), "\(message): \(text)") }
        }
    }

    @Test("Gap notice names the source and the exact range")
    func gapCopy() {
        let text = StatusCopy.text(.earlierPartMissing(.microphone, MediaRange(startSeconds: 250, endSeconds: 260)))
        #expect(text.contains("Microphone"))
        #expect(text.contains("04:10–04:20"))
    }

    @Test("Partial and recovered outcomes never use the pass tone")
    func outcomeTones() {
        #expect(StatusCopy.outcomeTone(.saved) == .pass)
        for o in [FinalOutcome.savedPartial, .recovered, .recoveredPartial, .failed] {
            #expect(StatusCopy.outcomeTone(o) != .pass)
        }
    }

    @Test("Settings build the frozen contract the person chose")
    func contractFromSettings() {
        let defaults = UserDefaults(suiteName: "CallCaptureTests-\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults)
        #expect(settings.contract.requiredSources.contains(.microphone))
        settings.includeMicrophone = false
        #expect(settings.contract.policy(for: .microphone) == nil)
        settings.importantMode = true
        #expect(settings.contract.unmetRequirementPolicy == .protectedStop)
        settings.captureMode = .screenOnly
        #expect(settings.contract.requestedSources == [.screen])
        // Appearance changes are stored and never touch the contract.
        settings.appearance = .dark
        #expect(AppSettings(defaults: defaults).appearance == .dark)
    }

    @Test("Durations and sizes are locale-formatted")
    func formatting() {
        #expect(!StatusCopy.duration(3_725).isEmpty)
        #expect(!StatusCopy.bytes(214_000_000).isEmpty)
    }
}
