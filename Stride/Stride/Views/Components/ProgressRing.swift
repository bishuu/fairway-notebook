import SwiftUI

/// The big animated step ring on the Today screen.
struct ProgressRing: View {
    var progress: Double          // 0...1
    var lineWidth: CGFloat = 24
    var goalReached: Bool = false

    @State private var glow = false

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let radius = max((side - lineWidth) / 2, 0)
            let clamped = min(max(progress, 0), 1)

            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: lineWidth)

                Circle()
                    .trim(from: 0, to: max(clamped, 0.003))
                    .stroke(Theme.ringGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: Theme.mint.opacity(goalReached ? 0.8 : 0.35), radius: goalReached ? 18 : 8)
                    .animation(.spring(response: 1.1, dampingFraction: 0.8), value: clamped)

                // Bright cap at the leading edge of the ring.
                Circle()
                    .fill(.white)
                    .frame(width: lineWidth * 0.55, height: lineWidth * 0.55)
                    .shadow(color: Theme.mint, radius: 6)
                    .offset(y: -radius)
                    .rotationEffect(.degrees(360 * clamped))
                    .opacity(clamped > 0.02 ? 1 : 0)
                    .animation(.spring(response: 1.1, dampingFraction: 0.8), value: clamped)

                if goalReached {
                    Circle()
                        .stroke(Theme.mint.opacity(glow ? 0 : 0.6), lineWidth: 2)
                        .scaleEffect(glow ? 1.25 : 1.0)
                        .animation(.easeOut(duration: 1.6).repeatForever(autoreverses: false), value: glow)
                        .onAppear { glow = true }
                }
            }
            .padding(lineWidth / 2)
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
