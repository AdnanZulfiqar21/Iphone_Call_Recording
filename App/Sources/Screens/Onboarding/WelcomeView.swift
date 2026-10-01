import SwiftUI

/// First launch (section 14.3): short value statement, honest capability summary,
/// non-blocking consent notice, no account, no permission barrage, no purchase.
struct WelcomeView: View {
    @Environment(AppSettings.self) private var settings
    @State private var showSetup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Space.xl) {
                    Image(systemName: "record.circle")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(DS.Palette.accent)
                        .frame(width: 72, height: 72)
                        .background(DS.Palette.accentFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityHidden(true)
                        .padding(.top, DS.Space.xl)
                    VStack(spacing: DS.Space.s) {
                        Text("Record what matters, know what you got")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text("CallCapture records your screen and available audio, then tells you plainly which sources were captured and where anything is missing.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    Card {
                        CapabilityLine(symbol: "checkmark.circle.fill", tone: .pass, text: String(localized: "Recordings stay on this iPhone unless you share them"))
                        CapabilityLine(symbol: "checkmark.circle.fill", tone: .pass, text: String(localized: "No account needed"))
                        CapabilityLine(symbol: "questionmark.circle", tone: .neutral,
                                       text: String(localized: "Call audio depends on the app and audio route. CallCapture checks every time and never guesses."))
                    }
                    InlineNotice(text: String(localized: "Recording laws differ by place. Tell the people you record and follow local law."))
                }
                .padding(.horizontal, DS.Space.margin)
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: DS.Space.s) {
                    PrimaryActionButton(title: String(localized: "Test my setup"), systemImage: "checklist", style: .accent) {
                        showSetup = true
                    }
                    .accessibilityIdentifier("testSetupButton")
                    Button("Skip for now") { settings.hasCompletedOnboarding = true }
                        .frame(minHeight: DS.Size.minimumTarget)
                        .accessibilityIdentifier("skipOnboardingButton")
                }
                .padding(DS.Space.margin)
                .background(.bar)
            }
            .navigationDestination(isPresented: $showSetup) {
                SetupGuideView(onFinish: { settings.hasCompletedOnboarding = true })
            }
        }
    }
}

private struct CapabilityLine: View {
    let symbol: String
    let tone: StatusTone
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: DS.Space.s) {
            Image(systemName: symbol).foregroundStyle(tone.color).accessibilityHidden(true)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
        .font(.callout)
    }
}
