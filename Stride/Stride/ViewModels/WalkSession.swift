import Foundation
import Combine
import CoreLocation
import WidgetKit

/// Runs one walk workout: timer, live steps, GPS route, distance, calories,
/// climbing, heart rate, and the Live Activity on the Lock Screen.
@MainActor
final class WalkSession: ObservableObject {
    enum State: Equatable {
        case idle, active, paused, finished
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var steps: Int = 0
    @Published private(set) var distanceMeters: Double = 0
    @Published private(set) var calories: Double = 0
    @Published private(set) var elevationGainMeters: Double = 0
    @Published private(set) var heartRate: Double?
    @Published private(set) var route: [RoutePoint] = []
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var currentPaceSecondsPerMeter: Double?
    @Published private(set) var locationDenied = false
    @Published private(set) var gpsAccuracy: Double?
    @Published private(set) var startDate: Date?
    @Published private(set) var lastSavedWalk: Walk?
    @Published var healthSaveError: String?

    let location: LocationService
    private let pedometer: PedometerService
    private let health: HealthKitService
    private let profile: UserProfile
    private let store: WalkStore
    private let altimeter = AltimeterService()
    private let liveActivity = LiveActivityController()

    private var segmentStart: Date?
    private var accumulatedElapsed: TimeInterval = 0
    private var segmentIndex = 0
    private var stepsBeforeSegment = 0
    private var pedometerDistanceBeforeSegment: Double = 0
    private var segmentPedometerDistance: Double = 0
    private var gpsDistance: Double = 0
    private var lastAcceptedLocation: CLLocation?
    private var ticker: AnyCancellable?
    private var endDate: Date?
    private var pauseStartedAt: Date?
    private var pauses: [DateInterval] = []
    private var lastActivityPush = Date.distantPast

    init(location: LocationService, pedometer: PedometerService, health: HealthKitService,
         profile: UserProfile, store: WalkStore) {
        self.location = location
        self.pedometer = pedometer
        self.health = health
        self.profile = profile
        self.store = store

        location.onLocation = { [weak self] fix in
            self?.handle(fix)
        }
        location.onAuthorizationChange = { [weak self] status in
            self?.locationDenied = (status == .denied || status == .restricted)
        }
        locationDenied = location.isDenied
    }

    var isRunning: Bool { state == .active || state == .paused }

    var routeCoordinates: [CLLocationCoordinate2D] { route.map { $0.coordinate } }

    var routeSegments: [[CLLocationCoordinate2D]] {
        var segments: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = []
        var index = route.first?.segment ?? 0
        for point in route {
            if point.segment != index {
                if current.count > 1 { segments.append(current) }
                current = []
                index = point.segment
            }
            current.append(point.coordinate)
        }
        if current.count > 1 { segments.append(current) }
        return segments
    }

    var averagePaceSecondsPerMeter: Double? {
        guard distanceMeters > 30, elapsed > 0 else { return nil }
        return elapsed / distanceMeters
    }

    // MARK: - Controls

    func start() {
        guard state == .idle || state == .finished else { return }
        resetCounters()
        let now = Date()
        startDate = now
        segmentStart = now
        state = .active
        healthSaveError = nil
        lastSavedWalk = nil
        beginSegment(at: now)
        altimeter.start { [weak self] gain in
            self?.elevationGainMeters = gain
        }
        health.startHeartRateUpdates(from: now) { [weak self] bpm in
            self?.heartRate = bpm
        }
        liveActivity.start(startedAt: now)
        ticker = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }

    func pause() {
        guard state == .active, let segmentStart else { return }
        accumulatedElapsed += Date().timeIntervalSince(segmentStart)
        self.segmentStart = nil
        stepsBeforeSegment = steps
        pedometerDistanceBeforeSegment += segmentPedometerDistance
        segmentPedometerDistance = 0
        pedometer.stopLiveUpdates()
        location.stopTracking()
        altimeter.pause()
        pauseStartedAt = Date()
        state = .paused
        tick()
        pushActivity(force: true)
    }

    func resume() {
        guard state == .paused else { return }
        let now = Date()
        if let pauseStartedAt {
            pauses.append(DateInterval(start: pauseStartedAt, end: now))
        }
        pauseStartedAt = nil
        segmentStart = now
        segmentIndex += 1
        lastAcceptedLocation = nil
        state = .active
        beginSegment(at: now)
        altimeter.resume { [weak self] gain in
            self?.elevationGainMeters = gain
        }
        pushActivity(force: true)
    }

    /// Stops the sensors and freezes the numbers so they can be reviewed.
    func finish() {
        guard state == .active || state == .paused else { return }
        if state == .active, let segmentStart {
            accumulatedElapsed += Date().timeIntervalSince(segmentStart)
        }
        segmentStart = nil
        let end = Date()
        endDate = end
        if let pauseStartedAt, pauseStartedAt < end {
            pauses.append(DateInterval(start: pauseStartedAt, end: end))
        }
        pauseStartedAt = nil
        pedometer.stopLiveUpdates()
        location.stopTracking()
        altimeter.stop()
        health.stopHeartRateUpdates()
        ticker = nil
        state = .finished
        tick()
        liveActivity.end(steps: steps, distanceMeters: distanceMeters,
                         calories: calories, elapsed: elapsed)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// Saves the finished walk to history and to Apple Health.
    func save() {
        guard state == .finished, let startDate else { return }
        let end = endDate ?? Date()
        let walk = Walk(start: startDate,
                        end: end,
                        activeSeconds: accumulatedElapsed,
                        steps: steps,
                        distanceMeters: distanceMeters,
                        calories: calories,
                        route: route,
                        pauses: pauses,
                        elevationGainMeters: elevationGainMeters)
        store.add(walk)
        lastSavedWalk = walk
        state = .idle
        attachHeartRate(to: walk, start: startDate, end: end)
        saveToHealth(walk)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func discard() {
        guard state == .finished else { return }
        state = .idle
        resetCounters()
    }

    /// Fills in average and peak heart rate once Health has the samples.
    private func attachHeartRate(to walk: Walk, start: Date, end: Date) {
        guard health.isAvailable, health.hasRequestedAccess else { return }
        Task {
            guard let summary = await health.heartRateSummary(from: start, to: end) else { return }
            guard var stored = store.walk(with: walk.id) else { return }
            stored.averageHeartRate = summary.average
            stored.maxHeartRate = summary.max
            store.update(stored)
            if lastSavedWalk?.id == stored.id { lastSavedWalk = stored }
        }
    }

    private func saveToHealth(_ walk: Walk) {
        guard health.isAvailable, health.hasRequestedAccess else { return }
        Task {
            do {
                try await health.saveWorkout(walk)
                guard var stored = store.walk(with: walk.id) else { return }
                stored.savedToHealth = true
                store.update(stored)
                if lastSavedWalk?.id == stored.id { lastSavedWalk = stored }
            } catch {
                healthSaveError = error.localizedDescription
            }
        }
    }

    // MARK: - Internals

    private func resetCounters() {
        elapsed = 0
        steps = 0
        distanceMeters = 0
        calories = 0
        elevationGainMeters = 0
        heartRate = nil
        route = []
        currentPaceSecondsPerMeter = nil
        gpsAccuracy = nil
        accumulatedElapsed = 0
        segmentIndex = 0
        stepsBeforeSegment = 0
        pedometerDistanceBeforeSegment = 0
        segmentPedometerDistance = 0
        gpsDistance = 0
        lastAcceptedLocation = nil
        endDate = nil
        pauseStartedAt = nil
        pauses = []
    }

    private func beginSegment(at date: Date) {
        location.startTracking()
        pedometer.startLiveUpdates(from: date) { [weak self] reading in
            guard let self, self.state == .active else { return }
            self.steps = self.stepsBeforeSegment + reading.steps
            self.segmentPedometerDistance = reading.distanceMeters ?? self.segmentPedometerDistance
            if let pace = reading.paceSecondsPerMeter, pace > 0 {
                self.currentPaceSecondsPerMeter = pace
            }
            self.recomputeDerived()
        }
    }

    private func tick() {
        var total = accumulatedElapsed
        if let segmentStart, state == .active {
            total += Date().timeIntervalSince(segmentStart)
        }
        elapsed = total
        recomputeDerived()
        pushActivity(force: false)
    }

    /// The Live Activity is refreshed a couple of times a minute; the timer on
    /// the card runs on its own in between.
    private func pushActivity(force: Bool) {
        guard isRunning else { return }
        let now = Date()
        guard force || now.timeIntervalSince(lastActivityPush) >= 20 else { return }
        lastActivityPush = now
        liveActivity.update(steps: steps, distanceMeters: distanceMeters,
                            calories: calories, elapsed: elapsed,
                            isPaused: state == .paused)
    }

    private func handle(_ fix: CLLocation) {
        currentLocation = fix
        gpsAccuracy = fix.horizontalAccuracy
        guard state == .active, let segmentStart, fix.timestamp >= segmentStart else { return }
        guard fix.horizontalAccuracy > 0, fix.horizontalAccuracy <= 40 else { return }

        if let last = lastAcceptedLocation {
            let delta = fix.distance(from: last)
            let seconds = fix.timestamp.timeIntervalSince(last.timestamp)
            // Ignore GPS jitter and impossible jumps.
            guard delta >= 2.5 else { return }
            if seconds > 0, delta / seconds > 7 { return }
            gpsDistance += delta
        }
        lastAcceptedLocation = fix
        route.append(RoutePoint(location: fix, segment: segmentIndex))
        recomputeDerived()
    }

    private func recomputeDerived() {
        let pedometerTotal = pedometerDistanceBeforeSegment + segmentPedometerDistance
        // Prefer GPS outdoors; fall back to the motion chip's estimate indoors.
        if route.count >= 3, gpsDistance > 20 {
            distanceMeters = gpsDistance
        } else if pedometerTotal > 0 || gpsDistance > 0 {
            distanceMeters = max(pedometerTotal, gpsDistance)
        } else {
            // No GPS and no motion-chip distance yet: estimate from stride length.
            distanceMeters = CalorieEstimator.distanceFromSteps(steps, body: profile.body)
        }
        calories = CalorieEstimator.walkingCalories(distanceMeters: distanceMeters,
                                                    seconds: elapsed,
                                                    body: profile.body)
    }
}
