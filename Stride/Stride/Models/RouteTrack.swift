import Foundation
import CoreLocation
import MapKit
import SwiftUI

/// A recorded route prepared for playback: running distances, timings, speeds
/// and headings, so the replay can fly a camera along it and colour the line
/// by how fast the walk was at each point.
struct RouteTrack {
    struct Sample {
        var coordinate: CLLocationCoordinate2D
        var distance: Double        // metres from the start
        var elapsed: TimeInterval   // seconds from the start
        var speed: Double           // metres per second into this point
        var heading: Double         // degrees, direction of travel
    }

    private(set) var samples: [Sample] = []
    private(set) var total: Double = 0
    private(set) var duration: TimeInterval = 0
    private(set) var medianSpeed: Double = 0
    private(set) var minSpeed: Double = 0
    private(set) var maxSpeed: Double = 0

    var points: [CLLocationCoordinate2D] { samples.map { $0.coordinate } }
    var isEmpty: Bool { samples.count < 2 }

    init(points routePoints: [RoutePoint]) {
        guard routePoints.count > 1 else {
            if let single = routePoints.first {
                samples = [Sample(coordinate: single.coordinate, distance: 0, elapsed: 0, speed: 0, heading: 0)]
            }
            return
        }

        let startTime = routePoints[0].timestamp
        var running = 0.0
        var previous: CLLocation?
        var built: [Sample] = []

        for point in routePoints {
            let location = CLLocation(latitude: point.latitude, longitude: point.longitude)
            var speed = 0.0
            if let previous {
                let step = location.distance(from: previous)
                let seconds = point.timestamp.timeIntervalSince(previous.timestamp)
                running += step
                if seconds > 0.1 { speed = step / seconds }
            }
            built.append(Sample(coordinate: point.coordinate,
                                distance: running,
                                elapsed: point.timestamp.timeIntervalSince(startTime),
                                speed: speed,
                                heading: 0))
            previous = CLLocation(coordinate: point.coordinate, altitude: 0,
                                  horizontalAccuracy: 1, verticalAccuracy: -1,
                                  timestamp: point.timestamp)
        }

        // Smooth the speeds so the colours do not flicker point to point.
        let raw = built.map { $0.speed }
        for index in built.indices {
            let lower = max(index - 2, 0)
            let upper = min(index + 2, raw.count - 1)
            let window = raw[lower...upper].filter { $0 > 0 }
            built[index].speed = window.isEmpty ? 0 : window.reduce(0, +) / Double(window.count)
            let next = min(index + 1, built.count - 1)
            built[index].heading = RouteTrack.bearing(from: built[index].coordinate,
                                                      to: built[next].coordinate)
        }
        if built.count > 1 {
            built[built.count - 1].heading = built[built.count - 2].heading
        }

        samples = built
        total = running
        duration = built.last?.elapsed ?? 0

        let moving = built.map { $0.speed }.filter { $0 > 0.2 }.sorted()
        if !moving.isEmpty {
            medianSpeed = moving[moving.count / 2]
            minSpeed = moving[max(Int(Double(moving.count) * 0.1) - 1, 0)]
            maxSpeed = moving[min(Int(Double(moving.count) * 0.9), moving.count - 1)]
        }
    }

    // MARK: - Lookups

    private func index(forFraction fraction: Double) -> (Int, Double) {
        guard samples.count > 1, total > 0 else { return (0, 0) }
        let target = min(max(fraction, 0), 1) * total
        var index = 1
        while index < samples.count - 1, samples[index].distance < target { index += 1 }
        let lower = samples[index - 1].distance
        let upper = samples[index].distance
        let span = upper - lower
        let t = span > 0 ? (target - lower) / span : 1
        return (index, min(max(t, 0), 1))
    }

    /// The position `fraction` (0...1) of the way along the route.
    func coordinate(at fraction: Double) -> CLLocationCoordinate2D? {
        guard let first = samples.first else { return nil }
        guard samples.count > 1 else { return first.coordinate }
        let (index, t) = self.index(forFraction: fraction)
        let a = samples[index - 1].coordinate
        let b = samples[index].coordinate
        return CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                      longitude: a.longitude + (b.longitude - a.longitude) * t)
    }

    /// Direction of travel at `fraction`, in degrees, for the follow camera.
    func heading(at fraction: Double) -> Double {
        guard samples.count > 1 else { return 0 }
        let (index, _) = self.index(forFraction: fraction)
        return samples[index].heading
    }

    func distance(at fraction: Double) -> Double {
        total * min(max(fraction, 0), 1)
    }

    func elapsed(at fraction: Double) -> TimeInterval {
        guard samples.count > 1 else { return 0 }
        let (index, t) = self.index(forFraction: fraction)
        let a = samples[index - 1].elapsed
        let b = samples[index].elapsed
        return a + (b - a) * t
    }

    func speed(at fraction: Double) -> Double {
        guard samples.count > 1 else { return 0 }
        let (index, _) = self.index(forFraction: fraction)
        return samples[index].speed
    }

    /// The part of the route already walked at `fraction`, for the growing trail.
    func trail(to fraction: Double) -> [CLLocationCoordinate2D] {
        guard samples.count > 1 else { return points }
        let target = distance(at: fraction)
        var result: [CLLocationCoordinate2D] = [samples[0].coordinate]
        var index = 1
        while index < samples.count, samples[index].distance <= target {
            result.append(samples[index].coordinate)
            index += 1
        }
        if let head = coordinate(at: fraction) { result.append(head) }
        return result
    }

    /// The last `metres` of the walked trail, drawn as a bright comet tail.
    func tail(endingAt fraction: Double, metres: Double) -> [CLLocationCoordinate2D] {
        guard samples.count > 1 else { return [] }
        let head = distance(at: fraction)
        let from = max(head - metres, 0)
        guard head > from else { return [] }
        var result: [CLLocationCoordinate2D] = []
        if total > 0, let startPoint = coordinate(at: from / total) { result.append(startPoint) }
        for sample in samples where sample.distance > from && sample.distance < head {
            result.append(sample.coordinate)
        }
        if let headPoint = coordinate(at: fraction) { result.append(headPoint) }
        return result.count > 1 ? result : []
    }

    /// A stretch of the route walked at a similar speed, used to colour the line.
    struct PaceRun: Identifiable {
        var id: Int
        var coordinates: [CLLocationCoordinate2D]
        var distances: [Double]
        var band: Int
    }

    /// The route split into stretches by pace. Short stretches are folded into
    /// their neighbour so the map draws a handful of lines, not hundreds.
    func paceRuns(bands: Int = 5, minimumLength: Double = 30) -> [PaceRun] {
        guard samples.count > 1 else { return [] }

        var runs: [(coords: [CLLocationCoordinate2D], dists: [Double], band: Int)] = []
        var coords: [CLLocationCoordinate2D] = [samples[0].coordinate]
        var dists: [Double] = [samples[0].distance]
        var currentBand = band(for: samples[1].speed, bands: bands)

        for index in 1..<samples.count {
            let sampleBand = band(for: samples[index].speed, bands: bands)
            coords.append(samples[index].coordinate)
            dists.append(samples[index].distance)
            let runLength = (dists.last ?? 0) - (dists.first ?? 0)
            if sampleBand != currentBand, runLength >= minimumLength, index < samples.count - 1 {
                runs.append((coords, dists, currentBand))
                coords = [samples[index].coordinate]
                dists = [samples[index].distance]
                currentBand = sampleBand
            }
        }
        if coords.count > 1 { runs.append((coords, dists, currentBand)) }

        return runs.enumerated().map { PaceRun(id: $0.offset, coordinates: $0.element.coords,
                                               distances: $0.element.dists, band: $0.element.band) }
    }

    /// The part of one pace run that has been walked by `headDistance` metres in.
    func clip(_ run: PaceRun, toDistance headDistance: Double) -> [CLLocationCoordinate2D] {
        guard let first = run.distances.first, first <= headDistance else { return [] }
        var result: [CLLocationCoordinate2D] = []
        for (index, distance) in run.distances.enumerated() {
            if distance <= headDistance {
                result.append(run.coordinates[index])
                continue
            }
            if index > 0 {
                let previous = run.distances[index - 1]
                let span = distance - previous
                let t = span > 0 ? (headDistance - previous) / span : 0
                let a = run.coordinates[index - 1]
                let b = run.coordinates[index]
                result.append(CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                                     longitude: a.longitude + (b.longitude - a.longitude) * t))
            }
            break
        }
        return result.count > 1 ? result : []
    }

    /// 0 is the slowest band, `bands - 1` the fastest.
    func band(for speed: Double, bands: Int) -> Int {
        guard maxSpeed > minSpeed, speed > 0 else { return bands / 2 }
        let t = (speed - minSpeed) / (maxSpeed - minSpeed)
        return min(max(Int(t * Double(bands)), 0), bands - 1)
    }

    /// A map region that fits the whole route with a little breathing room.
    var region: MKCoordinateRegion? {
        guard let first = samples.first else { return nil }
        var minLat = first.coordinate.latitude, maxLat = first.coordinate.latitude
        var minLon = first.coordinate.longitude, maxLon = first.coordinate.longitude
        for sample in samples {
            minLat = min(minLat, sample.coordinate.latitude)
            maxLat = max(maxLat, sample.coordinate.latitude)
            minLon = min(minLon, sample.coordinate.longitude)
            maxLon = max(maxLon, sample.coordinate.longitude)
        }
        let center = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2)
        let span = MKCoordinateSpan(latitudeDelta: max((maxLat - minLat) * 1.45, 0.003),
                                    longitudeDelta: max((maxLon - minLon) * 1.45, 0.003))
        return MKCoordinateRegion(center: center, span: span)
    }

    private static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let deltaLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let degrees = atan2(y, x) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }
}
