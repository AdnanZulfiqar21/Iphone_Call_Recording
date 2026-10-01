import Foundation

public enum AnomalyKind: String, Codable, Sendable {
    /// Media for this interval is known to be missing.
    case missing
    /// Evidence for this interval could not establish presence or absence.
    case inconclusive
    /// Media exists but is damaged or failed validation.
    case damaged
}

public struct Anomaly: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var source: SourceKind
    public var range: MediaRange
    public var kind: AnomalyKind
    public var reason: ReasonCode
    /// Set only when new evidence actually resolves the interval (section 6.3).
    public var resolution: Resolution?

    public struct Resolution: Codable, Sendable, Hashable {
        public var reason: String
        public var evidenceStage: PipelineStage
    }

    public init(id: UUID = UUID(), source: SourceKind, range: MediaRange, kind: AnomalyKind, reason: ReasonCode) {
        self.id = id
        self.source = source
        self.range = range
        self.kind = kind
        self.reason = reason
    }

    public var isOpen: Bool { resolution == nil }
}

/// Section 6.3. Retains every known missing, inconclusive or damaged interval.
/// Returning to healthy capture never removes an earlier interval (rule 15).
public struct AnomalyLedger: Codable, Sendable, Hashable {
    public private(set) var anomalies: [Anomaly] = []

    public init(anomalies: [Anomaly] = []) {
        self.anomalies = anomalies
    }

    /// Records an interval. Overlapping or touching intervals merge only when the source,
    /// kind and reason all match, so coalescing never changes meaning.
    @discardableResult
    public mutating func record(_ new: Anomaly, mergeTolerance: Double = 0.001) -> Anomaly {
        guard !new.range.isEmpty else { return new }
        if let index = anomalies.firstIndex(where: {
            $0.isOpen && $0.source == new.source && $0.kind == new.kind && $0.reason == new.reason &&
                $0.range.overlapsOrTouches(new.range, tolerance: mergeTolerance)
        }) {
            let id = anomalies[index].id
            anomalies[index].range = anomalies[index].range.union(new.range)
            // A merge can make the result touch further neighbours; fold them in.
            coalesce(around: index, tolerance: mergeTolerance)
            return anomalies.first { $0.id == id } ?? new
        }
        anomalies.append(new)
        anomalies.sort { ($0.source, $0.range.start) < ($1.source, $1.range.start) }
        return new
    }

    private mutating func coalesce(around index: Int, tolerance: Double) {
        var target = anomalies[index]
        var changed = true
        while changed {
            changed = false
            for (i, other) in anomalies.enumerated() where other.id != target.id && other.isOpen &&
                other.source == target.source && other.kind == target.kind && other.reason == target.reason &&
                other.range.overlapsOrTouches(target.range, tolerance: tolerance) {
                target.range = target.range.union(other.range)
                anomalies.remove(at: i)
                changed = true
                break
            }
        }
        if let i = anomalies.firstIndex(where: { $0.id == target.id }) { anomalies[i] = target }
        anomalies.sort { ($0.source, $0.range.start) < ($1.source, $1.range.start) }
    }

    /// Resolves an interval only with evidence that actually establishes the media
    /// (e.g. a validated recovery segment). A timer or later healthy capture is not such evidence.
    public mutating func resolve(id: UUID, because reason: String, evidence stage: PipelineStage) -> Bool {
        guard stage >= .checkpointed, let i = anomalies.firstIndex(where: { $0.id == id }) else { return false }
        anomalies[i].resolution = .init(reason: reason, evidenceStage: stage)
        return true
    }

    public func open(for source: SourceKind? = nil) -> [Anomaly] {
        anomalies.filter { $0.isOpen && (source == nil || $0.source == source) }
    }

    public var hasOpenAnomalies: Bool { anomalies.contains { $0.isOpen } }

    /// Total seconds of open anomalies for a source, counting overlaps once.
    public func affectedSeconds(for source: SourceKind) -> Double {
        let ranges = open(for: source).map(\.range).sorted { $0.start < $1.start }
        var total = 0.0
        var current: MediaRange?
        for r in ranges {
            if let c = current, c.overlapsOrTouches(r) {
                current = c.union(r)
            } else {
                if let c = current { total += c.duration }
                current = r
            }
        }
        if let c = current { total += c.duration }
        return total
    }
}

/// Contiguous coverage tracking for one source. A maximum timestamp is not proof of
/// all earlier media (section 10.3), so coverage is a set of ranges.
public struct CoverageSet: Codable, Sendable, Hashable {
    public private(set) var ranges: [MediaRange] = []

    public init() {}

    public mutating func insert(_ range: MediaRange, tolerance: Double = 0.001) {
        guard !range.isEmpty else { return }
        var merged = range
        ranges.removeAll { existing in
            if existing.overlapsOrTouches(merged, tolerance: tolerance) {
                merged = merged.union(existing)
                return true
            }
            return false
        }
        ranges.append(merged)
        ranges.sort { $0.start < $1.start }
    }

    public var coveredSeconds: Double { ranges.reduce(0) { $0 + $1.duration } }
    public var first: MediaTime? { ranges.first?.start }
    public var last: MediaTime? { ranges.last?.end }

    /// Holes inside `bounds` not covered by any range.
    public func gaps(within bounds: MediaRange, minimum: Double = 0) -> [MediaRange] {
        var result: [MediaRange] = []
        var cursor = bounds.start
        for r in ranges where r.end > bounds.start && r.start < bounds.end {
            if cursor < r.start {
                let gap = MediaRange(start: cursor, end: min(r.start, bounds.end))
                if gap.duration > minimum { result.append(gap) }
            }
            cursor = max(cursor, r.end)
        }
        if cursor < bounds.end {
            let gap = MediaRange(start: cursor, end: bounds.end)
            if gap.duration > minimum { result.append(gap) }
        }
        return result
    }
}
