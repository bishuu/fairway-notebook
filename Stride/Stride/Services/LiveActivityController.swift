import Foundation
import ActivityKit

/// Drives the Lock Screen and Dynamic Island card that shows a walk in progress.
@MainActor
final class LiveActivityController {
    private var activity: Activity<WalkActivityAttributes>?

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(startedAt: Date) {
        guard isSupported, activity == nil else { return }
        let state = WalkActivityAttributes.ContentState(steps: 0, distanceMeters: 0, calories: 0,
                                                        elapsed: 0, timerStart: startedAt, isPaused: false)
        activity = try? Activity.request(
            attributes: WalkActivityAttributes(startedAt: startedAt),
            content: ActivityContent(state: state, staleDate: nil),
            pushType: nil
        )
    }

    func update(steps: Int, distanceMeters: Double, calories: Double,
                elapsed: TimeInterval, isPaused: Bool) {
        guard let activity else { return }
        let state = WalkActivityAttributes.ContentState(
            steps: steps,
            distanceMeters: distanceMeters,
            calories: calories,
            elapsed: elapsed,
            timerStart: isPaused ? nil : Date().addingTimeInterval(-elapsed),
            isPaused: isPaused
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end(steps: Int, distanceMeters: Double, calories: Double, elapsed: TimeInterval) {
        guard let activity else { return }
        self.activity = nil
        let state = WalkActivityAttributes.ContentState(steps: steps, distanceMeters: distanceMeters,
                                                        calories: calories, elapsed: elapsed,
                                                        timerStart: nil, isPaused: true)
        Task {
            await activity.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .immediate)
        }
    }
}
