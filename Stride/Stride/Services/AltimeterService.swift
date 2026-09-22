import Foundation
import CoreMotion

/// Uses the iPhone's barometer to add up how much climbing a walk involved.
final class AltimeterService {
    private let altimeter = CMAltimeter()
    private var lastRelative: Double?
    private(set) var gainMeters: Double = 0

    var isAvailable: Bool { CMAltimeter.isRelativeAltitudeAvailable() }

    /// Called on the main thread with the running total in metres.
    func start(onUpdate: @escaping (Double) -> Void) {
        guard isAvailable else { return }
        stop()
        gainMeters = 0
        lastRelative = nil
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let relative = data.relativeAltitude.doubleValue
            if let last = self.lastRelative {
                let delta = relative - last
                // Ignore pressure noise; only count a real rise.
                if delta > 0.5 { self.gainMeters += delta }
                if abs(delta) > 0.5 { self.lastRelative = relative }
            } else {
                self.lastRelative = relative
            }
            onUpdate(self.gainMeters)
        }
    }

    func pause() {
        altimeter.stopRelativeAltitudeUpdates()
        lastRelative = nil
    }

    /// Resumes without clearing the total collected so far.
    func resume(onUpdate: @escaping (Double) -> Void) {
        guard isAvailable else { return }
        lastRelative = nil
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let relative = data.relativeAltitude.doubleValue
            if let last = self.lastRelative {
                let delta = relative - last
                if delta > 0.5 { self.gainMeters += delta }
                if abs(delta) > 0.5 { self.lastRelative = relative }
            } else {
                self.lastRelative = relative
            }
            onUpdate(self.gainMeters)
        }
    }

    func stop() {
        altimeter.stopRelativeAltitudeUpdates()
    }
}
