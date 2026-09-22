import Foundation
import ActivityKit

/// What the Live Activity on the Lock Screen and in the Dynamic Island shows
/// while a walk is being tracked.
struct WalkActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var steps: Int
        var distanceMeters: Double
        var calories: Double
        var elapsed: TimeInterval
        /// The instant the running timer should count up from. Nil while paused.
        var timerStart: Date?
        var isPaused: Bool
    }

    /// Fixed for the life of the walk.
    var startedAt: Date
}
