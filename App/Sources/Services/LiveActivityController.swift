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

    init() {
        // An activity left by an earlier run (terminated app, crash) must not keep claiming a recording.
        let orphans = Activity<RecordingActivityAttributes>.activities.map(ActivityRef.init)
        Task { for ref in orphans { await ref.activity.end(nil, dismissalPolicy: .immediate) } }
    }

    func update(with snapshot: SessionSnapshot) {
        let phase: RecordingActivityAttributes.ContentState.Phase? = switch snapshot.lifecycle {
        case .starting: .starting
        case .capturing: snapshot.sources.contains { $0.health == .limited || ($0.requirement == .required && $0.health == .unavailable) } ? .limited : .recording
        case .stopping: .stopping
        case .finalizing: .saving
        case .finalized, .failed, .cancelled: .ended
        case .idle, .preparing, .awaitingUserSelection: nil
        }
        // Snapshots are delivered newest-only, so the final phase can be skipped on the way back to
        // idle. Any non-active state with an activity still open ends it (device test 1).
        guard let phase else {
            if activity != nil { endActivity(state: lastState) }
            return
        }
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
            endActivity(state: state)
            return
        }
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(Self.staleAfter))
        if let activity {
            let ref = ActivityRef(activity: activity)
            Task { await ref.activity.update(content) }
        } else if isEnabledBySystem {
            activity = try? Activity.request(attributes: RecordingActivityAttributes(title: String(localized: "CallCapture")),
                                             content: content, pushType: nil)
        }
    }
}

extension LiveActivityController {
    /// Ends the activity at once: after Stop, a lingering "Recording" presentation reads as still
    /// recording. The saved result is shown in the app.
    fileprivate func endActivity(state: RecordingActivityAttributes.ContentState?) {
        let current = activity.map(ActivityRef.init)
        activity = nil
        lastState = nil
        let content = state.map { s -> ActivityContent<RecordingActivityAttributes.ContentState> in
            var ended = s
            ended.phase = .ended
            return ActivityContent(state: ended, staleDate: nil)
        }
        Task { await current?.activity.end(content, dismissalPolicy: .immediate) }
    }
}

/// ActivityKit's Activity is safe to message from any task; this wrapper states that to the
/// region-isolation checker without widening the controller's own isolation.
private struct ActivityRef: @unchecked Sendable {
    let activity: Activity<RecordingActivityAttributes>
}
