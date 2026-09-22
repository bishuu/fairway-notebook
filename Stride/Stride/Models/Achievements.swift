import Foundation
import SwiftUI

/// A badge the walker can earn.
struct Achievement: Identifiable, Hashable {
    enum Tier: Int { case bronze, silver, gold }

    var id: String
    var title: String
    var detail: String
    var icon: String
    var tier: Tier
    /// 0...1, how close the badge is to being earned.
    var progress: Double
    var unlockedOn: Date?

    var unlocked: Bool { unlockedOn != nil }

    var tint: Color {
        switch tier {
        case .bronze: return Theme.flame
        case .silver: return Theme.sky
        case .gold: return Theme.gold
        }
    }
}

/// A personal best.
struct PersonalRecord: Identifiable, Hashable {
    var id: String
    var title: String
    var value: String
    var caption: String
    var icon: String
    var tint: Color
}

/// Works out streaks, badges and records from the saved walks and step history.
enum AchievementEngine {

    /// Consecutive days up to today where the step goal was met. Today counts
    /// only once it is met, so a quiet morning does not wipe out the streak.
    static func streak(days: [DailySteps], goal: Int) -> Int {
        guard goal > 0 else { return 0 }
        let calendar = Calendar.current
        let met = Set(days.filter { $0.steps >= goal }.map { calendar.startOfDay(for: $0.date) })
        guard !met.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: Date())
        var cursor = met.contains(today)
            ? today
            : (calendar.date(byAdding: .day, value: -1, to: today) ?? today)

        var streak = 0
        while met.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    /// The longest run of goal days anywhere in the history given.
    static func bestStreak(days: [DailySteps], goal: Int) -> Int {
        guard goal > 0 else { return 0 }
        let calendar = Calendar.current
        let met = Set(days.filter { $0.steps >= goal }.map { calendar.startOfDay(for: $0.date) }).sorted()
        guard !met.isEmpty else { return 0 }

        var best = 1
        var run = 1
        for index in 1..<met.count {
            let gap = calendar.dateComponents([.day], from: met[index - 1], to: met[index]).day ?? 0
            run = gap == 1 ? run + 1 : 1
            best = max(best, run)
        }
        return best
    }

    static func records(walks: [Walk], days: [DailySteps]) -> [PersonalRecord] {
        var records: [PersonalRecord] = []

        if let bestDay = days.max(by: { $0.steps < $1.steps }), bestDay.steps > 0 {
            records.append(PersonalRecord(id: "bestDay", title: "Most steps in a day",
                                          value: Format.steps(bestDay.steps),
                                          caption: bestDay.date.formatted(.dateTime.month(.abbreviated).day()),
                                          icon: "figure.walk", tint: Theme.mint))
        }
        if let longest = walks.max(by: { $0.distanceMeters < $1.distanceMeters }), longest.distanceMeters > 0 {
            records.append(PersonalRecord(id: "longest", title: "Longest walk",
                                          value: Format.distance(longest.distanceMeters),
                                          caption: longest.start.formatted(.dateTime.month(.abbreviated).day()),
                                          icon: "point.topleft.down.to.point.bottomright.curvepath.fill", tint: Theme.sky))
        }
        if let longestTime = walks.max(by: { $0.activeSeconds < $1.activeSeconds }), longestTime.activeSeconds > 0 {
            records.append(PersonalRecord(id: "longestTime", title: "Longest time",
                                          value: Format.shortDuration(longestTime.activeSeconds),
                                          caption: longestTime.start.formatted(.dateTime.month(.abbreviated).day()),
                                          icon: "timer", tint: Theme.violet))
        }
        let paced = walks.filter { $0.distanceMeters > 800 }
        if let fastest = paced.compactMap({ walk -> (Walk, Double)? in
            guard let pace = walk.paceSecondsPerMeter else { return nil }
            return (walk, pace)
        }).min(by: { $0.1 < $1.1 }) {
            records.append(PersonalRecord(id: "fastest", title: "Fastest pace",
                                          value: Format.pace(secondsPerMeter: fastest.1),
                                          caption: fastest.0.start.formatted(.dateTime.month(.abbreviated).day()),
                                          icon: "speedometer", tint: Theme.gold))
        }
        if let burn = walks.max(by: { $0.calories < $1.calories }), burn.calories > 0 {
            records.append(PersonalRecord(id: "calories", title: "Most calories",
                                          value: Format.calories(burn.calories) + " kcal",
                                          caption: burn.start.formatted(.dateTime.month(.abbreviated).day()),
                                          icon: "flame.fill", tint: Theme.flame))
        }
        if let climb = walks.max(by: { $0.elevationGainMeters < $1.elevationGainMeters }), climb.elevationGainMeters > 5 {
            records.append(PersonalRecord(id: "climb", title: "Biggest climb",
                                          value: Format.elevation(climb.elevationGainMeters),
                                          caption: climb.start.formatted(.dateTime.month(.abbreviated).day()),
                                          icon: "mountain.2.fill", tint: Theme.rose))
        }
        return records
    }

    static func achievements(walks: [Walk], days: [DailySteps], goal: Int) -> [Achievement] {
        let totalDistance = walks.reduce(0) { $0 + $1.distanceMeters }
        let currentStreak = streak(days: days, goal: goal)
        let best = max(bestStreak(days: days, goal: goal), currentStreak)
        let bestDay = days.map { $0.steps }.max() ?? 0
        let longestWalk = walks.map { $0.distanceMeters }.max() ?? 0
        let longestTime = walks.map { $0.activeSeconds }.max() ?? 0
        let biggestClimb = walks.map { $0.elevationGainMeters }.max() ?? 0
        let earliest = walks.contains { Calendar.current.component(.hour, from: $0.start) < 8 }
        let latest = walks.contains { Calendar.current.component(.hour, from: $0.start) >= 21 }
        let fastest = walks.filter { $0.distanceMeters > 800 }.compactMap { $0.paceSecondsPerMeter }.min()

        func date(where predicate: (Walk) -> Bool) -> Date? {
            walks.filter(predicate).map { $0.start }.min()
        }

        var list: [Achievement] = []

        list.append(Achievement(id: "first", title: "First Steps", detail: "Finish your first walk",
                                icon: "shoe.2.fill", tier: .bronze,
                                progress: walks.isEmpty ? 0 : 1,
                                unlockedOn: walks.map { $0.start }.min()))

        list.append(Achievement(id: "explorer", title: "Explorer", detail: "Record 10 walks",
                                icon: "map.fill", tier: .bronze,
                                progress: min(Double(walks.count) / 10, 1),
                                unlockedOn: walks.count >= 10 ? walks.sorted { $0.start < $1.start }[9].start : nil))

        list.append(Achievement(id: "trailblazer", title: "Trailblazer", detail: "Record 50 walks",
                                icon: "signpost.right.fill", tier: .silver,
                                progress: min(Double(walks.count) / 50, 1),
                                unlockedOn: walks.count >= 50 ? walks.sorted { $0.start < $1.start }[49].start : nil))

        list.append(Achievement(id: "fiveK", title: "5K Club", detail: "Walk 5 km in one go",
                                icon: "figure.walk.circle.fill", tier: .bronze,
                                progress: min(longestWalk / 5000, 1),
                                unlockedOn: date { $0.distanceMeters >= 5000 }))

        list.append(Achievement(id: "tenK", title: "10K Day", detail: "Take 10,000 steps in a day",
                                icon: "sparkles", tier: .silver,
                                progress: min(Double(bestDay) / 10_000, 1),
                                unlockedOn: days.first { $0.steps >= 10_000 }?.date))

        list.append(Achievement(id: "twentyK", title: "Big Day", detail: "Take 20,000 steps in a day",
                                icon: "bolt.fill", tier: .gold,
                                progress: min(Double(bestDay) / 20_000, 1),
                                unlockedOn: days.first { $0.steps >= 20_000 }?.date))

        list.append(Achievement(id: "hour", title: "The Long Way", detail: "Walk for a full hour",
                                icon: "hourglass", tier: .silver,
                                progress: min(longestTime / 3600, 1),
                                unlockedOn: date { $0.activeSeconds >= 3600 }))

        list.append(Achievement(id: "half", title: "Half Marathon", detail: "21.1 km walked in total",
                                icon: "flag.fill", tier: .silver,
                                progress: min(totalDistance / 21_097, 1),
                                unlockedOn: cumulativeDate(walks: walks, target: 21_097)))

        list.append(Achievement(id: "marathon", title: "Marathon", detail: "42.2 km walked in total",
                                icon: "flag.checkered", tier: .gold,
                                progress: min(totalDistance / 42_195, 1),
                                unlockedOn: cumulativeDate(walks: walks, target: 42_195)))

        list.append(Achievement(id: "century", title: "Century", detail: "100 km walked in total",
                                icon: "crown.fill", tier: .gold,
                                progress: min(totalDistance / 100_000, 1),
                                unlockedOn: cumulativeDate(walks: walks, target: 100_000)))

        list.append(Achievement(id: "week", title: "Week Warrior", detail: "Hit your goal 7 days running",
                                icon: "calendar", tier: .bronze,
                                progress: min(Double(best) / 7, 1),
                                unlockedOn: best >= 7 ? Date() : nil))

        list.append(Achievement(id: "fortnight", title: "Fortnight", detail: "Hit your goal 14 days running",
                                icon: "calendar.badge.checkmark", tier: .silver,
                                progress: min(Double(best) / 14, 1),
                                unlockedOn: best >= 14 ? Date() : nil))

        list.append(Achievement(id: "month", title: "Month Master", detail: "Hit your goal 30 days running",
                                icon: "star.circle.fill", tier: .gold,
                                progress: min(Double(best) / 30, 1),
                                unlockedOn: best >= 30 ? Date() : nil))

        list.append(Achievement(id: "early", title: "Early Bird", detail: "Start a walk before 8am",
                                icon: "sunrise.fill", tier: .bronze,
                                progress: earliest ? 1 : 0,
                                unlockedOn: date { Calendar.current.component(.hour, from: $0.start) < 8 }))

        list.append(Achievement(id: "night", title: "Night Owl", detail: "Start a walk after 9pm",
                                icon: "moon.stars.fill", tier: .bronze,
                                progress: latest ? 1 : 0,
                                unlockedOn: date { Calendar.current.component(.hour, from: $0.start) >= 21 }))

        list.append(Achievement(id: "climb", title: "Hill Climber", detail: "Climb 100 m in one walk",
                                icon: "mountain.2.fill", tier: .silver,
                                progress: min(biggestClimb / 100, 1),
                                unlockedOn: date { $0.elevationGainMeters >= 100 }))

        // 13:00 per mile is a brisk walk; stored as seconds per metre.
        let briskPace = 780.0 / 1609.344
        list.append(Achievement(id: "brisk", title: "Brisk Walker", detail: "Average a 13-minute mile",
                                icon: "hare.fill", tier: .gold,
                                progress: fastest.map { min(briskPace / $0, 1) } ?? 0,
                                unlockedOn: date { ($0.paceSecondsPerMeter ?? .infinity) <= briskPace && $0.distanceMeters > 800 }))

        return list
    }

    /// When the running distance total first crossed `target`.
    private static func cumulativeDate(walks: [Walk], target: Double) -> Date? {
        var running = 0.0
        for walk in walks.sorted(by: { $0.start < $1.start }) {
            running += walk.distanceMeters
            if running >= target { return walk.start }
        }
        return nil
    }
}
