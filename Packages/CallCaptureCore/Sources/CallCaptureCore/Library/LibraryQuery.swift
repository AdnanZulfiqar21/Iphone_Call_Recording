import Foundation

public enum LibrarySort: String, Codable, Sendable, CaseIterable {
    case newest, oldest
    /// Pro sorting options (section 21 "advanced organization").
    case longest, shortest, title

    public var requiresPro: Bool { self == .longest || self == .shortest || self == .title }
}

public enum LibraryFilter: String, Codable, Sendable, CaseIterable {
    case all
    case partial
    case recovered
    case bookmarked
    case needsAttention
}

/// Lightweight row model so large libraries never decode media to render (UX12).
public struct LibraryRow: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var title: String
    public var createdAt: Date
    public var duration: Double
    public var outcome: FinalOutcome
    public var libraryState: LibraryState
    public var validation: FileValidation
    public var bookmarkCount: Int
    public var hasKnownGaps: Bool

    public init(_ m: RecordingMetadata) {
        id = m.id
        title = m.title
        createdAt = m.createdAt
        duration = m.duration
        outcome = m.outcome
        libraryState = m.libraryState
        validation = m.validation
        bookmarkCount = m.bookmarks.count
        hasKnownGaps = m.hasKnownGaps
    }
}

public struct LibraryQuery: Sendable, Equatable {
    public var text: String
    public var sort: LibrarySort
    public var filter: LibraryFilter

    public init(text: String = "", sort: LibrarySort = .newest, filter: LibraryFilter = .all) {
        self.text = text
        self.sort = sort
        self.filter = filter
    }

    /// Local title search, case- and diacritic-insensitive, Unicode-safe.
    public func apply(to rows: [LibraryRow]) -> [LibraryRow] {
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = rows.filter { row in
            guard row.libraryState != .deletePending else { return false }
            switch filter {
            case .all: break
            case .partial: guard row.outcome.isPartial || row.hasKnownGaps else { return false }
            case .recovered: guard row.outcome.isRecovered else { return false }
            case .bookmarked: guard row.bookmarkCount > 0 else { return false }
            case .needsAttention:
                guard row.libraryState == .quarantined || row.libraryState == .recovering || row.outcome == .failed
                        || row.validation == .failed else { return false }
            }
            guard !needle.isEmpty else { return true }
            return row.title.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]) != nil
        }
        return filtered.sorted { a, b in
            switch sort {
            case .longest where a.duration != b.duration: return a.duration > b.duration
            case .shortest where a.duration != b.duration: return a.duration < b.duration
            case .title:
                let order = a.title.localizedStandardCompare(b.title)
                if order != .orderedSame { return order == .orderedAscending }
            case .newest where a.createdAt != b.createdAt: return a.createdAt > b.createdAt
            case .oldest where a.createdAt != b.createdAt: return a.createdAt < b.createdAt
            default: break
            }
            return a.id.uuidString < b.id.uuidString   // stable identity
        }
    }
}
