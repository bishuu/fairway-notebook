import SwiftUI
import Charts

/// Bar chart of steps per day with the daily goal line.
struct StepsChart: View {
    var days: [DailySteps]
    var goal: Int
    var compact: Bool = false

    private var labelFormat: Date.FormatStyle {
        days.count > 10 ? Date.FormatStyle.dateTime.day() : Date.FormatStyle.dateTime.weekday(.narrow)
    }

    private var maxSteps: Int {
        max(days.map { $0.steps }.max() ?? 0, goal, 1)
    }

    var body: some View {
        Chart {
            ForEach(days) { day in
                BarMark(
                    x: .value("Day", day.date, unit: .day),
                    y: .value("Steps", day.steps),
                    width: compact ? .ratio(0.55) : .ratio(0.6)
                )
                .foregroundStyle(day.steps >= goal ? AnyShapeStyle(Theme.stepsGradient) : AnyShapeStyle(Theme.sky.opacity(0.75)))
                .cornerRadius(6)
            }
            if goal > 0 {
                RuleMark(y: .value("Goal", goal))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .foregroundStyle(Theme.mint.opacity(0.9))
                    .annotation(position: .top, alignment: .trailing) {
                        if !compact {
                            Text("Goal \(Format.steps(goal))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Theme.mint)
                        }
                    }
            }
        }
        .chartYScale(domain: 0...Double(maxSteps) * 1.15)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: days.count > 10 ? 5 : 1)) { value in
                AxisGridLine().foregroundStyle(.clear)
                AxisValueLabel(format: labelFormat)
                    .font(.caption2)
            }
        }
        .chartYAxis {
            if compact {
                AxisMarks(values: .automatic(desiredCount: 2)) { _ in
                    AxisGridLine().foregroundStyle(.primary.opacity(0.08))
                }
            } else {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(.primary.opacity(0.08))
                    AxisValueLabel {
                        if let steps = value.as(Int.self) {
                            Text(steps >= 1000 ? "\(steps / 1000)k" : "\(steps)")
                                .font(.caption2)
                        }
                    }
                }
            }
        }
    }
}
