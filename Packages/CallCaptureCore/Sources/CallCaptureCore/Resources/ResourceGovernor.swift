import Foundation

public enum ResourceState: String, Codable, Sendable, Comparable, CaseIterable {
    case normal = "NORMAL"
    case conserve = "CONSERVE"
    case audioPriority = "AUDIO_PRIORITY"
    case protectedStop = "PROTECTED_STOP"

    public static func < (lhs: Self, rhs: Self) -> Bool { allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)! }

    /// Optional visuals (meters, previews, decorative motion) run only in NORMAL (UX16).
    public var allowsOptionalVisuals: Bool { self == .normal }
}

public enum ThermalLevel: String, Codable, Sendable { case nominal, fair, serious, critical }

public struct ResourceInputs: Sendable, Equatable {
    public var freeBytes: Int64
    public var thermal: ThermalLevel
    public var memoryWarning: Bool
    public var lowPowerMode: Bool
    /// Fraction 0...1 of the ingress bound currently used.
    public var queueFill: Double

    public init(freeBytes: Int64, thermal: ThermalLevel = .nominal, memoryWarning: Bool = false, lowPowerMode: Bool = false, queueFill: Double = 0) {
        self.freeBytes = freeBytes
        self.thermal = thermal
        self.memoryWarning = memoryWarning
        self.lowPowerMode = lowPowerMode
        self.queueFill = queueFill
    }
}

/// Section 15 storage reserve: encoding rate × remaining planned time is not assumed; instead the
/// reserve covers finalization workspace, journal writes and a margin, scaled by the format rate.
public struct StorageReserve: Sendable, Equatable {
    public var bytesPerSecond: Double
    public var finalizationWorkspaceSeconds: Double
    public var journalBytes: Int64
    public var marginBytes: Int64

    public static func forMode(_ mode: CaptureMode) -> StorageReserve {
        switch mode {
        case .audioOnly: return StorageReserve(bytesPerSecond: 24_000, finalizationWorkspaceSeconds: 120, journalBytes: 2 << 20, marginBytes: 100 << 20)
        case .screenOnly, .screenAndAudio:
            // ~6 Mbit/s H.264 + AAC; master assembly may need a copy of recent segments.
            return StorageReserve(bytesPerSecond: 800_000, finalizationWorkspaceSeconds: 300, journalBytes: 8 << 20, marginBytes: 300 << 20)
        }
    }

    /// Bytes that must stay free to finish and validate safely.
    public var reserveBytes: Int64 {
        Int64(bytesPerSecond * finalizationWorkspaceSeconds) + journalBytes + marginBytes
    }

    public func canStart(freeBytes: Int64) -> Bool { freeBytes > reserveBytes + Int64(bytesPerSecond * 60) }

    /// Estimated recording time with uncertainty: a range, never a single promise.
    public func estimatedSeconds(freeBytes: Int64) -> ClosedRange<Double> {
        let usable = max(0, Double(freeBytes - reserveBytes))
        let nominal = usable / bytesPerSecond
        return (nominal * 0.7)...(nominal * 1.1)
    }
}

/// ResourceGovernor: only optional work and video quality degrade automatically.
/// Losing required media is still a reported loss (section 15).
public struct ResourceGovernor: Sendable {
    public var reserve: StorageReserve
    public private(set) var state: ResourceState = .normal

    public init(reserve: StorageReserve) { self.reserve = reserve }

    @discardableResult
    public mutating func evaluate(_ inputs: ResourceInputs) -> ResourceState {
        var next: ResourceState = .normal
        if inputs.freeBytes <= reserve.reserveBytes || inputs.thermal == .critical {
            next = .protectedStop
        } else if inputs.thermal == .serious || inputs.memoryWarning || inputs.queueFill > 0.8
                    || inputs.freeBytes <= reserve.reserveBytes + Int64(reserve.bytesPerSecond * 300) {
            next = .audioPriority
        } else if inputs.thermal == .fair || inputs.lowPowerMode || inputs.queueFill > 0.5 {
            next = .conserve
        }
        state = next
        return next
    }
}
