import SwiftUI
import CallCaptureCore

enum AppearancePreference: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
    var title: String {
        switch self {
        case .system: return String(localized: "System")
        case .light: return String(localized: "Light")
        case .dark: return String(localized: "Dark")
        }
    }
}

/// User preferences. Changing appearance never touches a session (section 14.2).
@MainActor @Observable
final class AppSettings {
    private let defaults: UserDefaults

    var appearance: AppearancePreference { didSet { defaults.set(appearance.rawValue, forKey: "appearance") } }
    var captureMode: CaptureMode { didSet { defaults.set(captureMode.rawValue, forKey: "captureMode") } }
    var includeMicrophone: Bool { didSet { defaults.set(includeMicrophone, forKey: "includeMicrophone") } }
    var importantMode: Bool { didSet { defaults.set(importantMode, forKey: "importantMode") } }
    var consentReminder: Bool { didSet { defaults.set(consentReminder, forKey: "consentReminder") } }
    var hidePreviews: Bool { didSet { defaults.set(hidePreviews, forKey: "hidePreviews") } }
    var appLockEnabled: Bool { didSet { defaults.set(appLockEnabled, forKey: "appLockEnabled") } }
    var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") } }
    var showInputMeter: Bool { didSet { defaults.set(showInputMeter, forKey: "showInputMeter") } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        appearance = AppearancePreference(rawValue: defaults.string(forKey: "appearance") ?? "") ?? .system
        captureMode = CaptureMode(rawValue: defaults.string(forKey: "captureMode") ?? "") ?? .screenAndAudio
        includeMicrophone = defaults.object(forKey: "includeMicrophone") as? Bool ?? true
        importantMode = defaults.bool(forKey: "importantMode")
        consentReminder = defaults.object(forKey: "consentReminder") as? Bool ?? true
        hidePreviews = defaults.object(forKey: "hidePreviews") as? Bool ?? true
        appLockEnabled = defaults.bool(forKey: "appLockEnabled")
        hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        showInputMeter = defaults.object(forKey: "showInputMeter") as? Bool ?? true
    }

    var contract: CaptureContract {
        CaptureContract.standard(mode: captureMode, includeMicrophone: includeMicrophone, importantMode: importantMode)
    }

    var scopeDescription: String {
        switch (captureMode, includeMicrophone) {
        case (.screenOnly, _): return String(localized: "Full screen, no audio")
        case (.screenAndAudio, true): return String(localized: "Full screen + microphone + app audio")
        case (.screenAndAudio, false): return String(localized: "Full screen + app audio")
        case (.audioOnly, true): return String(localized: "Microphone + app audio")
        case (.audioOnly, false): return String(localized: "App audio only")
        }
    }
}
