import SwiftUI
import Charts

/// Weekly and monthly reports: how this period compares with the last one.
@MainActor
struct TrendsView: View {
    @EnvironmentObject private var today: TodayModel
    @EnvironmentObject private var store: WalkStore
    @EnvironmentObject private var profile: UserProfile

    @State private var period: Trends.Period = .week

    private var report: Trends.Report {
        Trends.report(period: period, days: today.monthlySteps, walks: store.walks)
    }

    var body: some View {
        let report = self.report
        VStack(spacing: 16) {
            Picker("Period", selection: $period) {
                ForEach(Trends.Period.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            headline(report)
            breakdown(report)
            if report.buckets.count > 1 {
                chart(report)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: period)
    }

    private func headline(_ report: Trends.Report) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(report.periodLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Format.steps(report.currentSteps))
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Text("steps")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                if let change = report.change {
                    HStack(spacing: 5) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        Text("\(abs(change).formatted(.number.precision(.fractionLength(0))))% vs last \(period == .week ? "week" : "month")")
                    }
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(change >= 0 ? Theme.mint : Theme.flame)
                } else {
                    Text("No earlier \(period == .week ? "week" : "month") to compare with yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func breakdown(_ report: Trends.Report) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(icon: "figure.walk.motion", value: "\(report.currentWalks)",
                     label: report.currentWalks == 1 ? "Walk" : "Walks", tint: Theme.mint)
            StatTile(icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                     value: Format.distanceValue(report.currentDistance, digits: 1),
                     unit: Format.units.distanceSuffix, label: "Walked", tint: Theme.sky)
            StatTile(icon: "flame.fill", value: Format.calories(report.currentCalories),
                     unit: "kcal", label: "Burned", tint: Theme.flame)
            StatTile(icon: "timer", value: Format.shortDuration(report.currentActiveSeconds),
                     label: "Moving", tint: Theme.violet)
        }
    }

    private func chart(_ report: Trends.Report) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(period == .week ? "Steps by week" : "Steps by month", systemImage: "chart.bar.fill")
                    .font(.headline)
                Chart(report.buckets) { bucket in
                    BarMark(
                        x: .value("Period", bucket.label),
                        y: .value("Steps", bucket.steps),
                        width: .ratio(0.6)
                    )
                    .foregroundStyle(bucket.start == report.periodStart
                                     ? AnyShapeStyle(Theme.stepsGradient)
                                     : AnyShapeStyle(Theme.sky.opacity(0.55)))
                    .cornerRadius(6)
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(Color.primary.opacity(0.08))
                        AxisValueLabel {
                            if let steps = value.as(Int.self) {
                                Text(steps >= 1000 ? "\(steps / 1000)k" : "\(steps)")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in AxisValueLabel().font(.caption2) }
                }
                .frame(height: 180)

                Text("Daily average \(Format.steps(report.buckets.last?.dailyAverage ?? 0)) steps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
