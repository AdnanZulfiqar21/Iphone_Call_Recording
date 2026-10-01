import Foundation
import StoreKit
import CallCaptureCore

/// One-time Pro purchase (P11). Isolated from capture and owned-file access (section 5):
/// nothing here is consulted by SessionController, playback, export or recovery.
@MainActor @Observable
final class EntitlementService {
    static let proProductID = "com.adnanzulfiqar.callcapture.pro"

    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
        case purchased
        case pending
        case cancelled
        case failed(String)
    }

    private let defaults: UserDefaults
    private(set) var cache: EntitlementCache
    private(set) var product: Product?
    private(set) var productLoadFailed = false
    private(set) var purchaseState: PurchaseState = .idle
    private var updatesTask: Task<Void, Never>?

    init(defaults: UserDefaults) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "entitlementCache"),
           let cached = try? JSONDecoder().decode(EntitlementCache.self, from: data) {
            // Until re-verified this launch, the last known state is treated as unknown-with-history.
            cache = EntitlementCache(state: cached.state == .pro ? .unknown : cached.state, verifiedAt: cached.verifiedAt,
                                     productID: cached.state == .pro ? cached.productID : nil)
        } else {
            cache = EntitlementCache()
        }
    }

    var isPro: Bool { EntitlementPolicy.isAvailable(.exportPresets, cache: cache) }

    func isAvailable(_ feature: Feature) -> Bool { EntitlementPolicy.isAvailable(feature, cache: cache) }

    func start() async {
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(update)
            }
        }
        await refreshEntitlement()
        await loadProduct()
    }

    func loadProduct() async {
        productLoadFailed = false
        do {
            product = try await Product.products(for: [Self.proProductID]).first
            if product == nil { productLoadFailed = true }
        } catch {
            productLoadFailed = true
        }
    }

    /// Offline or failed checks keep the cached state; they never revoke owned recordings (T33).
    func refreshEntitlement() async {
        var found = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let t) = result, t.productID == Self.proProductID, t.revocationDate == nil {
                found = true
            }
        }
        if found {
            save(EntitlementCache(state: .pro, verifiedAt: Date(), productID: Self.proProductID))
        } else if cache.state != .pro {
            save(EntitlementCache(state: cache.productID == nil ? .free : .unknown, verifiedAt: cache.verifiedAt, productID: cache.productID))
        }
    }

    func purchase() async {
        guard let product else { return }
        purchaseState = .purchasing
        do {
            switch try await product.purchase() {
            case .success(let verification):
                if case .verified(let t) = verification {
                    await t.finish()
                    save(EntitlementCache(state: .pro, verifiedAt: Date(), productID: t.productID))
                    purchaseState = .purchased
                } else {
                    purchaseState = .failed(String(localized: "The purchase couldn't be verified."))
                }
            case .pending:
                purchaseState = .pending
            case .userCancelled:
                purchaseState = .cancelled
            @unknown default:
                purchaseState = .idle
            }
        } catch {
            purchaseState = .failed(String(localized: "The purchase didn't complete. You haven't been charged by CallCapture."))
        }
    }

    func restore() async {
        purchaseState = .loading
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            purchaseState = isPro ? .purchased : .idle
        } catch {
            purchaseState = .failed(String(localized: "Couldn't reach the App Store. Try again when you're online."))
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result, t.productID == Self.proProductID else { return }
        if t.revocationDate != nil {
            // Refund/revocation removes Pro conveniences only; recordings and core features stay (UX15).
            save(EntitlementCache(state: .revoked, verifiedAt: Date(), productID: nil))
        } else {
            save(EntitlementCache(state: .pro, verifiedAt: Date(), productID: t.productID))
        }
        await t.finish()
    }

    private func save(_ c: EntitlementCache) {
        cache = c
        if let data = try? JSONEncoder().encode(c) { defaults.set(data, forKey: "entitlementCache") }
    }
}
