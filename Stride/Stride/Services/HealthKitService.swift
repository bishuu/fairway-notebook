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
    private var observerQuery: HKObserverQuery?

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
