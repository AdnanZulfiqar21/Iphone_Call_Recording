import SwiftUI
import StoreKit
import CallCaptureCore

/// Optional one-time Pro (P11). Localized StoreKit price, Restore and a clear dismissal.
/// No forced or misleading flows; safety, accessibility and owned recordings are never paywalled.
struct ProView: View {
    @Environment(EntitlementService.self) private var entitlements
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: DS.Space.s) {
                    Image(systemName: "star.circle.fill").font(.system(size: 40)).foregroundStyle(DS.Palette.accent)
                        .accessibilityHidden(true)
                    Text("CallCapture Pro").font(.title2.weight(.bold))
                    Text("Extras for people who record often. One purchase, no subscription.")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, DS.Space.s)
            }
            Section(String(localized: "Included with Pro")) {
                Label("Advanced organisation and bookmark tools", systemImage: "folder.badge.gearshape")
                Label("Export presets", systemImage: "square.and.arrow.up.on.square")
                Label("Detailed recording history", systemImage: "clock")
                Label("App Lock convenience options", systemImage: "lock")
            }
            Section(String(localized: "Always free")) {
                Label("Recording and missing-audio warnings", systemImage: "record.circle")
                Label("Playback, rename, delete and export", systemImage: "play.rectangle")
                Label("Recovery and file protection", systemImage: "lock.shield")
            }
            Section { purchaseArea }
        }
        .navigationTitle(String(localized: "Pro"))
        .task { if entitlements.product == nil { await entitlements.loadProduct() } }
    }

    @ViewBuilder private var purchaseArea: some View {
        if entitlements.isPro {
            Label("Pro is unlocked on this Apple Account", systemImage: "checkmark.seal.fill").foregroundStyle(DS.Palette.pass)
        } else if let product = entitlements.product {
            PrimaryActionButton(title: String(localized: "Unlock for \(product.displayPrice)"), systemImage: "star", style: .accent,
                                isEnabled: entitlements.purchaseState != .purchasing) {
                Task { await entitlements.purchase() }
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .accessibilityIdentifier("purchaseButton")
        } else if entitlements.productLoadFailed {
            Text("The price couldn't be loaded. Check your connection and try again.").foregroundStyle(.secondary)
            Button("Try again") { Task { await entitlements.loadProduct() } }
        } else {
            HStack { ProgressView(); Text("Loading price…") }
        }
        Button("Restore purchases") { Task { await entitlements.restore() } }
            .frame(minHeight: DS.Size.minimumTarget)
            .accessibilityIdentifier("restoreButton")
        switch entitlements.purchaseState {
        case .pending: Text("Purchase pending approval. You can keep using CallCapture.").font(.footnote)
        case .cancelled: Text("Purchase cancelled. Nothing changed.").font(.footnote).foregroundStyle(.secondary)
        case .failed(let message): Text(message).font(.footnote).foregroundStyle(DS.Palette.warning)
        default: EmptyView()
        }
        Button("Not now") { dismiss() }
            .frame(minHeight: DS.Size.minimumTarget)
    }
}
