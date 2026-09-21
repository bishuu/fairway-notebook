import Foundation
import CoreLocation

/// Wraps CoreLocation for live walk tracking, including while the phone is
/// locked (the app declares the "location" background mode in Info.plist).
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    /// Called on the main thread with each new GPS fix.
    var onLocation: ((CLLocation) -> Void)?
    /// Called on the main thread when permission changes.
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    private(set) var authorization: CLAuthorizationStatus = .notDetermined
    private(set) var isTracking = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
        manager.distanceFilter = 2
        manager.pausesLocationUpdatesAutomatically = false
        authorization = manager.authorizationStatus
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    func requestPermission() {
        if authorization == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    func startTracking() {
        requestPermission()
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
        manager.startUpdatingLocation()
        isTracking = true
    }

    func stopTracking() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
        isTracking = false
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            DispatchQueue.main.async { [weak self] in
                self?.onLocation?(location)
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Ignored: a failed fix simply produces no point.
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        authorization = status
        DispatchQueue.main.async { [weak self] in
            self?.onAuthorizationChange?(status)
        }
    }
}
