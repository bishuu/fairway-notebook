import SwiftUI

/// The app's colours and shared styles.
enum Theme {
    static let mint = Color(red: 0.24, green: 0.88, blue: 0.64)
    static let teal = Color(red: 0.10, green: 0.66, blue: 0.78)
    static let sky = Color(red: 0.25, green: 0.56, blue: 0.98)
    static let violet = Color(red: 0.58, green: 0.42, blue: 0.98)
    static let flame = Color(red: 1.00, green: 0.55, blue: 0.25)
    static let rose = Color(red: 0.98, green: 0.35, blue: 0.50)
    static let gold = Color(red: 1.00, green: 0.80, blue: 0.30)

    static let stepsGradient = LinearGradient(colors: [mint, teal, sky],
                                              startPoint: .topLeading, endPoint: .bottomTrailing)
    static let ringGradient = AngularGradient(colors: [teal, mint, sky, violet, teal],
                                              center: .center, startAngle: .degrees(0), endAngle: .degrees(360))
    static let flameGradient = LinearGradient(colors: [gold, flame, rose],
                                              startPoint: .top, endPoint: .bottom)
    static let buttonGradient = LinearGradient(colors: [mint, teal],
                                               startPoint: .leading, endPoint: .trailing)
    static let routeColor = sky
    static let routeGlow = mint

    /// Slow to fast, for colouring a route by pace. A perceptually even ramp,
    /// so a step in colour means the same change in speed anywhere on the line.
    static let paceRamp: [Color] = [
        Color(red: 0.36, green: 0.27, blue: 0.71),
        Color(red: 0.20, green: 0.49, blue: 0.87),
        Color(red: 0.09, green: 0.69, blue: 0.79),
        Color(red: 0.24, green: 0.86, blue: 0.60),
        Color(red: 0.74, green: 0.94, blue: 0.39)
    ]

    static func paceColor(band: Int) -> Color {
        paceRamp[min(max(band, 0), paceRamp.count - 1)]
    }

    static let cardRadius: CGFloat = 24
}

/// A frosted card used across the app.
@MainActor
struct GlassCard<Content: View>: View {
    var padding: CGFloat
    private let content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
    }
}

/// Scale-on-press style for the big buttons.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
