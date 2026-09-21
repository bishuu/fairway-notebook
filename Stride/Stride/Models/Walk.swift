import Foundation
import CoreLocation

/// One GPS fix recorded during a walk.
struct RoutePoint: Codable, Hashable {
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var horizontalAccuracy: Double
    /// Walks can be paused; each resume starts a new segment so the map
    /// does not draw a line across the gap.
    var segment: Int

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    init(location: CLLocation, segment: Int) {
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        timestamp = location.timestamp
        horizontalAccuracy = max(location.horizontalAccuracy, 1)
        self.segment = segment
    }

    var clLocation: CLLocation {
        CLLocation(coordinate: coordinate,
                   altitude: 0,
                   horizontalAccuracy: horizontalAccuracy,
                   verticalAccuracy: -1,
                   timestamp: timestamp)
    }
}

/// A finished, saved walk.
struct Walk: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var start: Date
    var end: Date
    /// Time spent walking, excluding pauses.
    var activeSeconds: TimeInterval
    var steps: Int
    var distanceMeters: Double
    var calories: Double
    var route: [RoutePoint]
    var savedToHealth: Bool = false

    var averageSpeedMetersPerSecond: Double {
        activeSeconds > 0 ? distanceMeters / activeSeconds : 0
    }

    /// Seconds per mile, or nil when there is not enough data.
    var paceSecondsPerMile: Double? {
        guard distanceMeters > 50, activeSeconds > 0 else { return nil }
        return activeSeconds / (distanceMeters / 1609.344)
    }

    var hasRoute: Bool { route.count > 1 }

    /// Route split into the separately drawn segments (one per resume).
    var routeSegments: [[CLLocationCoordinate2D]] {
        var segments: [[CLLocationCoordinate2D]] = []
        var current: [CLLocationCoordinate2D] = []
        var currentIndex = route.first?.segment ?? 0
        for point in route {
            if point.segment != currentIndex {
                if current.count > 1 { segments.append(current) }
                current = []
                currentIndex = point.segment
            }
            current.append(point.coordinate)
        }
        if current.count > 1 { segments.append(current) }
        return segments
    }
}

/// Steps taken on one calendar day (used for the history chart).
struct DailySteps: Identifiable, Hashable {
    var date: Date
    var steps: Int
    var id: Date { date }
}
