import SwiftUI
import CallCaptureCore

// Component layer (section 14.2). Components render authoritative view state only;
// they never create capture logic or infer health from animation.

/// Large primary action with label, used for Start, Play and confirmations.
struct PrimaryActionButton: View {
    enum Style { case record, stop, accent, tinted }
    let title: String
    let systemImage: String
    var style: Style = .accent
    var isEnabled = true
    var disabledReason: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: DS.Space.xs) {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: style == .tinted ? DS.Size.minimumTarget : DS.Size.primaryControlHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionButtonStyle(style: style))
            .disabled(!isEnabled)
            if !isEnabled, let disabledReason {
                Text(disabledReason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct ActionButtonStyle: ButtonStyle {
    let style: PrimaryActionButton.Style
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let (bg, fg): (Color, Color) = {
            switch style {
            case .record, .stop: return (DS.Palette.recordButton, .white)
            case .accent: return (DS.Palette.accentButton, .white)
            case .tinted: return (DS.Palette.accentFill, DS.Palette.accent)
            }
        }()
        configuration.label
            .foregroundStyle(isEnabled ? fg : Color.secondary)
            .background(isEnabled ? bg : Color(uiColor: .tertiarySystemFill), in: RoundedRectangle(cornerRadius: DS.Radius.control, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

/// The recording control: Start when idle, Stop while active. Stop is a direct action with
/// immediate acknowledgement — no hold, swipe or confirmation (section 14.5). Repeats are idempotent.
struct RecordingControl: View {
    let isActive: Bool
    let stopAcknowledged: Bool
    let canStart: Bool
    let disabledReason: String?
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        if isActive {
            Button(action: onStop) {
                Label(stopAcknowledged ? String(localized: "Stopping…") : String(localized: "Stop recording"), systemImage: "stop.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: DS.Size.primaryControlHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ActionButtonStyle(style: .stop))
            .accessibilityIdentifier("stopButton")
            .accessibilityHint(Text("Ends capture immediately. Saving continues after."))
        } else {
            PrimaryActionButton(title: String(localized: "Start recording"), systemImage: "record.circle", style: .record,
                                isEnabled: canStart, disabledReason: disabledReason, action: onStart)
                .accessibilityIdentifier("startButton")
        }
    }
}

/// Status chip: colour + icon + text, never colour alone (UX04).
struct StatusPill: View {
    let text: String
    let tone: StatusTone

    var body: some View {
        Label(text, systemImage: tone.symbol)
            .labelStyle(.titleAndIcon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone == .warning ? DS.Palette.warning : tone.color)
            .padding(.horizontal, DS.Space.s)
            .padding(.vertical, DS.Space.xs)
            .background(background, in: Capsule())
            .accessibilityElement(children: .combine)
    }

    private var background: Color {
        tone == .warning ? DS.Palette.warningFill : tone.color.opacity(0.14)
    }
}

/// One requested source: name, current observation and freshness (section 14.5 secondary tier).
struct SourceStatusRow: View {
    let status: SourceStatus
    let lifecycle: Lifecycle
    var showMeter: Bool
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let line = StatusPresenter.source(status, lifecycle: lifecycle)
        // At accessibility sizes the row stacks vertically so words never break mid-word (UX03).
        AdaptiveRow(spacing: DS.Space.m) {
            Image(systemName: status.source.symbol)
                .font(.body)
                .foregroundStyle(DS.Palette.accent)
                .frame(width: 30, height: 30)
                .background(DS.Palette.accentFill, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(status.source.displayName).font(.body.weight(.medium))
                HStack(spacing: DS.Space.s) {
                    Text(StatusCopy.sourceDetail(status, lifecycle: lifecycle))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if showMeter, status.source.isAudio, let level = status.inputLevel, line.tone == .pass {
                        InputLevelMeter(level: level)
                    }
                }
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: DS.Space.s) }
            StatusPill(text: StatusCopy.text(line.message), tone: line.tone)
        }
        .padding(.vertical, DS.Space.xs)
        .frame(minHeight: DS.Size.minimumTarget)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("\(status.source.displayName): \(StatusCopy.text(line.message))"))
        .accessibilityValue(Text(StatusCopy.sourceDetail(status, lifecycle: lifecycle)))
    }
}

/// Input level from real, downsampled samples. Labelled as input level only (section 14.7).
struct InputLevelMeter: View {
    let level: Float

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<6, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Float(i) / 6 < level * 1.6 ? DS.Palette.accent : DS.Palette.neutral.opacity(0.35))
                    .frame(width: 3, height: CGFloat(5 + i * 2))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Persistent notice; stays until resolved or dismissed (never only a toast).
struct InlineNotice: View {
    let text: String
    var tone: StatusTone = .warning
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.s) {
            Image(systemName: tone.symbol)
                .foregroundStyle(tone == .warning ? DS.Palette.warning : tone.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DS.Space.xs) {
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.callout.weight(.semibold))
                        .frame(minHeight: DS.Size.minimumTarget, alignment: .leading)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DS.Space.m)
        .background(tone == .warning ? DS.Palette.warningFill : DS.Palette.accentFill,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Text-first library row (section 14.6).
struct RecordingRow: View {
    let row: LibraryRow

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        AdaptiveRow(spacing: DS.Space.m) {
            VStack(alignment: .leading, spacing: 3) {
                // Long titles wrap fully rather than truncating (section 14.6, UX14).
                Text(row.title)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(row.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(StatusCopy.duration(row.duration))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            if !typeSize.isAccessibilitySize { Spacer(minLength: DS.Space.s) }
            StatusPill(text: rowStatus.0, tone: rowStatus.1)
        }
        .frame(minHeight: DS.Size.minimumTarget)
        .accessibilityElement(children: .combine)
    }

    private var rowStatus: (String, StatusTone) {
        switch row.libraryState {
        case .quarantined: return (String(localized: "Needs attention"), .warning)
        case .recovering: return (String(localized: "Recovering"), .neutral)
        case .validating: return (String(localized: "Checking"), .neutral)
        default: return (StatusCopy.outcome(row.outcome), StatusCopy.outcomeTone(row.outcome))
        }
    }
}

/// Outcome summary at the top of a saved result (section 14.3).
struct RecordingSummary: View {
    let metadata: RecordingMetadata

    var body: some View {
        VStack(spacing: DS.Space.s) {
            let tone = StatusCopy.outcomeTone(metadata.outcome)
            Image(systemName: tone.symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(tone == .warning ? DS.Palette.warning : tone.color)
                .frame(width: 60, height: 60)
                .background((tone == .warning ? DS.Palette.warningFill : tone.color.opacity(0.14)),
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .accessibilityHidden(true)
            Text(headline)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text("\(metadata.title) · \(StatusCopy.duration(metadata.duration)) · \(StatusCopy.bytes(Int64(metadata.byteCount)))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var headline: String {
        let message: StatusMessage = switch metadata.outcome {
        case .saved: .savedNoKnownGaps
        case .savedPartial: .savedWithMissingSections
        case .recovered: .recoveredNoKnownGaps
        case .recoveredPartial: .recoveredWithMissingSections
        case .failed: .saveFailedRecoveryKept
        }
        return StatusCopy.text(message)
    }
}

/// Labelled gap or bookmark marker for timelines (section 14.6).
struct TimelineMarker: View {
    enum Kind { case gap, bookmark }
    let kind: Kind
    let title: String
    let time: String

    var body: some View {
        HStack(spacing: DS.Space.m) {
            Image(systemName: kind == .gap ? "exclamationmark.triangle.fill" : "bookmark.fill")
                .foregroundStyle(kind == .gap ? DS.Palette.warning : DS.Palette.accent)
                .frame(width: 30, height: 30)
                .background(kind == .gap ? DS.Palette.warningFill : DS.Palette.accentFill, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(time).font(.footnote).foregroundStyle(.secondary).monospacedDigit()
            }
            Spacer()
        }
        .frame(minHeight: DS.Size.minimumTarget)
        .accessibilityElement(children: .combine)
        .accessibilityHint(Text("Plays from this point"))
    }
}

/// Empty states with one valid next action.
struct EmptyState: View {
    let systemImage: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: systemImage)
        } description: {
            Text(message)
        } actions: {
            if let actionTitle, let action {
                Button(actionTitle, action: action).buttonStyle(.borderedProminent)
            }
        }
    }
}

/// Settings row with an icon tile, matching native grouped settings.
struct SettingsRow: View {
    let title: String
    let systemImage: String
    var detail: String?

    var body: some View {
        HStack(spacing: DS.Space.m) {
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(DS.Palette.accentButton, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let detail { Text(detail).font(.footnote).foregroundStyle(.secondary) }
            }
        }
        .frame(minHeight: DS.Size.minimumTarget)
    }
}

/// Grouped content card on a stable surface.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.s) { content }
            .padding(DS.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DS.Palette.card, in: RoundedRectangle(cornerRadius: DS.Radius.card, style: .continuous))
    }
}

/// Horizontal row that becomes a leading-aligned vertical stack at accessibility text sizes.
struct AdaptiveRow<Content: View>: View {
    var spacing: CGFloat = DS.Space.m
    @ViewBuilder var content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        layout { content }
    }
}
