import UIKit
import SwiftUI
import CallCaptureCore

/// Design tokens (roadmap section 14.2 / 14.12; docs/ux/design-system.md).
/// Colours come from named asset colours with light, dark and increased-contrast variants.
enum DS {
    enum Palette {
        static let accent = Color("AccentColor")
        static let record = Color("RecordRed")
        static let warning = Color("WarningText")
        static let warningFill = Color("WarningFill")
        static let pass = Color("PassGreen")
        static let neutral = Color("NeutralUnknown")
        static let accentFill = Color("AccentFill")
        /// Fills behind white labels; darker than the text tokens in dark mode (contrast report).
        static let recordButton = Color("RecordButtonFill")
        static let accentButton = Color("AccentButtonFill")
        static let surface = Color(uiColor: .systemGroupedBackground)
        static let card = Color(uiColor: .secondarySystemGroupedBackground)
        static let separator = Color(uiColor: .separator)
    }

    /// Shared 4/8/12/16/24/32 pt spacing scale.
    enum Space {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
        static let margin: CGFloat = 20
    }

    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 16
        static let chip: CGFloat = 10
    }

    enum Size {
        /// Product choice: primary Start/Stop at least 56 pt high (section 14.2).
        static let primaryControlHeight: CGFloat = 56
        /// Apple minimum touch target.
        static let minimumTarget: CGFloat = 44
    }

    enum Motion {
        /// 180–250 ms minor state changes; none when Reduce Motion is on (section 14.7).
        static func standard(_ reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : .easeInOut(duration: 0.22)
        }
    }
}

extension StatusTone {
    var color: Color {
        switch self {
        case .recording: return DS.Palette.record
        case .warning: return DS.Palette.warning
        case .pass: return DS.Palette.pass
        case .neutral: return DS.Palette.neutral
        case .accent: return DS.Palette.accent
        }
    }

    /// Every status pairs colour with an icon and text (UX04).
    var symbol: String {
        switch self {
        case .recording: return "record.circle"
        case .warning: return "exclamationmark.triangle.fill"
        case .pass: return "checkmark.circle.fill"
        case .neutral: return "questionmark.circle"
        case .accent: return "info.circle"
        }
    }
}

extension SourceKind {
    var symbol: String {
        switch self {
        case .screen: return "rectangle.on.rectangle"
        case .microphone: return "mic.fill"
        case .appAudio: return "speaker.wave.2.fill"
        }
    }

    var displayName: String {
        switch self {
        case .screen: return String(localized: "Screen")
        case .microphone: return String(localized: "Microphone")
        case .appAudio: return String(localized: "App audio")
        }
    }
}
