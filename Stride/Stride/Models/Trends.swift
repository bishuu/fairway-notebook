import Foundation

/// One bucket in a trend report (a week or a month).
struct TrendBucket: Identifiable, Hashable {
    var start: Date
    var label: String
    var steps: Int
    var days: Int
    var id: Date { start }

    var dailyAverage: Int { days > 0 ? steps / days : 0 }
}

/// Rolls the day-by-day step history and the saved walks up into periods.
enum Trends {
    enum Period: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        var id: String { rawValue }
    }

    struct Report {
        var buckets: [TrendBucket]
        var currentSteps: Int
        var previousSteps: Int
        var currentWalks: Int
        var currentDistance: Double
        var currentCalories: Double
        var currentActiveSeconds: TimeInterval
        var periodStart: Date
        var periodLabel: String

        /// Percentage change against the period before, or nil when there is nothing to compare.
        var change: Double? {
            guard previousSteps > 0 else { return nil }
            return (Double(currentSteps) - Double(previousSteps)) / Double(previousSteps) * 100
        }
    }

    static func report(period: Period, days: [DailySteps], walks: [Walk]) -> Report {
        let calendar = Calendar.current
        let now = Date()
        let component: Calendar.Component = period == .week ? .weekOfYear : .month

        func bucketStart(_ date: Date) -> Date {
            if period == .week {
                return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
            }
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        }

        var totals: [Date: (steps: Int, days: Int)] = [:]
        for day in days {
            let key = bucketStart(day.date)
            var entry = totals[key] ?? (0, 0)
            entry.steps += day.steps
            entry.days += 1
            totals[key] = entry
        }

        let buckets = totals.keys.sorted().map { key -> TrendBucket in
            let entry = totals[key] ?? (0, 0)
            let label: String
            if period == .week {
                label = key.formatted(.dateTime.month(.abbreviated).day())
            } else {
                label = key.formatted(.dateTime.month(.abbreviated))
            }
            return TrendBucket(start: key, label: label, steps: entry.steps, days: entry.days)
        }

        let thisStart = bucketStart(now)
        let previousStart = calendar.date(byAdding: component, value: -1, to: thisStart) ?? thisStart
        let currentSteps = totals[thisStart]?.steps ?? 0
        let previousSteps = totals[previousStart]?.steps ?? 0

        let periodWalks = walks.filter { $0.start >= thisStart }
        let label = period == .week ? "This week" : "This month"

        return Report(buckets: buckets,
                      currentSteps: currentSteps,
                      previousSteps: previousSteps,
                      currentWalks: periodWalks.count,
                      currentDistance: periodWalks.reduce(0) { $0 + $1.distanceMeters },
                      currentCalories: periodWalks.reduce(0) { $0 + $1.calories },
                      currentActiveSeconds: periodWalks.reduce(0) { $0 + $1.activeSeconds },
                      periodStart: thisStart,
                      periodLabel: label)
    }
}
