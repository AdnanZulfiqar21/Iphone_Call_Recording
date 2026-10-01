import UIKit
import SwiftUI
import CallCaptureCore

/// Saved result (section 14.3): outcome headline, duration, completeness and file checks,
/// then Play and Share. Partial results keep their limitations; no celebration for missing media.
struct SavedResultView: View {
    @Environment(AppModel.self) private var model
    let metadata: RecordingMetadata
    @State private var openPlayer = false

    var body: some View {
        ScrollView {
            VStack(spacing: DS.Space.l) {
                RecordingSummary(metadata: metadata)
                    .padding(.top, DS.Space.l)
                    .accessibilityIdentifier("resultSummary")
                VStack(spacing: 0) {
                    ForEach(metadata.sources, id: \.source) { s in
                        sourceLine(s)
                            .padding(.horizontal, DS.Space.l)
                            .padding(.vertical, DS.Space.s)
                        Divider().padding(.leading, DS.Space.l)
                    }
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("File checks").font(.body.weight(.medium))
                            Text(StatusCopy.validation(metadata.validation)).font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        StatusPill(text: metadata.validation == .failed ? String(localized: "Problem") : String(localized: "Basic"),
                                   tone: metadata.validation == .failed ? .warning : (metadata.validation == .fullChecksPassed ? .pass : .neutral))
                    }
                    .padding(.horizontal, DS.Space.l)
                    .padding(.vertical, DS.Space.m)
                }
                .background(DS.Palette.card, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))

                if !metadata.unmetRequirements.isEmpty {
                    InlineNotice(text: String(localized: "Important Recording mode: \(metadata.unmetRequirements.map(\.displayName).formatted()) wasn't confirmed. This is kept in the report."))
                }
                Text("Participant completeness can't be confirmed automatically. Play the recording to check it.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Space.margin)
        }
        .background(DS.Palette.surface)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: DS.Space.s) {
                HStack(spacing: DS.Space.s) {
                    PrimaryActionButton(title: String(localized: "Play"), systemImage: "play.fill", style: .accent) { openPlayer = true }
                        .accessibilityIdentifier("resultPlayButton")
                    if let url = model.masterURL(metadata.id) {
                        ShareLink(item: url) {
                            Label("Share", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: DS.Size.primaryControlHeight)
                        }
                        .buttonStyle(ActionButtonStyle(style: .tinted))
                    }
                }
                if metadata.hasKnownGaps {
                    Button("Review missing sections") { openPlayer = true }
                        .frame(minHeight: DS.Size.minimumTarget)
                }
                Button("New recording") { model.acknowledgeResult() }
                    .frame(minHeight: DS.Size.minimumTarget)
                    .accessibilityIdentifier("newRecordingButton")
            }
            .padding(DS.Space.margin)
            .background(.bar)
        }
        .navigationTitle(String(localized: "Saved"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $openPlayer) { PlayerView(recordingID: metadata.id) }
    }

    private func sourceLine(_ s: SourceSummary) -> some View {
        let missing = metadata.openAnomalies.filter { $0.source == s.source }
        let (text, tone): (String, StatusTone) = {
            if !s.everReceived { return (s.requirement == .optional ? String(localized: "Not received during this recording") : String(localized: "Not received"),
                                         s.requirement == .optional ? .neutral : .warning) }
            if missing.isEmpty { return (String(localized: "No known gaps"), .pass) }
            let ranges = missing.prefix(3).map(\.range.description).formatted()
            return (String(localized: "Missing \(ranges)"), .warning)
        }()
        return HStack {
            Image(systemName: s.source.symbol).foregroundStyle(DS.Palette.accent).frame(width: 24).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.source.displayName).font(.body.weight(.medium))
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            StatusPill(text: tone == .pass ? String(localized: "Complete") : (tone == .neutral ? String(localized: "Unconfirmed") : String(localized: "Partial")),
                       tone: tone)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Cancelled, denied, unsupported or failed-before-media outcomes: calm and actionable (UX10).
struct NonCaptureResultView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.openURL) private var openURL

    var body: some View {
        let s = model.session
        VStack(spacing: DS.Space.xl) {
            Spacer()
            Image(systemName: icon(s)).font(.system(size: 40)).foregroundStyle(DS.Palette.neutral).accessibilityHidden(true)
            Text(StatusCopy.text(s.headline.message))
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("nonCaptureHeadline")
            Text(explanation(s))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            VStack(spacing: DS.Space.s) {
                PrimaryActionButton(title: String(localized: "Back to Record"), systemImage: "arrow.uturn.backward", style: .accent) {
                    model.acknowledgeResult()
                }
                .accessibilityIdentifier("backToRecordButton")
                if s.nonCaptureOutcome == .permissionDenied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    }
                    .frame(minHeight: DS.Size.minimumTarget)
                }
                if s.nonCaptureOutcome == .insufficientStorage {
                    Button("Manage storage") {
                        model.acknowledgeResult()
                        model.selectedTab = .settings
                    }
                    .frame(minHeight: DS.Size.minimumTarget)
                }
            }
        }
        .padding(DS.Space.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Palette.surface)
    }

    private func icon(_ s: SessionSnapshot) -> String {
        switch s.nonCaptureOutcome {
        case .permissionDenied: return "hand.raised"
        case .unsupported, .captureUnavailable: return "rectangle.slash"
        case .insufficientStorage: return "internaldrive"
        default: return s.finalOutcome == .failed ? "exclamationmark.triangle" : "xmark.circle"
        }
    }

    private func explanation(_ s: SessionSnapshot) -> String {
        switch s.nonCaptureOutcome {
        case .userCancelled: return String(localized: "Nothing was recorded. Start again whenever you're ready.")
        case .permissionDenied: return String(localized: "iOS didn't allow screen recording. You can try again, or check Screen Time and privacy settings.")
        case .unsupported, .captureUnavailable: return String(localized: "This iPhone or iOS version doesn't offer the screen recording CallCapture uses (iOS 27 or later).")
        case .insufficientStorage: return String(localized: "CallCapture keeps space free so a recording can always be finished and saved. Free up space and try again.")
        case nil:
            if s.endReason == .sourceNeverArrived { return String(localized: "No media arrived after starting, so nothing was saved.") }
            return String(localized: "Any media that was saved is kept and can be recovered from Recordings.")
        }
    }
}
