import SwiftUI

/// A short shower of confetti, shown when the daily goal is reached.
@MainActor
struct ConfettiBurst: View {
    var trigger: Int

    private struct Piece {
        var x: Double
        var delay: Double
        var speed: Double
        var drift: Double
        var size: Double
        var spin: Double
        var color: Color
    }

    @State private var pieces: [Piece] = []
    @State private var startedAt: Date?

    private let colors: [Color] = [Theme.mint, Theme.sky, Theme.violet, Theme.gold, Theme.rose, .white]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 40, paused: startedAt == nil)) { context in
            Canvas { graphics, size in
                guard let startedAt else { return }
                let elapsed = context.date.timeIntervalSince(startedAt)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0, t < 3.2 else { continue }
                    let y = -20 + t * t * 120 * piece.speed + t * 60
                    let x = piece.x * size.width + sin(t * 3 + piece.spin) * 30 * piece.drift
                    let alpha = t > 2.4 ? max(0, 1 - (t - 2.4) / 0.8) : 1
                    var rect = CGRect(x: x, y: y, width: piece.size, height: piece.size * 0.55)
                    rect = rect.offsetBy(dx: -piece.size / 2, dy: -piece.size / 2)
                    var transform = CGAffineTransform(translationX: rect.midX, y: rect.midY)
                    transform = transform.rotated(by: t * 4 * piece.spin)
                    transform = transform.translatedBy(x: -rect.midX, y: -rect.midY)
                    let path = Path(roundedRect: rect, cornerRadius: 1.5).applying(transform)
                    graphics.fill(path, with: .color(piece.color.opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            fire()
        }
    }

    private func fire() {
        var generated: [Piece] = []
        for index in 0..<90 {
            generated.append(Piece(x: Double.random(in: 0...1),
                                   delay: Double.random(in: 0...0.6),
                                   speed: Double.random(in: 0.6...1.4),
                                   drift: Double.random(in: 0.4...1.2),
                                   size: Double.random(in: 6...12),
                                   spin: Double.random(in: -2...2),
                                   color: colors[index % colors.count]))
        }
        pieces = generated
        startedAt = Date()
        Task {
            try? await Task.sleep(for: .seconds(4.5))
            if let startedAt, Date().timeIntervalSince(startedAt) > 4 {
                self.startedAt = nil
            }
        }
    }
}
