import Foundation

public enum SessionDeadline: String, Sendable, Hashable, CaseIterable {
    case startup
    case stopAcknowledgement
    case drain
    case finalization
}

public enum SessionEvent: Sendable, Equatable {
    case recordRequested(CaptureContract)
    case resourcesReady
    case resourcesInsufficient
    case selectionAccepted(microphoneEnabled: Bool)
    case selectionCancelled
    case permissionDenied
    case unsupported
    case firstMediaAccepted
    case stopRequested
    /// The capture stream ended; `reason` is nil for an acknowledged user Stop.
    case captureEnded(reason: ReasonCode?)
    case drainCompleted
    case finalizeCompleted(FinalOutcome)
    case finalizeFailed
    case writerClosed
    case deadlineExpired(SessionDeadline)
    case mediaServicesReset
    case reset
}

public enum SessionEffect: Sendable, Equatable {
    case checkResources
    case presentPicker
    case startCapture
    case stopCapture
    case freezeCutoff
    case beginDrain
    case finalizeWriter
    case cancelWriter
    case preserveRecovery
    case releaseResources
    case schedule(SessionDeadline, seconds: Double)
    case cancel(SessionDeadline)
}

/// The authoritative lifecycle (section 8). Pure and deterministic: callers apply effects.
/// One active session at a time (rule 1); stale generations are rejected (rule 8, T04).
public struct SessionStateMachine: Sendable {
    public private(set) var lifecycle: Lifecycle = .idle
    public private(set) var sessionID: UUID?
    public private(set) var generation = 0
    public private(set) var contract: CaptureContract?
    public private(set) var nonCaptureOutcome: NonCaptureOutcome?
    public private(set) var finalOutcome: FinalOutcome?
    public private(set) var captureEndReason: ReasonCode?
    public private(set) var stopRequested = false
    /// True while a media writer may still write; no new session may start (section 8).
    public private(set) var writerLeaseHeld = false
    public private(set) var hasCapturedMedia = false
    public private(set) var recoveryPending = false
    public let profile: AcceptanceProfile

    public init(profile: AcceptanceProfile = .v1) { self.profile = profile }

    public var canStartNewSession: Bool {
        !lifecycle.isActive && !writerLeaseHeld
    }

    public var identity: SessionIdentity? {
        guard let id = sessionID, let c = contract else { return nil }
        return SessionIdentity(sessionID: id, generation: generation, contractVersion: c.version)
    }

    /// Applies an event for `eventGeneration`. Events from other generations are ignored.
    public mutating func handle(_ event: SessionEvent, generation eventGeneration: Int? = nil, newSessionID: UUID = UUID()) -> [SessionEffect] {
        if case .recordRequested(let c) = event {
            guard canStartNewSession else { return [] }   // double Record is a no-op (T01)
            generation += 1
            sessionID = newSessionID
            contract = c
            lifecycle = .preparing
            nonCaptureOutcome = nil
            finalOutcome = nil
            captureEndReason = nil
            stopRequested = false
            hasCapturedMedia = false
            recoveryPending = false
            return [.checkResources]
        }
        if let g = eventGeneration, g != generation { return [] }

        switch (lifecycle, event) {
        case (.preparing, .resourcesReady):
            lifecycle = .awaitingUserSelection
            return [.presentPicker]
        case (.preparing, .resourcesInsufficient):
            return endWithoutCapture(.insufficientStorage, lifecycle: .failed)

        case (.awaitingUserSelection, .selectionAccepted):
            lifecycle = .starting
            writerLeaseHeld = true
            // Picker wait is excluded; the startup deadline begins after selection (section 8).
            return [.startCapture, .schedule(.startup, seconds: profile.startupDeadline)]
        case (.awaitingUserSelection, .selectionCancelled):
            return endWithoutCapture(.userCancelled, lifecycle: .cancelled)
        case (.awaitingUserSelection, .permissionDenied), (.starting, .permissionDenied):
            return endWithoutCapture(.permissionDenied, lifecycle: .cancelled)
        case (.awaitingUserSelection, .unsupported), (.starting, .unsupported):
            return endWithoutCapture(.unsupported, lifecycle: .failed)
        case (.awaitingUserSelection, .stopRequested), (.preparing, .stopRequested):
            return endWithoutCapture(.userCancelled, lifecycle: .cancelled)

        case (.starting, .firstMediaAccepted):
            lifecycle = .capturing
            hasCapturedMedia = true
            return []
        case (.starting, .deadlineExpired(.startup)):
            // No media at all by the deadline: an explicit failed start, never success (T03).
            lifecycle = .stopping
            captureEndReason = .sourceNeverArrived
            return [.stopCapture, .freezeCutoff, .beginDrain, .schedule(.drain, seconds: profile.drainDeadline)]
        case (.capturing, .deadlineExpired(.startup)):
            return []   // per-source startup evaluation is the HealthVerifier's job

        case (.starting, .stopRequested), (.capturing, .stopRequested):
            stopRequested = true
            lifecycle = .stopping
            return [.freezeCutoff, .stopCapture, .cancel(.startup),
                    .schedule(.stopAcknowledgement, seconds: profile.stopAcknowledgement),
                    .beginDrain, .schedule(.drain, seconds: profile.drainDeadline)]
        case (.stopping, .stopRequested), (.finalizing, .stopRequested):
            return []   // idempotent Stop (T01)

        case (.starting, .captureEnded(let reason)), (.capturing, .captureEnded(let reason)):
            // System or stream stop is authoritative (rule 5): stop ingesting, finish accepted data.
            lifecycle = .stopping
            captureEndReason = reason ?? captureEndReason
            return [.freezeCutoff, .cancel(.startup), .beginDrain, .schedule(.drain, seconds: profile.drainDeadline)]
        case (.stopping, .captureEnded(let reason)):
            if captureEndReason == nil { captureEndReason = reason }
            return [.cancel(.stopAcknowledgement)]

        case (.stopping, .deadlineExpired(.stopAcknowledgement)):
            return []   // capture-off is shown independently; drain continues under its own deadline

        case (.stopping, .drainCompleted), (.stopping, .deadlineExpired(.drain)):
            lifecycle = .finalizing
            return [.cancel(.drain), .cancel(.stopAcknowledgement), .finalizeWriter, .schedule(.finalization, seconds: profile.finalizationDeadline)]

        case (.finalizing, .finalizeCompleted(let outcome)):
            lifecycle = outcome == .failed ? .failed : .finalized
            finalOutcome = outcome
            writerLeaseHeld = false
            return [.cancel(.finalization), .releaseResources]
        case (.finalizing, .finalizeFailed):
            lifecycle = .failed
            finalOutcome = .failed
            recoveryPending = true
            writerLeaseHeld = false
            return [.cancel(.finalization), .preserveRecovery, .releaseResources]
        case (.finalizing, .deadlineExpired(.finalization)):
            // A timeout does not prove the writer closed: keep the lease until it confirms (section 8).
            lifecycle = .failed
            finalOutcome = .failed
            recoveryPending = true
            captureEndReason = captureEndReason ?? .finalizationTimeout
            return [.preserveRecovery, .cancelWriter]
        case (_, .writerClosed):
            writerLeaseHeld = false
            return lifecycle.isActive ? [] : [.releaseResources]

        case (.starting, .mediaServicesReset), (.capturing, .mediaServicesReset), (.stopping, .mediaServicesReset):
            // Invalidate and close safely; restart requires a new user action (section 8, T22).
            captureEndReason = .mediaServicesReset
            if lifecycle == .stopping { return [] }
            lifecycle = .stopping
            return [.freezeCutoff, .stopCapture, .cancel(.startup), .beginDrain, .schedule(.drain, seconds: profile.drainDeadline)]

        case (.finalized, .reset), (.cancelled, .reset), (.failed, .reset):
            guard !writerLeaseHeld else { return [] }
            lifecycle = .idle
            return []

        default:
            return []
        }
    }

    /// Replaces the contract with a new segment before capture starts (explicit user choice only).
    public mutating func adoptContract(_ c: CaptureContract) {
        guard lifecycle == .awaitingUserSelection || lifecycle == .preparing else { return }
        contract = c
    }

    private mutating func endWithoutCapture(_ outcome: NonCaptureOutcome, lifecycle newState: Lifecycle) -> [SessionEffect] {
        nonCaptureOutcome = outcome
        lifecycle = newState
        writerLeaseHeld = false
        return [.cancel(.startup), .stopCapture, .releaseResources]
    }
}
