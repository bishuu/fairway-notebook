import SwiftUI

/// Soft gradient glow behind every screen. Drawn with plain gradients (no
/// blur filters or continuous animation) so scrolling over it stays smooth.
@MainActor
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            baseGradient

            RadialGradient(colors: [Theme.teal.opacity(colorScheme == .dark ? 0.42 : 0.28), .clear],
                           center: UnitPoint(x: 0.12, y: 0.08), startRadius: 0, endRadius: 330)
            RadialGradient(colors: [Theme.violet.opacity(colorScheme == .dark ? 0.36 : 0.20), .clear],
                           center: UnitPoint(x: 0.92, y: 0.42), startRadius: 0, endRadius: 300)
            RadialGradient(colors: [Theme.mint.opacity(colorScheme == .dark ? 0.26 : 0.18), .clear],
                           center: UnitPoint(x: 0.28, y: 0.95), startRadius: 0, endRadius: 280)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var baseGradient: LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(colors: [Color(red: 0.05, green: 0.07, blue: 0.14),
                                           Color(red: 0.03, green: 0.05, blue: 0.10)],
                                  startPoint: .top, endPoint: .bottom)
        }
        return LinearGradient(colors: [Color(red: 0.94, green: 0.97, blue: 1.0),
                                       Color(red: 0.90, green: 0.95, blue: 0.97)],
                              startPoint: .top, endPoint: .bottom)
    }
}
