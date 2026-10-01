import ActivityKit
import SwiftUI
import WidgetKit

@main
struct CallCaptureWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RecordingLiveActivity()
    }
}

/// Lock Screen and Dynamic Island presentation (section 14.9). Shows last-update context and a
/// clearly stale appearance; elapsed time is never presented as proof of background health.
struct RecordingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            LockScreenView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(Color(.systemBackground))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label { Text(phaseTitle(context.state.phase)) } icon: { indicator(context.state.phase, stale: context.isStale) }
                        .font(.caption.weight(.semibold))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ElapsedText(state: context.state).font(.title3.monospacedDigit().weight(.semibold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.isStale ? String(localized: "Status not updated") : context.state.headline)
                            .font(.caption)
                        Text("Updated \(context.state.updatedAt, style: .time) · Open CallCapture to stop")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                indicator(context.state.phase, stale: context.isStale)
            } compactTrailing: {
                ElapsedText(state: context.state).monospacedDigit().font(.caption2)
            } minimal: {
                indicator(context.state.phase, stale: context.isStale)
            }
            .widgetURL(URL(string: "callcapture://record"))
        }
    }

    @ViewBuilder func indicator(_ phase: RecordingActivityAttributes.ContentState.Phase, stale: Bool) -> some View {
        if stale {
            Image(systemName: "questionmark.circle").foregroundStyle(.gray)
        } else {
            switch phase {
            case .recording: Image(systemName: "record.circle").foregroundStyle(.red)
            case .limited: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            default: Image(systemName: "hourglass").foregroundStyle(.gray)
            }
        }
    }

    func phaseTitle(_ phase: RecordingActivityAttributes.ContentState.Phase) -> String {
        switch phase {
        case .starting: return String(localized: "Starting")
        case .recording: return String(localized: "Recording")
        case .limited: return String(localized: "Recording — limited")
        case .stopping: return String(localized: "Stopping")
        case .saving: return String(localized: "Saving")
        case .ended: return String(localized: "Ended")
        }
    }
}

struct ElapsedText: View {
    let state: RecordingActivityAttributes.ContentState
    var body: some View {
        if let start = state.captureStartedAt, state.phase == .recording || state.phase == .limited {
            Text(timerInterval: start...Date.distantFuture, countsDown: false)
        } else {
            Text(Duration.seconds(state.elapsedAtUpdate).formatted(.time(pattern: .minuteSecond)))
        }
    }
}

struct LockScreenView: View {
    let state: RecordingActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: isStale ? "questionmark.circle" : (state.phase == .limited ? "exclamationmark.triangle.fill" : "record.circle"))
                .font(.title2)
                .foregroundStyle(isStale ? .gray : (state.phase == .limited ? .orange : .red))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(isStale ? String(localized: "Status not updated") : state.headline)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Text(isStale ? String(localized: "Last update \(state.updatedAt.formatted(date: .omitted, time: .shortened)). Open CallCapture to check.")
                             : String(localized: "Updated \(state.updatedAt.formatted(date: .omitted, time: .shortened))\(state.gapCount > 0 ? " · " + String(localized: "missing sections noted") : "")"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ElapsedText(state: state)
                .font(.title2.monospacedDigit().weight(.semibold))
                .opacity(isStale ? 0.5 : 1)
        }
        .padding(16)
        .accessibilityElement(children: .combine)
    }
}
