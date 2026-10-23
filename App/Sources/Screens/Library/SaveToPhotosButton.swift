import SwiftUI

/// One-tap "Save to Photos" for a saved recording (device test 1 asked for it outside Export).
/// The label reports progress and the outcome in place; the master stays in CallCapture.
struct SaveToPhotosButton: View {
    let url: URL
    /// Full-width tinted action (result screen) or a list row (player).
    var prominent = false

    @State private var saving = false
    @State private var outcome: PhotoLibrarySaver.Outcome?

    var body: some View {
        Button {
            saving = true
            outcome = nil
            Task {
                outcome = await PhotoLibrarySaver.saveVideo(at: url)
                saving = false
            }
        } label: {
            if prominent {
                label.font(.headline).frame(maxWidth: .infinity, minHeight: DS.Size.primaryControlHeight)
            } else {
                label.frame(minHeight: DS.Size.minimumTarget)
            }
        }
        .modifier(ProminentStyle(prominent: prominent))
        .disabled(saving || outcome == .saved)
        .accessibilityIdentifier("saveToPhotosButton")
    }

    @ViewBuilder private var label: some View {
        if saving {
            Label(String(localized: "Saving to Photos…"), systemImage: "hourglass")
        } else if let outcome {
            Label(PhotoLibrarySaver.message(for: outcome),
                  systemImage: outcome == .saved ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
        } else {
            Label(String(localized: "Save to Photos"), systemImage: "photo.on.rectangle")
        }
    }
}

private struct ProminentStyle: ViewModifier {
    let prominent: Bool
    func body(content: Content) -> some View {
        if prominent { content.buttonStyle(ActionButtonStyle(style: .tinted)) } else { content }
    }
}
