import Foundation

public enum EntitlementState: String, Codable, Sendable {
    case unknown
    case free
    case pro
    case revoked
}

/// Features. Core recording, warnings, playback, rename, delete, standard export, recovery,
/// basic search/filters, storage view and diagnostics export are never paywalled (rule 24, section 21).
public enum Feature: String, Codable, Sendable, CaseIterable {
    case record, healthWarnings, playback, rename, delete, standardExport, recovery
    case basicSearch, outcomeFilters, bookmarks, storageView, diagnosticsExport, appearance
    /// Pro: extra library sorting and the detailed technical report. Basic gap information,
    /// warnings and all owned-file actions stay free (section 21).
    case advancedOrganization, detailedHistory

    public var requiresPro: Bool {
        switch self {
        case .advancedOrganization, .detailedHistory: return true
        default: return false
        }
    }
}

public struct EntitlementCache: Codable, Sendable, Equatable {
    public var state: EntitlementState
    public var verifiedAt: Date?
    public var productID: String?

    public init(state: EntitlementState = .unknown, verifiedAt: Date? = nil, productID: String? = nil) {
        self.state = state
        self.verifiedAt = verifiedAt
        self.productID = productID
    }
}

public enum EntitlementPolicy {
    /// Offline/unknown keeps the last verified Pro state so a purchase is not lost offline,
    /// and never affects free features or owned recordings (T33, UX15).
    public static func isAvailable(_ feature: Feature, cache: EntitlementCache) -> Bool {
        guard feature.requiresPro else { return true }
        switch cache.state {
        case .pro: return true
        case .unknown: return cache.productID != nil && cache.verifiedAt != nil
        case .free, .revoked: return false
        }
    }
}
