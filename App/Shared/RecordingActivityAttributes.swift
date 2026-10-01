import ActivityKit
import Foundation

/// Shared between the app and the widget extension. The Live Activity is a projection of
/// SessionController state; it is never the authority for capture liveness (section 14.9).
struct RecordingActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case starting, recording, limited, stopping, saving, ended
        }

        var phase: Phase
        /// Plain-language headline produced by the app's evidence-to-copy mapping.
        var headline: String
        /// When elapsed capture time began (nil until media arrives).
        var captureStartedAt: Date?
        /// Elapsed seconds at the last update, used when the timer is not running.
        var elapsedAtUpdate: Double
        /// Time of the last authoritative update, shown so staleness is visible.
        var updatedAt: Date
        var gapCount: Int
    }

    var title: String
}
