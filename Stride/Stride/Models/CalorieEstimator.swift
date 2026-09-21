import Foundation

/// Estimates calories burned while walking from body inputs.
///
/// Uses MET values for walking from the Compendium of Physical Activities,
/// scaled by body weight and time, with stride length (from height and gender)
/// used to turn steps into distance when there is no GPS track.
enum CalorieEstimator {
    /// Walking MET by speed in miles per hour (Compendium of Physical Activities).
    private static let metTable: [(mph: Double, met: Double)] = [
        (1.5, 2.0), (2.0, 2.8), (2.5, 3.0), (3.0, 3.5),
        (3.5, 4.3), (4.0, 5.0), (4.5, 7.0), (5.0, 8.3)
    ]

    static func met(forSpeedMph mph: Double) -> Double {
        guard let first = metTable.first, let last = metTable.last else { return 3.5 }
        if mph <= first.mph { return first.met }
        if mph >= last.mph { return last.met }
        for index in 1..<metTable.count {
            let lower = metTable[index - 1]
            let upper = metTable[index]
            if mph <= upper.mph {
                let fraction = (mph - lower.mph) / (upper.mph - lower.mph)
                return lower.met + (upper.met - lower.met) * fraction
            }
        }
        return last.met
    }

    /// Calories for a walk of a known distance and duration.
    static func walkingCalories(distanceMeters: Double, seconds: TimeInterval, body: BodyStats) -> Double {
        guard seconds > 0, distanceMeters > 0 else { return 0 }
        let mph = distanceMeters / seconds * 2.2369363
        let met = met(forSpeedMph: mph)
        let hours = seconds / 3600
        return met * body.weightKg * hours * body.gender.energyFactor
    }

    /// Calories for a step count when only steps are known (assumes an average 3 mph pace).
    static func caloriesFromSteps(_ steps: Int, body: BodyStats) -> Double {
        guard steps > 0 else { return 0 }
        let distance = Double(steps) * body.strideMeters
        let seconds = distance / (3.0 / 2.2369363)
        return walkingCalories(distanceMeters: distance, seconds: seconds, body: body)
    }

    /// Distance estimate for a step count from stride length.
    static func distanceFromSteps(_ steps: Int, body: BodyStats) -> Double {
        Double(max(steps, 0)) * body.strideMeters
    }
}
