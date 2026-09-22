import Foundation
import Combine
import WidgetKit

/// Live step count for today, blending the phone's motion chip (instant)
/// with Apple Health (the number the Health app shows, including a watch).
@MainActor
final class TodayModel: ObservableObject {
    @Published private(set) var steps: Int = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var weeklySteps: [DailySteps] = []
    @Published private(set) var monthlySteps: [DailySteps] = []
    @Published private(set) var motionDenied = false
    @Published private(set) var pedometerUnavailable = false
    @Published private(set) var lastRefresh: Date?
    @Published private(set) var streakDays: Int = 0

    private let pedometer: PedometerService
    private let health: HealthKitService
    private let profile: UserProfile

    private var healthTodaySteps: Int?
    private var healthTodayDistance: Double?
    private var pedometerAtHealthSync = 0
    private var pedometerToday = 0
    private var pedometerDistance: Double = 0
    private var refreshTimer: AnyCancellable?
    private var isRunning = false
    private var lastPublish = Date.distantPast
    private var walkActive = false

    init(pedometer: PedometerService, health: HealthKitService, profile: UserProfile) {
        self.pedometer = pedometer
        self.health = health
        self.profile = profile
    }

    var calories: Double {
        CalorieEstimator.caloriesFromSteps(steps, body: profile.body)
    }

    var goalProgress: Double {
        guard profile.dailyGoal > 0 else { return 0 }
        return min(Double(steps) / Double(profile.dailyGoal), 1)
    }

    var goalReached: Bool { steps >= profile.dailyGoal && profile.dailyGoal > 0 }

    var weeklyAverage: Int {
        guard !weeklySteps.isEmpty else { return 0 }
        return weeklySteps.reduce(0) { $0 + $1.steps } / weeklySteps.count
    }

    /// Hands today's numbers to the widgets and asks them to redraw. Throttled,
    /// because steps arrive far more often than a widget can usefully change.
    func publishSnapshot(walkActive: Bool? = nil, force: Bool = false) {
        if let walkActive { self.walkActive = walkActive }
        let now = Date()
        guard force || now.timeIntervalSince(lastPublish) >= 60 else { return }
        lastPublish = now
        streakDays = AchievementEngine.streak(days: monthlySteps, goal: profile.dailyGoal)
        let snapshot = StrideSnapshot(steps: steps,
                                      goal: profile.dailyGoal,
                                      distanceMeters: distanceMeters,
                                      calories: calories,
                                      streakDays: streakDays,
                                      walkActive: self.walkActive,
                                      updated: Date())
        AppGroup.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Begins live updates. Safe to call more than once.
    func start() {
        guard !isRunning else {
            Task { await refresh() }
            return
        }
        isRunning = true
        pedometerUnavailable = !pedometer.isAvailable
        startPedometer()
        health.observeSteps { [weak self] in
            Task { await self?.refresh() }
        }
        refreshTimer = Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
        Task { await refresh() }
    }

    private func startPedometer() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        pedometer.startLiveUpdates(from: startOfDay) { [weak self] reading in
            guard let self else { return }
            self.motionDenied = false
            self.pedometerToday = reading.steps
            self.pedometerDistance = reading.distanceMeters ?? self.pedometerDistance
            self.recompute()
        }
    }

    /// Re-reads today's totals and the history from Apple Health (or the phone).
    func refresh() async {
        motionDenied = pedometer.isDenied
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)

        // A new day: clear yesterday's numbers and restart the live stream from midnight.
        if let last = lastRefresh, !Calendar.current.isDate(last, inSameDayAs: now) {
            resetForNewDay()
            startPedometer()
        }

        if health.isAvailable, health.hasRequestedAccess {
            let healthSteps = await health.todaySteps()
            let healthDistance = await health.todayDistanceMeters()
            // Health receives the phone's steps in batches, minutes behind the motion
            // chip. Baseline the live delta at the end of Health's latest sample so the
            // steps taken since then are added on top instead of being lost.
            let latestSampleEnd = await health.latestStepSampleEnd()
            let anchor = min(latestSampleEnd ?? now, now)
            var phoneAtAnchor = 0
            if anchor > startOfDay {
                phoneAtAnchor = await pedometer.query(from: startOfDay, to: anchor)?.steps ?? pedometerToday
            }
            let phoneNow = await pedometer.query(from: startOfDay, to: now)
            healthTodaySteps = healthSteps
            healthTodayDistance = healthDistance
            pedometerAtHealthSync = phoneAtAnchor
            if let phoneNow {
                pedometerToday = max(pedometerToday, phoneNow.steps)
                pedometerDistance = phoneNow.distanceMeters ?? pedometerDistance
            }
        } else {
            healthTodaySteps = nil
            healthTodayDistance = nil
            if let phoneNow = await pedometer.query(from: startOfDay, to: now) {
                pedometerToday = max(pedometerToday, phoneNow.steps)
                pedometerDistance = phoneNow.distanceMeters ?? pedometerDistance
            }
        }
        recompute()
        await refreshHistory()
        lastRefresh = now
        publishSnapshot(force: true)
    }

    private func resetForNewDay() {
        steps = 0
        distanceMeters = 0
        pedometerToday = 0
        pedometerDistance = 0
        pedometerAtHealthSync = 0
        healthTodaySteps = nil
        healthTodayDistance = nil
    }

    private func refreshHistory() async {
        var month: [DailySteps]? = nil
        if health.isAvailable, health.hasRequestedAccess {
            month = await health.dailySteps(days: 30)
        }
        if month == nil || (month?.allSatisfy { $0.steps == 0 } ?? true) {
            let phoneWeek = await pedometer.dailySteps(days: 7)
            if !phoneWeek.isEmpty { month = phoneWeek }
        }
        guard var days = month else { return }
        // Keep today's bar in step with the live number.
        if let index = days.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
            days[index].steps = max(days[index].steps, steps)
        }
        monthlySteps = days
        weeklySteps = Array(days.suffix(7))
    }

    private func recompute() {
        let blended: Int
        if let healthTodaySteps {
            blended = healthTodaySteps + max(0, pedometerToday - pedometerAtHealthSync)
        } else {
            blended = pedometerToday
        }
        // Within a day the count only ever grows (Health can briefly lag the live number).
        steps = max(steps, blended)
        if let healthTodayDistance, healthTodayDistance > 0 {
            distanceMeters = max(healthTodayDistance, pedometerDistance)
        } else if pedometerDistance > 0 {
            distanceMeters = pedometerDistance
        } else {
            distanceMeters = CalorieEstimator.distanceFromSteps(steps, body: profile.body)
        }
        if let index = weeklySteps.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
            weeklySteps[index].steps = max(weeklySteps[index].steps, steps)
        }
        if let index = monthlySteps.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
            monthlySteps[index].steps = max(monthlySteps[index].steps, steps)
        }
    }
}
