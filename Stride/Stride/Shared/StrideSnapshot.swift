import Foundation

/// The small bundle of numbers the widgets draw.
struct StrideSnapshot: Codable, Hashable {
    var steps: Int
    var goal: Int
    var distanceMeters: Double
    var calories: Double
    var streakDays: Int
    var walkActive: Bool
    var updated: Date

    var progress: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1)
    }

    var goalReached: Bool { goal > 0 && steps >= goal }

    var remaining: Int { max(goal - steps, 0) }

    static let placeholder = StrideSnapshot(steps: 7420, goal: 10_000, distanceMeters: 5600,
                                            calories: 310, streakDays: 4, walkActive: false,
                                            updated: Date())
}
