import Foundation

/// Section 15 development acceptance targets, frozen as a versioned policy.
/// These are targets, not measured device performance.
public struct AcceptanceProfile: Codable, Sendable, Hashable {
    public var version: Int
    public var startupDeadline: Double
    public var audioStaleThreshold: Double
    public var failureDisplayLatency: Double
    public var stopAcknowledgement: Double
    public var drainDeadline: Double
    public var finalizationDeadline: Double
    public var checkpointTarget: Double
    public var videoQueueBytes: Int
    public var audioQueueSeconds: Double
    public var audioQueueBytes: Int
    public var maxPendingTasks: Int
    public var recoveryRetriesPerLaunch: Int
    public var avDriftTarget: Double
    /// PTS discontinuity larger than this is recorded as a coverage gap for continuous sources.
    public var gapTolerance: Double
    /// Seconds of all-zero audio after which content is reported as suspicious.
    public var suspiciousZeroAudioSeconds: Double
    /// Seconds after which a projected status (Live Activity, app view of an extension) is stale.
    public var statusStaleAfter: Double

    public static let v1 = AcceptanceProfile(
        version: 1,
        startupDeadline: 15,
        audioStaleThreshold: 2,
        failureDisplayLatency: 1,
        stopAcknowledgement: 1,
        drainDeadline: 5,
        finalizationDeadline: 30,
        checkpointTarget: 5,
        videoQueueBytes: 32 * 1024 * 1024,
        audioQueueSeconds: 2,
        audioQueueBytes: 4 * 1024 * 1024,
        maxPendingTasks: 256,
        recoveryRetriesPerLaunch: 2,
        avDriftTarget: 0.1,
        gapTolerance: 0.1,
        suspiciousZeroAudioSeconds: 3,
        statusStaleAfter: 5
    )
}
