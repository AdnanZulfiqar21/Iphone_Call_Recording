import ActivityKit
import Foundation
import CallCaptureCore

/// Projects session state to a Live Activity with a stale date (section 14.9, T32).
/// Missing permission or disabled activities never affect recording.
@MainActor
final class LiveActivityController {
    private var activity: Activity<RecordingActivityAttributes>?
    private var lastState: RecordingActivityAttributes.ContentState?
    private var lastPush = Date.distantPast
    /// Projected status older than this is shown as stale by the system.
    static let staleAfter: TimeInterval = 45

    private(set) var isEnabledBySystem = ActivityAuthorizationInfo().areActivitiesEnabled

    func update(with snapshot: SessionSnapshot) {
        let phase: RecordingActivityAttributes.ContentState.Phase? = switch snapshot.lifecycle {
        case .starting: .starting
        case .capturing: snapshot.sources.contains { $0.health == .limited || ($0.requirement == .required && $0.health == .unavailable) } ? .limited : .recording
        case .stopping: .stopping
        case .finalizing: .saving
        case .finalized, .failed, .cancelled: .ended
        case .idle, .preparing, .awaitingUserSelection: nil
        }
        guard let phase else { return }
        let state = RecordingActivityAttributes.ContentState(
            phase: phase,
            headline: StatusCopy.text(snapshot.headline.message),
            captureStartedAt: snapshot.lifecycle == .capturing ? Date().addingTimeInterval(-snapshot.elapsed) : nil,
            elapsedAtUpdate: snapshot.elapsed,
            updatedAt: Date(),
            gapCount: snapshot.anomalies.open().count)
        // Throttle cosmetic updates; phase and gap changes are pushed immediately.
        let significant = state.phase != lastState?.phase || state.gapCount != lastState?.gapCount
        guard significant || Date().timeIntervalSince(lastPush) > 15 else { return }
        lastState = state
        lastPush = Date()
        isEnabledBySystem = ActivityAuthorizationInfo().areActivitiesEnabled

        if phase == .ended {
            let content = ActivityContent(state: state, staleDate: nil)
            let current = activity
            activity = nil
            lastState = nil
            Task { await current?.end(content, dismissalPolicy: .after(Date().addingTimeInterval(60))) }
            return
        }
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(Self.staleAfter))
        if let activity {
            Task { await activity.update(content) }
        } else if isEnabledBySystem {
            activity = try? Activity.request(attributes: RecordingActivityAttributes(title: String(localized: "CallCapture")),
                                             content: content, pushType: nil)
        }
    }
}
