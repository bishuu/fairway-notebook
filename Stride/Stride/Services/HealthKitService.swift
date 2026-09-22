import Foundation
import HealthKit
import CoreLocation
import Combine

/// The bridge to Apple Health: reads steps and body measurements, and saves
/// finished walks as workouts (with their route) so they show up in Health
/// and Fitness.
@MainActor
final class HealthKitService: ObservableObject {
    enum HealthError: LocalizedError {
        case unavailable
        case notAuthorized
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .unavailable: return "Apple Health is not available on this device."
            case .notAuthorized: return "Stride does not have permission to save workouts to Apple Health."
            case .saveFailed: return "The workout could not be saved to Apple Health."
            }
        }
    }

    struct BodyMetrics {
        var weightLb: Double?
        var heightInches: Double?
        var gender: Gender?
    }

    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)
    private let distanceType = HKQuantityType(.distanceWalkingRunning)
    private let energyType = HKQuantityType(.activeEnergyBurned)
    private let heartRateType = HKQuantityType(.heartRate)
    private let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
    private var observerQuery: HKObserverQuery?
    private var heartRateQuery: HKAnchoredObjectQuery?

    /// True after the permission sheet has been shown at least once.
    @Published private(set) var hasRequestedAccess: Bool

    init() {
        hasRequestedAccess = UserDefaults.standard.bool(forKey: "health.requested")
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Apple never reveals whether reading was allowed, but it does for writing.
    var canSaveWorkouts: Bool {
        isAvailable && store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingAuthorized
    }

    var workoutSharingDenied: Bool {
        isAvailable && store.authorizationStatus(for: HKObjectType.workoutType()) == .sharingDenied
    }

    // MARK: - Permission

    @discardableResult
    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        let share: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            distanceType,
            energyType,
            HKSeriesType.workoutRoute()
        ]
        let read: Set<HKObjectType> = [
            stepType,
            distanceType,
            energyType,
            heartRateType,
            HKObjectType.workoutType(),
            HKQuantityType(.bodyMass),
            HKQuantityType(.height),
            HKCharacteristicType(.biologicalSex)
        ]
        do {
            try await store.requestAuthorization(toShare: share, read: read)
            hasRequestedAccess = true
            UserDefaults.standard.set(true, forKey: "health.requested")
            return true
        } catch {
            return false
        }
    }

    // MARK: - Reading

    /// Total steps so far today as Apple Health counts them (phone + watch).
    func todaySteps() async -> Int? {
        guard let value = await sumToday(stepType, unit: .count()) else { return nil }
        return Int(value)
    }

    func todayDistanceMeters() async -> Double? {
        await sumToday(distanceType, unit: .meter())
    }

    private func sumToday(_ type: HKQuantityType, unit: HKUnit) async -> Double? {
        guard isAvailable else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type,
                                          quantitySamplePredicate: predicate,
                                          options: .cumulativeSum) { _, statistics, _ in
                let value = statistics?.sumQuantity()?.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }

    /// Steps per day for the last `days` days (oldest first). Nil when Health can't answer.
    func dailySteps(days: Int) async -> [DailySteps]? {
        guard isAvailable, days > 0 else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -(days - 1), to: today) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)
        let now = Date()
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(quantityType: stepType,
                                                    quantitySamplePredicate: predicate,
                                                    options: .cumulativeSum,
                                                    anchorDate: today,
                                                    intervalComponents: DateComponents(day: 1))
            query.initialResultsHandler = { _, collection, _ in
                guard let collection else {
                    continuation.resume(returning: nil)
                    return
                }
                var results: [DailySteps] = []
                collection.enumerateStatistics(from: start, to: now) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: .count()) ?? 0
                    results.append(DailySteps(date: statistics.startDate, steps: Int(value)))
                }
                continuation.resume(returning: results)
            }
            store.execute(query)
        }
    }

    // MARK: - Heart rate

    /// Streams heart rate while a walk is running. Values come from a paired
    /// Apple Watch or any other monitor that writes to Health; without one
    /// the handler simply never fires.
    func startHeartRateUpdates(from start: Date, onUpdate: @escaping (Double) -> Void) {
        guard isAvailable else { return }
        stopHeartRateUpdates()
        let predicate = HKQuery.predicateForSamples(withStart: start, end: nil, options: .strictStartDate)

        func handle(_ samples: [HKSample]?) {
            guard let latest = samples?.compactMap({ $0 as? HKQuantitySample })
                .max(by: { $0.endDate < $1.endDate }) else { return }
            let value = latest.quantity.doubleValue(for: self.heartRateUnit)
            DispatchQueue.main.async { onUpdate(value) }
        }

        let query = HKAnchoredObjectQuery(type: heartRateType, predicate: predicate,
                                          anchor: nil, limit: HKObjectQueryNoLimit) { _, samples, _, _, _ in
            handle(samples)
        }
        query.updateHandler = { _, samples, _, _, _ in
            handle(samples)
        }
        heartRateQuery = query
        store.execute(query)
    }

    func stopHeartRateUpdates() {
        if let heartRateQuery { store.stop(heartRateQuery) }
        heartRateQuery = nil
    }

    /// Average and highest heart rate recorded across a finished walk.
    func heartRateSummary(from start: Date, to end: Date) async -> (average: Double, max: Double)? {
        guard isAvailable, end > start else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: heartRateType,
                                          quantitySamplePredicate: predicate,
                                          options: [.discreteAverage, .discreteMax]) { _, statistics, _ in
                guard let statistics,
                      let average = statistics.averageQuantity()?.doubleValue(for: self.heartRateUnit),
                      let maximum = statistics.maximumQuantity()?.doubleValue(for: self.heartRateUnit) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: (average, maximum))
            }
            store.execute(query)
        }
    }

    /// When the most recent step sample in Health ends (nil when there are none).
    func latestStepSampleEnd() async -> Date? {
        guard isAvailable else { return nil }
        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: stepType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: samples?.first?.endDate)
            }
            store.execute(query)
        }
    }

    /// Calls `handler` on the main thread whenever new step data lands in Health.
    func observeSteps(_ handler: @escaping () -> Void) {
        guard isAvailable else { return }
        if let observerQuery { store.stop(observerQuery) }
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { _, completion, _ in
            DispatchQueue.main.async { handler() }
            completion()
        }
        observerQuery = query
        store.execute(query)
    }

    /// Latest weight, height and sex recorded in Health, for prefilling the profile.
    func fetchBodyMetrics() async -> BodyMetrics {
        var metrics = BodyMetrics()
        guard isAvailable else { return metrics }
        metrics.weightLb = await latestQuantity(HKQuantityType(.bodyMass), unit: .pound())
        metrics.heightInches = await latestQuantity(HKQuantityType(.height), unit: .inch())
        if let sex = try? store.biologicalSex().biologicalSex {
            switch sex {
            case .male: metrics.gender = .male
            case .female: metrics.gender = .female
            case .other: metrics.gender = .other
            default: metrics.gender = nil
            }
        }
        return metrics
    }

    private func latestQuantity(_ type: HKQuantityType, unit: HKUnit) async -> Double? {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                let sample = samples?.first as? HKQuantitySample
                continuation.resume(returning: sample?.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    // MARK: - Writing

    /// Saves a finished walk to Apple Health as a walking workout with its route.
    func saveWorkout(_ walk: Walk) async throws {
        guard isAvailable else { throw HealthError.unavailable }
        guard canSaveWorkouts else { throw HealthError.notAuthorized }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .walking
        configuration.locationType = walk.hasRoute ? .outdoor : .indoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: HKDevice.local())
        try await builder.beginCollection(at: walk.start)

        var samples: [HKSample] = []
        if walk.distanceMeters > 0, store.authorizationStatus(for: distanceType) == .sharingAuthorized {
            let quantity = HKQuantity(unit: .meter(), doubleValue: walk.distanceMeters)
            samples.append(HKQuantitySample(type: distanceType, quantity: quantity, start: walk.start, end: walk.end))
        }
        if walk.calories > 0, store.authorizationStatus(for: energyType) == .sharingAuthorized {
            let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: walk.calories)
            samples.append(HKQuantitySample(type: energyType, quantity: quantity, start: walk.start, end: walk.end))
        }
        if !samples.isEmpty {
            try await builder.addSamples(samples)
        }

        // Pauses so Health shows the active duration rather than wall-clock time.
        var events: [HKWorkoutEvent] = []
        for pause in walk.pauses where pause.start >= walk.start && pause.end <= walk.end {
            events.append(HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil))
            if pause.end < walk.end {
                events.append(HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: pause.end, duration: 0), metadata: nil))
            }
        }
        if !events.isEmpty {
            try await builder.addWorkoutEvents(events)
        }
        try await builder.endCollection(at: walk.end)

        let finished: HKWorkout? = try await builder.finishWorkout()
        guard let workout = finished else { throw HealthError.saveFailed }

        if walk.hasRoute, store.authorizationStatus(for: HKSeriesType.workoutRoute()) == .sharingAuthorized {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: HKDevice.local())
            let locations = walk.route.map { $0.clLocation }
            try await routeBuilder.insertRouteData(locations)
            _ = try await routeBuilder.finishRoute(with: workout, metadata: nil)
        }
    }
}
