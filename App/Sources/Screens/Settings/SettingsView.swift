import UIKit
import SwiftUI
import CallCaptureCore

/// Native grouped Settings (section 14.3).
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(EntitlementService.self) private var entitlements

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            List {
                Section {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(AppearancePreference.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("appearancePicker")
                } header: {
                    Text("Appearance")
                }
                Section {
                    NavigationLink { CaptureSettingsView() } label: {
                        SettingsRow(title: String(localized: "Capture"), systemImage: "record.circle", detail: settings.scopeDescription)
                    }
                    NavigationLink { StorageView() } label: {
                        SettingsRow(title: String(localized: "Storage"), systemImage: "internaldrive",
                                    detail: String(localized: "\(StatusCopy.bytes(model.store.usage().recordingsBytes)) used · \(StatusCopy.bytes(model.freeBytes)) free"))
                    }
                    NavigationLink { PrivacySettingsView() } label: {
                        SettingsRow(title: String(localized: "Privacy & App Lock"), systemImage: "lock.shield",
                                    detail: settings.appLockEnabled ? String(localized: "App Lock on") : String(localized: "App Lock off"))
                    }
                }
                Section {
                    NavigationLink { HelpView() } label: {
                        SettingsRow(title: String(localized: "Help & recording laws"), systemImage: "questionmark.circle")
                    }
                    NavigationLink { SetupGuideView() } label: {
                        SettingsRow(title: String(localized: "Test my setup"), systemImage: "checklist")
                    }
                    NavigationLink { DiagnosticsView() } label: {
                        SettingsRow(title: String(localized: "Diagnostics report"), systemImage: "stethoscope")
                    }
                }
                Section {
                    NavigationLink { ProView() } label: {
                        SettingsRow(title: String(localized: "CallCapture Pro"), systemImage: "star",
                                    detail: entitlements.isPro ? String(localized: "Unlocked — thank you") : String(localized: "Optional one-time purchase"))
                    }
                    .accessibilityIdentifier("proRow")
                } footer: {
                    Text("Recording, warnings, playback and your files are always free.")
                }
                Section {
                    LabeledContent(String(localized: "Version"), value: AppInfo.versionString)
                }
            }
            .navigationTitle(String(localized: "Settings"))
        }
    }
}

enum AppInfo {
    static var versionString: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(v) (\(b))"
    }
}

struct CaptureSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Picker("What to record", selection: $settings.captureMode) {
                    Text("Screen and audio").tag(CaptureMode.screenAndAudio)
                    Text("Screen only").tag(CaptureMode.screenOnly)
                }
                if settings.captureMode != .screenOnly {
                    Toggle("Include microphone", isOn: $settings.includeMicrophone)
                }
            }
            Section {
                Toggle("Important Recording mode", isOn: $settings.importantMode)
            } footer: {
                Text("Stops safely, keeping what was captured, if a selected audio source can't be confirmed shortly after starting. Missing-audio warnings are shown in every mode.")
            }
            Section {
                Toggle("Show input level", isOn: $settings.showInputMeter)
                Toggle("Remind me to tell participants", isOn: $settings.consentReminder)
            } footer: {
                Text("The input level shows sound reaching CallCapture. It's hidden automatically if the iPhone is under heavy load.")
            }
        }
        .navigationTitle(String(localized: "Capture"))
    }
}

struct StorageView: View {
    @Environment(AppModel.self) private var model
    @State private var usage: RecordingStore.Usage?
    @State private var confirmClear = false

    var body: some View {
        List {
            if let usage {
                Section {
                    LabeledContent(String(localized: "Recordings"), value: StatusCopy.bytes(usage.recordingsBytes))
                    LabeledContent(String(localized: "Kept for recovery"), value: StatusCopy.bytes(usage.recoveryBytes))
                    LabeledContent(String(localized: "Exported copies"), value: StatusCopy.bytes(usage.exportBytes))
                    LabeledContent(String(localized: "Preview cache"), value: StatusCopy.bytes(usage.cacheBytes))
                    LabeledContent(String(localized: "Free on iPhone"), value: StatusCopy.bytes(model.freeBytes))
                } footer: {
                    Text("Recordings are never deleted automatically. Media kept for recovery isn't a cache and isn't cleared here.")
                }
            }
            Section {
                Button("Clear preview cache") { confirmClear = true }
                    .frame(minHeight: DS.Size.minimumTarget)
            } footer: {
                Text("Removes waveform previews only. They're rebuilt when needed.")
            }
            Section {
                Text("Recordings are stored in CallCapture's private storage and are included in your iPhone or iCloud backup if backups are on. CallCapture doesn't upload recordings. If you lose this iPhone without a backup, recordings you haven't exported are lost.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Backups")
            }
        }
        .navigationTitle(String(localized: "Storage"))
        .onAppear { refresh() }
        .confirmationDialog(String(localized: "Clear preview cache?"), isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear cache") {
                try? model.store.clearCaches()
                refresh()
            }
        }
    }

    private func refresh() {
        model.refreshStorage()
        usage = model.store.usage()
    }
}

struct PrivacySettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AppLockService.self) private var appLock
    @Environment(EntitlementService.self) private var entitlements

    var body: some View {
        @Bindable var settings = settings
        Form {
            Section {
                Toggle("Hide previews in the app switcher", isOn: $settings.hidePreviews)
                Toggle("App Lock with \(appLock.biometryName)", isOn: $settings.appLockEnabled)
                    .disabled(!appLock.isAvailable)
            } footer: {
                Text("App Lock asks for \(appLock.biometryName) when you open CallCapture. Your recordings are protected by iOS file protection whether or not App Lock is on. Stop stays available while locked.")
            }
            Section {
                PrivacyLine(symbol: "iphone", text: String(localized: "Recordings are stored on this iPhone. CallCapture doesn't upload them."))
                PrivacyLine(symbol: "person.crop.circle.badge.xmark", text: String(localized: "No account, analytics or advertising."))
                PrivacyLine(symbol: "doc.text.magnifyingglass", text: String(localized: "Diagnostics reports contain technical events only and are shared only if you choose to."))
                PrivacyLine(symbol: "rectangle.on.rectangle", text: String(localized: "Full-screen recording can include notifications and other apps. Stop when you've finished."))
                PrivacyLine(symbol: "icloud", text: String(localized: "Device and iCloud backups may include recordings. Shared copies are outside CallCapture's control."))
            } header: {
                Text("How your data is handled")
            }
        }
        .navigationTitle(String(localized: "Privacy"))
    }
}

private struct PrivacyLine: View {
    let symbol: String
    let text: String
    var body: some View {
        Label { Text(text).fixedSize(horizontal: false, vertical: true) } icon: { Image(systemName: symbol).foregroundStyle(DS.Palette.accent) }
            .font(.callout)
    }
}

struct HelpView: View {
    var body: some View {
        List {
            Section(String(localized: "Recording laws")) {
                Text("Laws about recording conversations differ between countries and regions. Some require everyone's permission. CallCapture can't tell you whether a recording is lawful and doesn't give legal advice.")
                Text("Tell the people you record, and check the rules where you and they are.")
            }
            Section(String(localized: "What CallCapture can and can't confirm")) {
                Text("It shows which sources actually delivered media, and where something was missing.")
                Text("It can't confirm that everyone in a call was recorded. Sound levels don't identify speakers.")
                Text("Whether another app's call audio is available depends on iOS and that app. CallCapture shows it as unconfirmed until audio arrives.")
            }
            Section(String(localized: "Common questions")) {
                DisclosureGroup("Why does recording continue after my call ends?") {
                    Text("Full-screen recording captures the screen until you tap Stop. CallCapture doesn't detect when calls start or end.")
                }
                DisclosureGroup("What happens if CallCapture closes during a recording?") {
                    Text("Media saved up to that point is recovered next time you open the app. Recording doesn't continue after the app closes, so the end may be missing.")
                }
                DisclosureGroup("What does “Saved with missing sections” mean?") {
                    Text("Part of a source you selected wasn't received. The recording shows exactly which source and time range.")
                }
            }
        }
        .navigationTitle(String(localized: "Help"))
    }
}

struct DiagnosticsView: View {
    @Environment(AppModel.self) private var model
    @State private var reportURL: URL?

    var body: some View {
        List {
            Section {
                Text("A diagnostics report lists technical events such as start, stop, missing-audio and saving steps. It never includes recordings, titles, audio, transcripts, contacts or screen content.")
                    .font(.callout)
            }
            Section {
                if let reportURL {
                    ShareLink(item: reportURL) { Label("Share report", systemImage: "square.and.arrow.up") }
                        .frame(minHeight: DS.Size.minimumTarget)
                } else {
                    Button("Prepare report") { prepare() }
                        .frame(minHeight: DS.Size.minimumTarget)
                }
            } footer: {
                Text("\(model.diagnostics.events.count) events recorded since launch.")
            }
        }
        .navigationTitle(String(localized: "Diagnostics"))
    }

    private func prepare() {
        let device = UIDevice.current
        guard let data = try? model.diagnostics.exportReport(appVersion: AppInfo.versionString, osVersion: device.systemVersion,
                                                              deviceModel: device.model, resourceState: model.session.resourceState.rawValue,
                                                              now: Date()) else { return }
        let url = model.layout.diagnostics.appendingPathComponent("CallCapture-diagnostics.json")
        try? data.write(to: url, options: .atomic)
        reportURL = url
    }
}
