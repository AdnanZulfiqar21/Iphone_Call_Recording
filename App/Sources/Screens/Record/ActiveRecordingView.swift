import SwiftUI
import CallCaptureCore

/// Active recording hierarchy (section 14.5):
/// primary — lifecycle, elapsed time, Stop; secondary — per-source observations;
/// persistent — every known missing interval; context — storage and next step.
struct ActiveRecordingView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var showDetails = false
    @State private var announcedGaps = 0

    var body: some View {
        let s = model.session
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: DS.Space.l) {
                    header(s)
                    if s.lifecycle == .awaitingUserSelection || s.lifecycle == .preparing {
                        InlineNotice(text: String(localized: "Choose what to share in the iOS sheet. Nothing is recorded until you confirm."), tone: .accent)
                    } else {
                        sources(s)
                        notices(s)
                        if s.lifecycle == .capturing || s.lifecycle == .starting {
                            DisclosureGroup(isExpanded: $showDetails) {
                                details(s).padding(.top, DS.Space.s)
                            } label: {
                                Text("Details").font(.subheadline.weight(.semibold))
                            }
                            .frame(minHeight: DS.Size.minimumTarget)
                        }
                    }
                }
                .padding(.horizontal, DS.Space.margin)
                .padding(.top, DS.Space.l)
            }
            // Stop stays on screen at every text size; secondary details scroll (UX03).
            stopArea(s)
        }
        .background(DS.Palette.surface)
        .navigationTitle(String(localized: "Record"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: s.anomalies.open().count) { _, count in
            // Announce new limitations once; never every timer tick (section 14.8).
            if count > announcedGaps {
                AccessibilityNotification.Announcement(String(localized: "Part of the recording is missing. It stays in the report.")).post()
            }
            announcedGaps = count
        }
        .onChange(of: s.lifecycle) { _, lifecycle in
            if lifecycle == .stopping {
                AccessibilityNotification.Announcement(String(localized: "Recording stopped. Saving.")).post()
            }
        }
    }

    @ViewBuilder private func header(_ s: SessionSnapshot) -> some View {
        let line = s.headline
        VStack(spacing: DS.Space.s) {
            HStack(spacing: DS.Space.s) {
                if line.tone == .recording {
                    RecordingDot()
                } else {
                    Image(systemName: line.tone.symbol).foregroundStyle(line.tone.color).accessibilityHidden(true)
                }
                Text(StatusCopy.text(line.message))
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("sessionHeadline")
            }
            if s.lifecycle != .awaitingUserSelection && s.lifecycle != .preparing {
                // The timer counts actual capture time only (section 14.5).
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Text(StatusCopy.duration(model.session.elapsed))
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .scaleEffect(typeSize.isAccessibilitySize ? 1 : 1.35)
                        .padding(.vertical, typeSize.isAccessibilitySize ? 0 : DS.Space.s)
                        .accessibilityLabel(Text("Elapsed recording time"))
                        .accessibilityValue(Text(StatusCopy.duration(model.session.elapsed)))
                        .accessibilityIdentifier("elapsedTimer")
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder private func sources(_ s: SessionSnapshot) -> some View {
        if !s.sources.isEmpty {
            VStack(spacing: 0) {
                ForEach(s.sources, id: \.source) { status in
                    SourceStatusRow(status: status, lifecycle: s.lifecycle,
                                    showMeter: settings.showInputMeter && s.resourceState.allowsOptionalVisuals)
                        .padding(.horizontal, DS.Space.l)
                        .padding(.vertical, DS.Space.s)
                    if status.source != s.sources.last?.source { Divider().padding(.leading, 58) }
                }
            }
            .background(DS.Palette.card, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
        }
    }

    @ViewBuilder private func notices(_ s: SessionSnapshot) -> some View {
        // Persistent: an earlier gap stays visible after the source resumes (rule 15).
        ForEach(StatusPresenter.persistentNotices(s.anomalies), id: \.self) { notice in
            InlineNotice(text: StatusCopy.text(notice.message))
                .accessibilityIdentifier("gapNotice")
        }
        if s.sources.contains(where: { $0.source == .appAudio && $0.health != .checksPassing }) && s.lifecycle == .capturing {
            InlineNotice(text: String(localized: "App audio isn't confirmed. iOS may not provide another app's call audio; the microphone may still pick up a speaker."),
                         tone: .neutral)
        }
        if s.lifecycle == .stopping || s.lifecycle == .finalizing {
            InlineNotice(text: String(localized: "Capture is off. Your file is being saved — you can leave this screen."), tone: .accent)
        }
    }

    private func details(_ s: SessionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.s) {
            ForEach(s.sources, id: \.source) { status in
                HStack {
                    Text(status.source.displayName)
                    Spacer()
                    Text(status.secondsSinceProgress.map { String(localized: "last input \(String(format: "%.1f", $0)) s ago") }
                         ?? String(localized: "no input yet"))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.footnote)
            }
            Text("Space: \(model.storageEstimate)").font(.footnote).foregroundStyle(.secondary)
            Text("Input levels show sound reaching CallCapture. They don't prove that everyone in a call was recorded.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func stopArea(_ s: SessionSnapshot) -> some View {
        VStack(spacing: DS.Space.s) {
            switch s.lifecycle {
            case .preparing, .awaitingUserSelection:
                PrimaryActionButton(title: String(localized: "Cancel"), systemImage: "xmark", style: .tinted) { model.stop() }
                    .accessibilityIdentifier("cancelStartButton")
            case .starting, .capturing:
                RecordingControl(isActive: true, stopAcknowledged: s.stopRequested, canStart: false, disabledReason: nil,
                                 onStart: {}, onStop: model.stop)
            case .stopping, .finalizing:
                HStack(spacing: DS.Space.s) {
                    ProgressView()
                    Text(StatusCopy.text(.savingFile)).font(.callout)
                }
                .frame(maxWidth: .infinity, minHeight: DS.Size.primaryControlHeight)
            default:
                EmptyView()
            }
        }
        .padding(DS.Space.margin)
        .background(.bar)
    }
}

/// Recording indicator. Pulses only when motion is allowed; it is never health evidence.
struct RecordingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dim = false

    var body: some View {
        Circle()
            .fill(DS.Palette.record)
            .frame(width: 12, height: 12)
            .opacity(dim ? 0.4 : 1)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { dim = true }
            }
            .accessibilityHidden(true)
    }
}
