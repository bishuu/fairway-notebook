import Foundation
import CoreLocation
import MapKit

/// A recorded route with running distances, used to animate a replay.
struct RouteTrack {
    let points: [CLLocationCoordinate2D]
    let cumulative: [Double]
    let total: Double

    init(points: [RoutePoint]) {
        let coordinates = points.map { $0.coordinate }
        var distances: [Double] = []
        var running = 0.0
        var previous: CLLocation?
        for point in points {
            let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
            if let previous {
                running += location.distance(from: previous)
            }
            distances.append(running)
            previous = location
        }
        self.points = coordinates
        cumulative = distances
        total = running
    }

    var isEmpty: Bool { points.count < 2 }

    /// The position `fraction` (0...1) of the way along the route.
    func coordinate(at fraction: Double) -> CLLocationCoordinate2D? {
        guard !isEmpty else { return points.first }
        let target = min(max(fraction, 0), 1) * total
        guard total > 0 else { return points.first }
        var index = 1
        while index < cumulative.count - 1, cumulative[index] < target { index += 1 }
        let segmentStart = cumulative[index - 1]
        let segmentEnd = cumulative[index]
        let span = segmentEnd - segmentStart
        let t = span > 0 ? (target - segmentStart) / span : 1
        let a = points[index - 1]
        let b = points[index]
        return CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                      longitude: a.longitude + (b.longitude - a.longitude) * t)
    }

    /// The part of the route already walked at `fraction`, for the growing trail.
    func trail(to fraction: Double) -> [CLLocationCoordinate2D] {
        guard !isEmpty else { return points }
        let target = min(max(fraction, 0), 1) * total
        var result: [CLLocationCoordinate2D] = [points[0]]
        var index = 1
        while index < cumulative.count, cumulative[index] <= target {
            result.append(points[index])
            index += 1
        }
        if let head = coordinate(at: fraction) {
            result.append(head)
        }
        return result
    }

    /// A map region that fits the whole route with a little breathing room.
    var region: MKCoordinateRegion? {
        guard let first = points.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude
        var minLon = first.longitude, maxLon = first.longitude
        for point in points {
            minLat = min(minLat, point.latitude); maxLat = max(maxLat, point.latitude)
            minLon = min(minLon, point.longitude); maxLon = max(maxLon, point.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.5, 0.004),
                                    longitudeDelta: max((maxLon - minLon) * 1.5, 0.004))
        return MKCoordinateRegion(center: center, span: span)
    }
}
