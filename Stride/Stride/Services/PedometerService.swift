import Foundation
import CoreMotion

/// Wraps the iPhone's built-in step counter (CoreMotion).
/// Each instance owns its own pedometer, so one can watch "today" while
/// another watches the current walk.
final class PedometerService {
    struct Reading {
        var steps: Int
        var distanceMeters: Double?
        var paceSecondsPerMeter: Double?
        var cadenceStepsPerSecond: Double?

        init(data: CMPedometerData) {
            steps = data.numberOfSteps.intValue
            distanceMeters = data.distance?.doubleValue
            paceSecondsPerMeter = data.currentPace?.doubleValue
            cadenceStepsPerSecond = data.currentCadence?.doubleValue
        }
    }

    private let pedometer = CMPedometer()

    var isAvailable: Bool { CMPedometer.isStepCountingAvailable() }

    var isDenied: Bool {
        let status = CMPedometer.authorizationStatus()
        return status == .denied || status == .restricted
    }

    var isAuthorized: Bool { CMPedometer.authorizationStatus() == .authorized }

    /// Starts live updates. The reading is cumulative from `start`.
    /// The handler is always called on the main thread.
    func startLiveUpdates(from start: Date, onUpdate: @escaping (Reading) -> Void) {
        pedometer.stopUpdates()
        guard isAvailable else { return }
        pedometer.startUpdates(from: start) { data, _ in
            guard let data else { return }
            let reading = Reading(data: data)
            DispatchQueue.main.async { onUpdate(reading) }
        }
    }

    func stopLiveUpdates() {
        pedometer.stopUpdates()
    }

    /// One-off query of steps between two dates (the phone keeps about 7 days).
    func query(from start: Date, to end: Date) async -> Reading? {
        guard isAvailable else { return nil }
        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, _ in
                if let data {
                    continuation.resume(returning: Reading(data: data))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Steps for each of the last `days` days, ending today, from the phone's own history.
    func dailySteps(days: Int) async -> [DailySteps] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var result: [DailySteps] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: today),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            let reading = await query(from: dayStart, to: min(dayEnd, Date()))
            result.append(DailySteps(date: dayStart, steps: reading?.steps ?? 0))
        }
        return result
    }
}
