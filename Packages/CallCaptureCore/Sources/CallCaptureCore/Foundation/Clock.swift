import Foundation

/// A point on a monotonic clock, in nanoseconds since an arbitrary origin.
/// Watchdogs and deadlines use this; it is never used for media timing or display (rules 6–7).
public struct MonotonicInstant: Comparable, Hashable, Sendable, Codable {
    public var nanoseconds: UInt64

    public init(nanoseconds: UInt64) { self.nanoseconds = nanoseconds }

    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.nanoseconds < rhs.nanoseconds }

    public func adding(seconds: Double) -> MonotonicInstant {
        MonotonicInstant(nanoseconds: nanoseconds &+ UInt64(max(0, seconds) * 1_000_000_000))
    }

    /// Seconds elapsed from `earlier` to `self`; zero if `earlier` is later.
    public func seconds(since earlier: MonotonicInstant) -> Double {
        guard nanoseconds >= earlier.nanoseconds else { return 0 }
        return Double(nanoseconds - earlier.nanoseconds) / 1_000_000_000
    }
}

public protocol MonotonicClock: Sendable {
    func now() -> MonotonicInstant
}

/// Uptime-based clock. Unaffected by wall-clock changes (T31).
public struct SystemMonotonicClock: MonotonicClock {
    public init() {}
    public func now() -> MonotonicInstant {
        MonotonicInstant(nanoseconds: DispatchTime.now().uptimeNanoseconds)
    }
}

/// Deterministic clock for tests and synthetic fixtures.
public final class ManualClock: MonotonicClock, @unchecked Sendable {
    private let lock = NSLock()
    private var current: MonotonicInstant

    public init(start: UInt64 = 1_000_000_000) { current = MonotonicInstant(nanoseconds: start) }

    public func now() -> MonotonicInstant {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    public func advance(seconds: Double) {
        lock.lock(); defer { lock.unlock() }
        current = current.adding(seconds: seconds)
    }
}

/// Wall-clock source for display/audit dates only.
public protocol WallClock: Sendable {
    func now() -> Date
}

public struct SystemWallClock: WallClock {
    public init() {}
    public func now() -> Date { Date() }
}

public final class FixedWallClock: WallClock, @unchecked Sendable {
    private let lock = NSLock()
    private var date: Date
    public init(_ date: Date) { self.date = date }
    public func now() -> Date { lock.lock(); defer { lock.unlock() }; return date }
    public func set(_ newDate: Date) { lock.lock(); date = newDate; lock.unlock() }
}
