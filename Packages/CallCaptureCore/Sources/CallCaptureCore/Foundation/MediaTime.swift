import Foundation

/// Media presentation time independent of CoreMedia, so domain logic stays portable.
/// The media layer converts CMTime to and from this type.
public struct MediaTime: Comparable, Hashable, Sendable, Codable {
    public var value: Int64
    public var timescale: Int32

    public init(value: Int64, timescale: Int32) {
        precondition(timescale > 0, "timescale must be positive")
        self.value = value
        self.timescale = timescale
    }

    /// Non-finite or out-of-range input produces `.invalid` instead of trapping.
    public init(seconds: Double, timescale: Int32 = 1_000_000) {
        let scaled = (seconds * Double(timescale)).rounded()
        guard scaled.isFinite, abs(scaled) < 9.0e18 else {
            self.init(value: Int64.min, timescale: 1)
            return
        }
        self.init(value: Int64(scaled), timescale: timescale)
    }

    public static let zero = MediaTime(value: 0, timescale: 1_000_000)
    public static let invalid = MediaTime(value: Int64.min, timescale: 1)

    public var isValid: Bool { !(value == Int64.min && timescale == 1) }

    public var seconds: Double { isValid ? Double(value) / Double(timescale) : .nan }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        // Cross-multiply to compare without floating-point rounding.
        Int128Compare.less(lhs.value, rhs.timescale, rhs.value, lhs.timescale)
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }

    public func hash(into hasher: inout Hasher) { hasher.combine(seconds) }

    public static func + (lhs: Self, rhs: Self) -> Self {
        MediaTime(seconds: lhs.seconds + rhs.seconds, timescale: max(lhs.timescale, rhs.timescale))
    }

    public static func - (lhs: Self, rhs: Self) -> Self {
        MediaTime(seconds: lhs.seconds - rhs.seconds, timescale: max(lhs.timescale, rhs.timescale))
    }
}

enum Int128Compare {
    /// Returns a*d < c*b using 128-bit intermediate via multipliedFullWidth.
    static func less(_ a: Int64, _ d: Int32, _ c: Int64, _ b: Int32) -> Bool {
        let left = a.multipliedFullWidth(by: Int64(d))
        let right = c.multipliedFullWidth(by: Int64(b))
        if left.high != right.high { return left.high < right.high }
        return left.low < right.low
    }
}

/// A half-open media interval [start, end).
public struct MediaRange: Hashable, Sendable, Codable, CustomStringConvertible {
    public var start: MediaTime
    public var end: MediaTime

    public init(start: MediaTime, end: MediaTime) {
        self.start = start
        self.end = max(start, end)
    }

    public init(startSeconds: Double, endSeconds: Double) {
        self.init(start: MediaTime(seconds: startSeconds), end: MediaTime(seconds: endSeconds))
    }

    public var duration: Double { end.seconds - start.seconds }
    public var isEmpty: Bool { !(start < end) }

    public func overlapsOrTouches(_ other: MediaRange, tolerance: Double = 0) -> Bool {
        start.seconds <= other.end.seconds + tolerance && other.start.seconds <= end.seconds + tolerance
    }

    public func union(_ other: MediaRange) -> MediaRange {
        MediaRange(start: min(start, other.start), end: max(end, other.end))
    }

    public func clamped(to bounds: MediaRange) -> MediaRange {
        MediaRange(start: max(start, bounds.start), end: min(max(end, bounds.start), bounds.end))
    }

    public var description: String {
        "\(TimeFormatting.clock(start.seconds))–\(TimeFormatting.clock(end.seconds))"
    }
}

public enum TimeFormatting {
    /// mm:ss, or h:mm:ss for an hour or more. Used for ranges in reports and copy (section 14.12).
    public static func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
