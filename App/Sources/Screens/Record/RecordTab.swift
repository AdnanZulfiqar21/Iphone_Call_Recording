import SwiftUI
import CallCaptureCore

/// Record tab: the dashboard when idle, the session while active, the result when finished.
/// Switching tabs and back restores the same session (UX07).
struct RecordTab: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            Group {
                switch model.session.lifecycle {
                case .idle:
                    RecordDashboardView()
                case .preparing, .awaitingUserSelection, .starting, .capturing, .stopping, .finalizing:
                    ActiveRecordingView()
                case .finalized, .failed:
                    if let id = model.session.savedRecordingID, let m = model.metadata(id) {
                        SavedResultView(metadata: m)
                    } else {
                        NonCaptureResultView()
                    }
                case .cancelled:
                    NonCaptureResultView()
                }
            }
            .animation(DS.Motion.standard(reduceMotion), value: model.session.lifecycle)
        }
    }
}

struct RecordDashboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var showOptions = false
    @State private var showSetup = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.l) {
                if !model.recoveredNotice.isEmpty || !model.recoveryCandidates.isEmpty {
                    RecoveryBanner()
                }
                Card {
                    summaryRow(String(localized: "Capture"), settings.scopeDescription, action: { showOptions = true }, id: "captureOptionsButton")
                    Divider()
                    summaryRow(String(localized: "Setup"), String(localized: "Review checks"), action: { showSetup = true }, id: "setupRowButton")
                    Divider()
                    summaryRow(String(localized: "Space"), model.storageEstimate, action: nil, id: nil)
                    if settings.importantMode {
                        Divider()
                        Label("Important Recording mode is on", systemImage: "exclamationmark.shield")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                if settings.captureMode != .audioOnly {
                    InlineNotice(text: String(localized: "Full-screen recording includes notifications and other apps you open. It keeps going after a call ends until you tap Stop."),
                                 tone: .accent)
                }
                RecordingControl(isActive: false, stopAcknowledged: false, canStart: model.startDisabledReason == nil,
                                 disabledReason: model.startDisabledReason, onStart: model.requestStart, onStop: {})
                RecentRecordings()
            }
            .padding(.horizontal, DS.Space.margin)
            .padding(.bottom, DS.Space.xl)
        }
        .background(DS.Palette.surface)
        .navigationTitle(String(localized: "Record"))
        .sheet(isPresented: $showOptions) { CaptureOptionsSheet() }
        .navigationDestination(isPresented: $showSetup) { SetupGuideView() }
        .refreshable { model.refreshStorage() }
    }

    private func summaryRow(_ title: String, _ value: String, action: (() -> Void)?, id: String?) -> some View {
        Button {
            action?()
        } label: {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer(minLength: DS.Space.m)
                Text(value)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(action == nil ? Color.primary : DS.Palette.accent)
                if action != nil { Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary).accessibilityHidden(true) }
            }
            .frame(minHeight: DS.Size.minimumTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .accessibilityIdentifier(id ?? "")
    }
}

struct RecentRecordings: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let recent = LibraryQuery().apply(to: model.library).prefix(3)
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: DS.Space.s) {
                Text("Recent").font(.headline).accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(Array(recent)) { row in
                        NavigationLink(value: row.id) {
                            RecordingRow(row: row).padding(.horizontal, DS.Space.l).padding(.vertical, DS.Space.s)
                        }
                        .buttonStyle(.plain)
                        if row.id != recent.last?.id { Divider().padding(.leading, DS.Space.l) }
                    }
                }
                .background(DS.Palette.card, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
            }
            .navigationDestination(for: UUID.self) { id in PlayerView(recordingID: id) }
        }
    }
}

/// Advanced configuration lives in a secondary sheet (section 14.3).
struct CaptureOptionsSheet: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Picker("What to record", selection: $settings.captureMode) {
                        Text("Screen and audio").tag(CaptureMode.screenAndAudio)
                        Text("Screen only").tag(CaptureMode.screenOnly)
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("What to record")
                }
                if settings.captureMode != .screenOnly {
                    Section {
                        Toggle("Include microphone", isOn: $settings.includeMicrophone)
                    } footer: {
                        Text("You can also turn the microphone on or off in the iOS sharing sheet. App audio is captured only if iOS provides it.")
                    }
                }
                Section {
                    Toggle("Important Recording mode", isOn: $settings.importantMode)
                } footer: {
                    Text("Requires every selected audio source. If one isn't confirmed shortly after starting, CallCapture keeps what was captured and stops safely instead of continuing silently.")
                }
            }
            .navigationTitle(String(localized: "Capture options"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }
}
