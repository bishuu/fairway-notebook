import ActivityKit
import WidgetKit
import SwiftUI

/// The card on the Lock Screen and the pill in the Dynamic Island that track
/// a walk while it is happening.
struct WalkLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WalkActivityAttributes.self) { context in
            lockScreen(context.state)
                .widgetURL(URL(string: "stride://walk"))
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(Theme.mint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    islandStat(icon: "figure.walk", value: Format.steps(context.state.steps),
                               label: "steps", tint: Theme.mint)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    islandStat(icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                               value: Format.distanceValue(context.state.distanceMeters),
                               label: Format.units.distanceSuffix, tint: Theme.sky)
                }
                DynamicIslandExpandedRegion(.center) {
                    timer(context.state, size: 22)
                        .foregroundStyle(.white)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 6) {
                        Image(systemName: context.state.isPaused ? "pause.circle.fill" : "flame.fill")
                            .foregroundStyle(context.state.isPaused ? Color.secondary : Theme.flame)
                        Text(context.state.isPaused
                             ? "Paused"
                             : "\(Format.calories(context.state.calories)) kcal burned")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "figure.walk")
                    .foregroundStyle(Theme.mint)
            } compactTrailing: {
                timer(context.state, size: 13)
                    .frame(maxWidth: 52)
                    .foregroundStyle(Theme.mint)
            } minimal: {
                Image(systemName: "figure.walk")
                    .foregroundStyle(Theme.mint)
            }
            .keylineTint(Theme.mint)
        }
    }

    // MARK: - Lock Screen card

    private func lockScreen(_ state: WalkActivityAttributes.ContentState) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.mint.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: state.isPaused ? "pause.fill" : "figure.walk.motion")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.mint)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(state.isPaused ? "Walk paused" : "Walk in progress")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.65))
                timer(state, size: 28)
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 5) {
                lockStat(Format.steps(state.steps), "steps", Theme.mint)
                lockStat(Format.distance(state.distanceMeters), "", Theme.sky)
                lockStat("\(Format.calories(state.calories)) kcal", "", Theme.flame)
            }
        }
        .padding(16)
    }

    private func lockStat(_ value: String, _ label: String, _ tint: Color) -> some View {
        HStack(spacing: 4) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(tint)
            if !label.isEmpty {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private func islandStat(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 1) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }

    /// While the walk runs the system counts the timer up on its own, so the
    /// card stays live without the app sending constant updates.
    @ViewBuilder
    private func timer(_ state: WalkActivityAttributes.ContentState, size: CGFloat) -> some View {
        if let start = state.timerStart, !state.isPaused {
            Text(timerInterval: start...start.addingTimeInterval(86_400),
                 pauseTime: nil, countsDown: false, showsHours: true)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .monospacedDigit()
        } else {
            Text(Format.duration(state.elapsed))
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .monospacedDigit()
        }
    }
}
