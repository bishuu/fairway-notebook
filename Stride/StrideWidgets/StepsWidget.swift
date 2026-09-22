import WidgetKit
import SwiftUI
import AppIntents

struct StepsEntry: TimelineEntry {
    var date: Date
    var snapshot: StrideSnapshot?
    /// True when the App Group is missing, so the widget can explain itself.
    var unavailable: Bool = false
}

struct StepsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StepsEntry {
        StepsEntry(date: Date(), snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (StepsEntry) -> Void) {
        if context.isPreview {
            completion(StepsEntry(date: Date(), snapshot: .placeholder))
            return
        }
        completion(currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StepsEntry>) -> Void) {
        let entry = currentEntry()
        // The app pushes a fresh snapshot whenever its numbers change; this is
        // just a safety net so the face never goes stale for long.
        let next = Calendar.current.date(byAdding: .minute, value: 20, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    private func currentEntry() -> StepsEntry {
        guard let snapshot = AppGroup.loadSnapshot() else {
            // Either the app has not run yet, or the shared container is not
            // available on this build. Either way, there is nothing to show.
            return StepsEntry(date: Date(), snapshot: nil, unavailable: true)
        }
        return StepsEntry(date: Date(), snapshot: snapshot)
    }
}

struct StepsWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StrideStepsWidget", provider: StepsProvider()) { entry in
            StepsWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LinearGradient(colors: [Color(red: 0.06, green: 0.10, blue: 0.20),
                                            Color(red: 0.04, green: 0.16, blue: 0.23)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
        }
        .configurationDisplayName("Steps Today")
        .description("Your step ring, distance and streak at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct StepsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StepsEntry

    private var snapshot: StrideSnapshot { entry.snapshot ?? StrideSnapshot(steps: 0, goal: 10_000, distanceMeters: 0, calories: 0, streakDays: 0, walkActive: false, updated: Date()) }

    var body: some View {
        switch family {
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .systemMedium: medium
        default: small
        }
    }

    // MARK: - Home Screen

    private var small: some View {
        VStack(spacing: 8) {
            if entry.unavailable {
                unavailableNote
            } else {
                ZStack {
                    WidgetRing(progress: snapshot.progress, lineWidth: 11)
                        .frame(width: 92, height: 92)
                    VStack(spacing: 0) {
                        Text(Format.steps(snapshot.steps))
                            .font(.system(size: 21, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text("steps")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .padding(.horizontal, 16)
                }
                HStack(spacing: 5) {
                    if snapshot.streakDays > 0 {
                        Image(systemName: "flame.fill").font(.system(size: 9))
                        Text("\(snapshot.streakDays)d").font(.system(size: 10, weight: .bold))
                    }
                    Text(Format.distance(snapshot.distanceMeters, digits: 1))
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.7))
            }
        }
        .foregroundStyle(.white)
        .widgetURL(URL(string: "stride://today"))
    }

    private var medium: some View {
        HStack(spacing: 16) {
            if entry.unavailable {
                unavailableNote
            } else {
                ZStack {
                    WidgetRing(progress: snapshot.progress, lineWidth: 11)
                        .frame(width: 88, height: 88)
                    VStack(spacing: 0) {
                        Text(Format.steps(snapshot.steps))
                            .font(.system(size: 19, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                        Text("of \(Format.steps(snapshot.goal))")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .padding(.horizontal, 14)
                }

                VStack(alignment: .leading, spacing: 8) {
                    metric("point.topleft.down.to.point.bottomright.curvepath.fill",
                           Format.distance(snapshot.distanceMeters, digits: 1), Theme.sky)
                    metric("flame.fill", "\(Format.calories(snapshot.calories)) kcal", Theme.flame)
                    metric(snapshot.streakDays > 0 ? "flame.fill" : "target",
                           snapshot.streakDays > 0 ? "\(snapshot.streakDays) day streak"
                                                   : "\(Format.steps(snapshot.remaining)) to go",
                           Theme.mint)

                    Button(intent: StartWalkIntent()) {
                        Label("Start a Walk", systemImage: "figure.walk.motion")
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.buttonGradient, in: Capsule())
                            .foregroundStyle(.black.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .foregroundStyle(.white)
    }

    private func metric(_ icon: String, _ text: String, _ tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 10, weight: .bold)).foregroundStyle(tint)
            Text(text).font(.system(size: 12, weight: .semibold))
            Spacer(minLength: 0)
        }
    }

    private var unavailableNote: some View {
        VStack(spacing: 4) {
            Image(systemName: "figure.walk").font(.system(size: 20, weight: .bold))
            Text("Open Stride")
                .font(.system(size: 12, weight: .bold))
            Text("to share today's steps")
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Lock Screen

    private var circular: some View {
        Gauge(value: snapshot.progress) {
            Image(systemName: "figure.walk")
        } currentValueLabel: {
            Text(compactSteps)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
        }
        .gaugeStyle(.accessoryCircular)
        .widgetURL(URL(string: "stride://today"))
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("\(Format.steps(snapshot.steps)) steps", systemImage: "figure.walk")
                .font(.system(size: 15, weight: .bold, design: .rounded))
            ProgressView(value: snapshot.progress)
                .progressViewStyle(.linear)
            Text(snapshot.goalReached
                 ? "Goal complete"
                 : "\(Format.steps(snapshot.remaining)) to your goal")
                .font(.system(size: 11))
        }
        .widgetURL(URL(string: "stride://today"))
    }

    private var inline: some View {
        Label("\(Format.steps(snapshot.steps)) steps", systemImage: "figure.walk")
    }

    private var compactSteps: String {
        let steps = snapshot.steps
        if steps >= 10_000 {
            return "\((Double(steps) / 1000).formatted(.number.precision(.fractionLength(0))))k"
        }
        if steps >= 1000 {
            return "\((Double(steps) / 1000).formatted(.number.precision(.fractionLength(1))))k"
        }
        return "\(steps)"
    }
}

/// A plain, static version of the app's ring, sized for a widget.
struct WidgetRing: View {
    var progress: Double
    var lineWidth: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.14), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(min(progress, 1), 0.004))
                .stroke(AngularGradient(colors: [Theme.teal, Theme.mint, Theme.sky, Theme.teal],
                                        center: .center),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}
