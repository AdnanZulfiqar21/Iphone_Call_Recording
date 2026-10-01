import UIKit
import SwiftUI
import AVFAudio
import CallCaptureCore

/// Guided setup (section 14.4). Each check shows a reason, its current result and a valid next
/// action. Passing checks never promise future call audio; simulated checks say so.
struct SetupGuideView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.openURL) private var openURL
    var onFinish: (() -> Void)?

    @State private var micPermission: AVAudioApplication.recordPermission = AVAudioApplication.shared.recordPermission
    @State private var requesting = false

    var body: some View {
        List {
            Section {
                Text("These checks look at this iPhone right now. They can't confirm that a future call's audio will be available — that's checked during each recording.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            Section {
                check(symbol: "internaldrive", title: String(localized: "Storage"),
                      detail: "\(StatusCopy.bytes(model.freeBytes)) free · \(model.storageEstimate)",
                      tone: StorageReserve.forMode(settings.captureMode).canStart(freeBytes: model.freeBytes) ? .pass : .warning)
                microphoneCheck
                check(symbol: "rectangle.on.rectangle", title: String(localized: "Screen recording"),
                      detail: model.captureAvailable
                        ? String(localized: "Available. iOS asks you to choose what to share when you start.")
                        : String(localized: "Not available on this device or iOS version (needs iOS 27)."),
                      tone: model.captureAvailable ? .pass : .warning)
                check(symbol: "speaker.wave.2", title: String(localized: "Call audio"),
                      detail: String(localized: "Can only be confirmed during a real call. CallCapture shows it as unconfirmed until audio actually arrives."),
                      tone: .neutral, pill: String(localized: "Unconfirmed"))
            } footer: {
                Text(evidenceFooter)
            }
            Section {
                Toggle(isOn: Binding(get: { settings.consentReminder }, set: { settings.consentReminder = $0 })) {
                    Text("Remind me to tell participants")
                }
                .frame(minHeight: DS.Size.minimumTarget)
            } footer: {
                Text("A short reminder before each recording. You can turn it off any time in Settings.")
            }
        }
        .navigationTitle(String(localized: "Test my setup"))
        .safeAreaInset(edge: .bottom) {
            if let onFinish {
                PrimaryActionButton(title: String(localized: "Done"), systemImage: "checkmark", style: .accent, action: onFinish)
                    .padding(DS.Space.margin)
                    .background(.bar)
                    .accessibilityIdentifier("setupDoneButton")
            }
        }
        .onAppear { model.refreshStorage() }
    }

    private var evidenceFooter: String {
        #if DEBUG
        if model.launchConfiguration.scenario != nil { return String(localized: "Development build: capture checks are simulated.") }
        #endif
        return String(localized: "Checked on this iPhone \(Date().formatted(date: .omitted, time: .shortened)).")
    }

    @ViewBuilder private var microphoneCheck: some View {
        switch micPermission {
        case .granted:
            check(symbol: "mic", title: String(localized: "Microphone"), detail: String(localized: "Allowed"), tone: .pass)
        case .denied:
            VStack(alignment: .leading, spacing: DS.Space.s) {
                check(symbol: "mic.slash", title: String(localized: "Microphone"),
                      detail: String(localized: "Not allowed. Recordings can still capture the screen and app audio."), tone: .warning)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .frame(minHeight: DS.Size.minimumTarget)
            }
        default:
            VStack(alignment: .leading, spacing: DS.Space.s) {
                check(symbol: "mic", title: String(localized: "Microphone"),
                      detail: String(localized: "Used only while you record, to include your voice."), tone: .neutral, pill: String(localized: "Not asked yet"))
                Button("Allow microphone") {
                    requesting = true
                    Task {
                        _ = await AVAudioApplication.requestRecordPermission()
                        micPermission = AVAudioApplication.shared.recordPermission
                        requesting = false
                    }
                }
                .disabled(requesting)
                .frame(minHeight: DS.Size.minimumTarget)
                .accessibilityIdentifier("allowMicrophoneButton")
            }
        }
    }

    private func check(symbol: String, title: String, detail: String, tone: StatusTone, pill: String? = nil) -> some View {
        HStack(alignment: .top, spacing: DS.Space.m) {
            Image(systemName: symbol)
                .foregroundStyle(tone == .warning ? DS.Palette.warning : tone.color)
                .frame(width: 30, height: 30)
                .background(tone == .warning ? DS.Palette.warningFill : tone.color.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: DS.Space.s)
            StatusPill(text: pill ?? (tone == .pass ? String(localized: "OK") : String(localized: "Check")), tone: tone)
        }
        .padding(.vertical, DS.Space.xs)
        .accessibilityElement(children: .combine)
    }
}
