import SwiftUI

/// Soft, slowly drifting gradient blobs behind every screen.
struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var drift = false

    var body: some View {
        ZStack {
            baseGradient.ignoresSafeArea()

            Circle()
                .fill(Theme.teal.opacity(colorScheme == .dark ? 0.45 : 0.30))
                .frame(width: 360, height: 360)
                .blur(radius: 90)
                .offset(x: drift ? -120 : -40, y: drift ? -260 : -180)

            Circle()
                .fill(Theme.violet.opacity(colorScheme == .dark ? 0.40 : 0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 90)
                .offset(x: drift ? 150 : 90, y: drift ? 120 : 220)

            Circle()
                .fill(Theme.mint.opacity(colorScheme == .dark ? 0.28 : 0.20))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: drift ? -80 : 40, y: drift ? 380 : 320)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
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
