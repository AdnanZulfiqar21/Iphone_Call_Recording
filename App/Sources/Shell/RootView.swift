import SwiftUI
import CallCaptureCore

/// Three primary tabs (section 14.3). Returning to Record restores the active session.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(AppLockService.self) private var appLock
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        ZStack {
            if settings.hasCompletedOnboarding {
                TabView(selection: $model.selectedTab) {
                    Tab(String(localized: "Record"), systemImage: "record.circle", value: AppTab.record) {
                        RecordTab()
                    }
                    Tab(String(localized: "Recordings"), systemImage: "list.bullet", value: AppTab.recordings) {
                        LibraryView()
                    }
                    Tab(String(localized: "Settings"), systemImage: "gearshape", value: AppTab.settings) {
                        SettingsView()
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if model.isSessionActive && model.selectedTab != .record {
                        ActiveSessionStrip()
                    }
                }
            } else {
                WelcomeView()
            }

            if appLock.isLocked {
                AppLockView()
                    .transition(.opacity)
            }
            // App-switcher snapshot redaction (section 13).
            if settings.hidePreviews && scenePhase != .active {
                PrivacyShield()
            }
        }
        .sheet(isPresented: $model.pendingStartAfterReminder) {
            ConsentReminderSheet()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background && settings.appLockEnabled { appLock.lock() }
            if phase == .active { model.refreshStorage() }
        }
        .onAppear {
            if settings.appLockEnabled { appLock.lock() }
        }
        .onOpenURL { url in
            // Live Activity route back to the session (section 14.9).
            if url.host == "record" { model.selectedTab = .record }
        }
    }
}

/// Unobtrusive route back to the active recording, with a direct Stop (section 14.3).
struct ActiveSessionStrip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: DS.Space.s) {
            Circle().fill(.white).frame(width: 8, height: 8).accessibilityHidden(true)
            Button {
                model.selectedTab = .record
            } label: {
                Text(stripTitle)
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, minHeight: DS.Size.minimumTarget, alignment: .leading)
            }
            .accessibilityHint(Text("Opens the recording screen"))
            if model.session.lifecycle == .capturing || model.session.lifecycle == .starting {
                Button(String(localized: "Stop")) { model.stop() }
                    .font(.footnote.weight(.bold))
                    .padding(.horizontal, DS.Space.m)
                    .frame(minHeight: 32)
                    .background(.white.opacity(0.25), in: Capsule())
                    .accessibilityIdentifier("stripStopButton")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, DS.Space.l)
        .background(DS.Palette.recordButton)
        .accessibilityElement(children: .contain)
    }

    private var stripTitle: String {
        switch model.session.lifecycle {
        case .capturing: return String(localized: "Recording \(StatusCopy.duration(model.session.elapsed))")
        case .stopping, .finalizing: return StatusCopy.text(.savingFile)
        default: return StatusCopy.text(model.session.headline.message)
        }
    }
}

struct PrivacyShield: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.background)
            VStack(spacing: DS.Space.m) {
                Image(systemName: "lock.shield").font(.system(size: 44)).foregroundStyle(DS.Palette.accent)
                Text("CallCapture").font(.title2.weight(.semibold))
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Lock overlay. Stop stays reachable during an active recording (section 14.5).
struct AppLockView: View {
    @Environment(AppLockService.self) private var appLock
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: DS.Space.xl) {
            Spacer()
            Image(systemName: "lock.fill").font(.system(size: 48)).foregroundStyle(DS.Palette.accent)
            Text("CallCapture is locked").font(.title2.weight(.bold))
            Text("Your recordings stay on this iPhone.").foregroundStyle(.secondary)
            PrimaryActionButton(title: String(localized: "Unlock with \(appLock.biometryName)"), systemImage: "faceid", style: .accent) {
                Task { await appLock.unlock() }
            }
            if let error = appLock.lastError {
                Text(error).font(.footnote).foregroundStyle(DS.Palette.warning)
            }
            Spacer()
            if model.session.lifecycle == .capturing {
                RecordingControl(isActive: true, stopAcknowledged: model.session.stopRequested, canStart: false,
                                 disabledReason: nil, onStart: {}, onStop: model.stop)
            }
        }
        .padding(DS.Space.margin)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Palette.surface)
        .task { await appLock.unlock() }
    }
}

/// Optional pre-start reminder about telling participants (section 13.2). Dismissible permanently.
struct ConsentReminderSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var dontShowAgain = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Space.l) {
                    Image(systemName: "person.2.wave.2").font(.system(size: 36)).foregroundStyle(DS.Palette.accent)
                        .accessibilityHidden(true)
                    Text("Before you record").font(.title2.weight(.bold))
                    Text("Tell the people you're recording, and follow the law where you are. Recording rules differ between countries and regions.")
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Full-screen recording also captures notifications and anything else you open while it runs.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Toggle("Don't remind me again", isOn: $dontShowAgain)
                        .frame(minHeight: DS.Size.minimumTarget)
                }
                .padding(DS.Space.margin)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: DS.Space.s) {
                    PrimaryActionButton(title: String(localized: "Continue"), systemImage: "record.circle", style: .record) {
                        if dontShowAgain { settings.consentReminder = false }
                        dismiss()
                        model.beginRecording()
                    }
                    .accessibilityIdentifier("consentContinueButton")
                    Button("Cancel") {
                        model.pendingStartAfterReminder = false
                        dismiss()
                    }
                    .frame(minHeight: DS.Size.minimumTarget)
                }
                .padding(DS.Space.margin)
                .background(.bar)
            }
        }
        .presentationDetents([.medium, .large])
    }
}
