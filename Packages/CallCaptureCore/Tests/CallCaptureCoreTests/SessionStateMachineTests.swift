import Testing
@testable import CallCaptureCore

@Suite("Session lifecycle (section 8)")
struct SessionStateMachineTests {
    func started() -> SessionStateMachine {
        var m = SessionStateMachine()
        _ = m.handle(.recordRequested(screenMicContract))
        _ = m.handle(.resourcesReady, generation: m.generation)
        _ = m.handle(.selectionAccepted(microphoneEnabled: true), generation: m.generation)
        _ = m.handle(.firstMediaAccepted, generation: m.generation)
        return m
    }

    @Test("T01 double Record creates one session; double Stop is idempotent")
    func doubleRecordAndStop() {
        var m = SessionStateMachine()
        #expect(m.handle(.recordRequested(screenMicContract)) == [.checkResources])
        let gen = m.generation
        #expect(m.handle(.recordRequested(screenMicContract)).isEmpty)
        #expect(m.generation == gen)

        var s = started()
        let first = s.handle(.stopRequested, generation: s.generation)
        #expect(first.contains(.stopCapture))
        #expect(s.lifecycle == .stopping)
        #expect(s.handle(.stopRequested, generation: s.generation).isEmpty)
        #expect(s.lifecycle == .stopping)
    }

    @Test("T02 picker cancel and permission denial are distinct, with no success claim")
    func cancelAndDeny() {
        var a = SessionStateMachine()
        _ = a.handle(.recordRequested(screenMicContract))
        _ = a.handle(.resourcesReady, generation: a.generation)
        _ = a.handle(.selectionCancelled, generation: a.generation)
        #expect(a.lifecycle == .cancelled)
        #expect(a.nonCaptureOutcome == .userCancelled)
        #expect(a.finalOutcome == nil)

        var b = SessionStateMachine()
        _ = b.handle(.recordRequested(screenMicContract))
        _ = b.handle(.resourcesReady, generation: b.generation)
        _ = b.handle(.permissionDenied, generation: b.generation)
        #expect(b.nonCaptureOutcome == .permissionDenied)

        var c = SessionStateMachine()
        _ = c.handle(.recordRequested(screenMicContract))
        _ = c.handle(.resourcesReady, generation: c.generation)
        _ = c.handle(.unsupported, generation: c.generation)
        #expect(c.nonCaptureOutcome == .unsupported)
        #expect(c.lifecycle == .failed)
        #expect(c.canStartNewSession)
    }

    @Test("T03 no media by the startup deadline is an explicit failed start")
    func startupDeadline() {
        var m = SessionStateMachine()
        _ = m.handle(.recordRequested(screenMicContract))
        _ = m.handle(.resourcesReady, generation: m.generation)
        let effects = m.handle(.selectionAccepted(microphoneEnabled: true), generation: m.generation)
        #expect(effects.contains(.schedule(.startup, seconds: 15)))
        _ = m.handle(.deadlineExpired(.startup), generation: m.generation)
        #expect(m.lifecycle == .stopping)
        #expect(m.captureEndReason == .sourceNeverArrived)
    }

    @Test("T04 events from an old generation never mutate the new session")
    func staleGeneration() {
        var m = started()
        let old = m.generation
        _ = m.handle(.stopRequested, generation: old)
        _ = m.handle(.drainCompleted, generation: old)
        _ = m.handle(.finalizeCompleted(.saved), generation: old)
        _ = m.handle(.writerClosed, generation: old)
        _ = m.handle(.reset, generation: old)
        _ = m.handle(.recordRequested(screenMicContract))
        #expect(m.generation == old + 1)
        _ = m.handle(.captureEnded(reason: .streamStoppedBySystem), generation: old)
        #expect(m.lifecycle == .preparing)
    }

    @Test("Picker wait is not recording; Stop while choosing cancels cleanly")
    func stopDuringPicker() {
        var m = SessionStateMachine()
        _ = m.handle(.recordRequested(screenMicContract))
        _ = m.handle(.resourcesReady, generation: m.generation)
        #expect(m.lifecycle == .awaitingUserSelection)
        #expect(!m.lifecycle.isCapturing)
        _ = m.handle(.stopRequested, generation: m.generation)
        #expect(m.lifecycle == .cancelled)
        #expect(!m.writerLeaseHeld)
    }

    @Test("T21 finalization timeout preserves recovery and keeps the writer lease until closed")
    func finalizationTimeout() {
        var m = started()
        _ = m.handle(.stopRequested, generation: m.generation)
        _ = m.handle(.drainCompleted, generation: m.generation)
        #expect(m.lifecycle == .finalizing)
        let effects = m.handle(.deadlineExpired(.finalization), generation: m.generation)
        #expect(effects.contains(.preserveRecovery))
        #expect(m.lifecycle == .failed)
        #expect(m.recoveryPending)
        #expect(m.writerLeaseHeld)
        #expect(!m.canStartNewSession)   // single-writer invariant (section 8)
        _ = m.handle(.writerClosed, generation: m.generation)
        #expect(m.canStartNewSession)
    }

    @Test("T22 media services reset invalidates and requires a new user action")
    func mediaReset() {
        var m = started()
        let effects = m.handle(.mediaServicesReset, generation: m.generation)
        #expect(effects.contains(.stopCapture))
        #expect(m.lifecycle == .stopping)
        #expect(m.captureEndReason == .mediaServicesReset)
        #expect(!effects.contains(.startCapture))
    }

    @Test("System stop is authoritative and drains accepted data")
    func systemStop() {
        var m = started()
        let effects = m.handle(.captureEnded(reason: .streamStoppedBySystem), generation: m.generation)
        #expect(effects.contains(.freezeCutoff))
        #expect(effects.contains(.beginDrain))
        #expect(m.captureEndReason == .streamStoppedBySystem)
    }

    @Test("Property: random event permutations keep invariants")
    func randomPermutations() {
        let events: [SessionEvent] = [
            .resourcesReady, .resourcesInsufficient, .selectionAccepted(microphoneEnabled: true), .selectionCancelled,
            .permissionDenied, .unsupported, .firstMediaAccepted, .stopRequested, .captureEnded(reason: nil),
            .drainCompleted, .finalizeCompleted(.saved), .finalizeFailed, .writerClosed, .deadlineExpired(.startup),
            .deadlineExpired(.drain), .deadlineExpired(.finalization), .mediaServicesReset, .reset,
        ]
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<500 {
            var m = SessionStateMachine()
            _ = m.handle(.recordRequested(screenMicContract))
            for _ in 0..<30 {
                let e = events.randomElement(using: &rng)!
                let before = m.lifecycle
                _ = m.handle(e, generation: m.generation)
                // A finalized outcome only follows finalizing.
                if m.lifecycle == .finalized { #expect(before == .finalizing || before == .finalized) }
                // Capture cannot be claimed without first media.
                if m.lifecycle == .capturing { #expect(m.hasCapturedMedia) }
                // A new session never starts while the writer lease is held.
                if m.writerLeaseHeld { #expect(!m.canStartNewSession) }
            }
        }
    }
}
