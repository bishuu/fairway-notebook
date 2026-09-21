import SwiftUI

/// The live "you are here" marker on the walk map: a walker with pulsing rings.
@MainActor
struct PulsingMarker: View {
    var color: Color = Theme.sky
    var isMoving: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
            ZStack {
                ring(phase: phase)
                ring(phase: (phase + 0.5).truncatingRemainder(dividingBy: 1))

                Circle()
                    .fill(color.opacity(0.25))
                    .frame(width: 44, height: 44)

                Circle()
                    .fill(color)
                    .frame(width: 30, height: 30)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .shadow(color: color.opacity(0.6), radius: 6)

                Image(systemName: isMoving ? "figure.walk" : "figure.stand")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 90, height: 90)
        }
    }

    private func ring(phase: Double) -> some View {
        Circle()
            .stroke(color.opacity(0.7 * (1 - phase)), lineWidth: 2)
            .frame(width: 30 + 60 * phase, height: 30 + 60 * phase)
    }
}

/// A small flag marking where a walk began.
@MainActor
struct StartPin: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 18, height: 18)
                .shadow(radius: 3)
            Circle()
                .fill(Theme.mint)
                .frame(width: 10, height: 10)
        }
    }
}

/// A small chequered-style marker for the end of a walk.
@MainActor
struct EndPin: View {
    var body: some View {
        Image(systemName: "flag.checkered.circle.fill")
            .font(.system(size: 26))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, Theme.rose)
            .shadow(radius: 3)
    }
}
