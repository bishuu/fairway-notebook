import SwiftUI

/// The picture a walk turns into when it is shared: route drawing, headline
/// numbers and the date, sized for a phone screenshot or a story post.
@MainActor
struct ShareCardView: View {
    var walk: Walk

    var body: some View {
        VStack(spacing: 0) {
            header
            routePanel
            stats
            footer
        }
        .frame(width: 400, height: 640)
        .background(
            LinearGradient(colors: [Color(red: 0.05, green: 0.09, blue: 0.19),
                                    Color(red: 0.03, green: 0.15, blue: 0.22),
                                    Color(red: 0.04, green: 0.07, blue: 0.14)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Format.walkTitle(walk.start))
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text(walk.start.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.stepsGradient)
        }
        .padding(.horizontal, 26)
        .padding(.top, 28)
        .padding(.bottom, 16)
    }

    private var routePanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.white.opacity(0.06))
            if walk.hasRoute {
                RoutePreview(segments: walk.routeSegments, lineWidth: 5)
                    .padding(22)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "figure.walk.motion")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.mint)
                    Text("\(Format.steps(walk.steps)) steps")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .frame(height: 280)
        .padding(.horizontal, 22)
    }

    private var stats: some View {
        HStack(spacing: 0) {
            cardStat(Format.distanceValue(walk.distanceMeters), Format.units.distanceSuffix, "Distance")
            divider
            cardStat(Format.shortDuration(walk.activeSeconds), nil, "Time")
            divider
            cardStat(Format.steps(walk.steps), nil, "Steps")
            divider
            cardStat(Format.calories(walk.calories), "kcal", "Burned")
        }
        .padding(.horizontal, 18)
        .padding(.top, 26)
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.12)).frame(width: 1, height: 34)
    }

    private func cardStat(_ value: String, _ unit: String?, _ label: String) -> some View {
        VStack(spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                if let unit {
                    Text(unit)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.55))
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white.opacity(0.5))
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 7) {
            Spacer()
            Image(systemName: "figure.walk")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.mint)
            Text("Stride")
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
            Spacer()
        }
        .padding(.top, 22)
        .padding(.bottom, 26)
    }
}

enum ShareCardRenderer {
    /// Draws the card into an image ready to hand to the share sheet.
    @MainActor
    static func image(for walk: Walk) -> Image? {
        let renderer = ImageRenderer(content: ShareCardView(walk: walk))
        renderer.scale = 3
        guard let uiImage = renderer.uiImage else { return nil }
        return Image(uiImage: uiImage)
    }
}
