import Foundation

public enum SourceKind: String, Codable, Sendable, CaseIterable, Comparable {
    case screen
    case microphone
    case appAudio

    public var isAudio: Bool { self != .screen }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        allCases.firstIndex(of: lhs)! < allCases.firstIndex(of: rhs)!
    }
}

public enum CaptureMode: String, Codable, Sendable, CaseIterable {
    case screenOnly
    case screenAndAudio
    case audioOnly
}

public enum SourceRequirement: String, Codable, Sendable {
    case required
    case optional
}

/// What to do when a required source is not confirmed by its startup deadline.
public enum UnmetRequirementPolicy: String, Codable, Sendable {
    /// Keep recording, show the limitation and report the gap (standard mode).
    case continueWithWarning
    /// Important Recording mode: preserve media captured so far and stop safely,
    /// unless the user explicitly accepts a new limited contract (section 14.4).
    case protectedStop
}

public struct SourcePolicy: Codable, Sendable, Hashable {
    public var kind: SourceKind
    public var requirement: SourceRequirement
    /// Whether this source is expected to deliver continuously (drives the stale threshold).
    public var expectsContinuousDelivery: Bool

    public init(kind: SourceKind, requirement: SourceRequirement, expectsContinuousDelivery: Bool) {
        self.kind = kind
        self.requirement = requirement
        self.expectsContinuousDelivery = expectsContinuousDelivery
    }
}

/// Validation coverage that must finish before FULL_CHECKS_PASSED can be claimed.
public enum ValidationCoverage: String, Codable, Sendable {
    case basic
    case full
}

/// Section 6.1. Frozen before a session starts; changing a required source creates a new segment.
public struct CaptureContract: Codable, Sendable, Hashable, Identifiable {
    public static let schemaVersion = 1

    public var id: UUID
    public var schemaVersion: Int
    public var version: Int
    public var mode: CaptureMode
    public var sources: [SourcePolicy]
    public var unmetRequirementPolicy: UnmetRequirementPolicy
    public var isImportantMode: Bool
    public var requiredValidation: ValidationCoverage
    public var profileVersion: Int

    public init(
        id: UUID = UUID(),
        version: Int = 1,
        mode: CaptureMode,
        sources: [SourcePolicy],
        importantMode: Bool = false,
        requiredValidation: ValidationCoverage = .full,
        profileVersion: Int = AcceptanceProfile.v1.version
    ) {
        self.id = id
        self.schemaVersion = Self.schemaVersion
        self.version = version
        self.mode = mode
        self.sources = sources.sorted { $0.kind < $1.kind }
        self.isImportantMode = importantMode
        self.unmetRequirementPolicy = importantMode ? .protectedStop : .continueWithWarning
        self.requiredValidation = requiredValidation
        self.profileVersion = profileVersion
    }

    public func policy(for kind: SourceKind) -> SourcePolicy? { sources.first { $0.kind == kind } }
    public var requiredSources: [SourceKind] { sources.filter { $0.requirement == .required }.map(\.kind) }
    public var requestedSources: [SourceKind] { sources.map(\.kind) }

    /// Standard contract for the user's selected scope. Microphone is required when audio
    /// is requested because it is the one audio source the app can observe directly; app
    /// audio is optional because the platform may never supply it (section 2).
    public static func standard(mode: CaptureMode, includeMicrophone: Bool = true, importantMode: Bool = false) -> CaptureContract {
        var sources: [SourcePolicy] = []
        if mode != .audioOnly {
            sources.append(SourcePolicy(kind: .screen, requirement: .required, expectsContinuousDelivery: false))
        }
        if mode != .screenOnly {
            if includeMicrophone {
                sources.append(SourcePolicy(kind: .microphone, requirement: .required, expectsContinuousDelivery: true))
            }
            sources.append(SourcePolicy(kind: .appAudio, requirement: importantMode ? .required : .optional, expectsContinuousDelivery: true))
        }
        return CaptureContract(mode: mode, sources: sources, importantMode: importantMode)
    }

    /// A new contract segment for an explicit user choice to continue with fewer requirements.
    /// The caller must retain the original unmet requirement in the report.
    public func limited(droppingRequirementFor kind: SourceKind) -> CaptureContract {
        var copy = self
        copy.version += 1
        copy.sources = sources.map { p in
            var p = p
            if p.kind == kind { p.requirement = .optional }
            return p
        }
        return copy
    }
}
