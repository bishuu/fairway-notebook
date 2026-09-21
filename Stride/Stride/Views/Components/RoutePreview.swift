import SwiftUI
import CoreLocation

/// Draws a walk's route as a tiny line drawing (no map tiles needed),
/// used for thumbnails in the history list.
@MainActor
struct RoutePreview: View {
    var segments: [[CLLocationCoordinate2D]]
    var lineWidth: CGFloat = 3
    /// Fraction of the route to draw, for the replay animation.
    var visibleFraction: Double = 1

    var body: some View {
        Canvas { context, size in
            let all = segments.flatMap { $0 }
            guard all.count > 1,
                  let minLat = all.map({ $0.latitude }).min(),
                  let maxLat = all.map({ $0.latitude }).max(),
                  let minLon = all.map({ $0.longitude }).min(),
                  let maxLon = all.map({ $0.longitude }).max() else {
                return
            }
            let midLat = (minLat + maxLat) / 2
            let cosLat = cos(midLat * .pi / 180)
            let width = max((maxLon - minLon) * cosLat, 0.00001)
            let height = max(maxLat - minLat, 0.00001)
            let inset: CGFloat = lineWidth * 2
            let scale = min((size.width - inset * 2) / width, (size.height - inset * 2) / height)
            let drawnWidth = width * scale
            let drawnHeight = height * scale
            let originX = (size.width - drawnWidth) / 2
            let originY = (size.height - drawnHeight) / 2

            func point(_ coordinate: CLLocationCoordinate2D) -> CGPoint {
                CGPoint(x: originX + (coordinate.longitude - minLon) * cosLat * scale,
                        y: originY + (maxLat - coordinate.latitude) * scale)
            }

            var path = Path()
            for segment in segments {
                let count = max(Int(Double(segment.count) * visibleFraction), 2)
                let visible = segment.prefix(count)
                guard let first = visible.first else { continue }
                path.move(to: point(first))
                for coordinate in visible.dropFirst() {
                    path.addLine(to: point(coordinate))
                }
            }
            context.stroke(path, with: .color(Theme.routeGlow.opacity(0.35)),
                           style: StrokeStyle(lineWidth: lineWidth * 2.2, lineCap: .round, lineJoin: .round))
            context.stroke(path, with: .linearGradient(Gradient(colors: [Theme.mint, Theme.sky]),
                                                       startPoint: .zero,
                                                       endPoint: CGPoint(x: size.width, y: size.height)),
                           style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))

            if let start = segments.first?.first {
                let p = point(start)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 3, y: p.y - 3, width: 6, height: 6)), with: .color(.white))
            }
        }
    }
}
