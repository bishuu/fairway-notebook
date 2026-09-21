import SwiftUI

/// Past walks and the step history chart.
@MainActor
struct HistoryView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case walks = "Walks"
        case steps = "Steps"
        var id: String { rawValue }
    }

    enum Span: String, CaseIterable, Identifiable {
        case week = "7 days"
        case month = "30 days"
        var id: String { rawValue }
    }

    @EnvironmentObject private var store: WalkStore
    @EnvironmentObject private var today: TodayModel
    @EnvironmentObject private var profile: UserProfile

    @State private var mode: Mode = .walks
    @State private var span: Span = .week

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        Picker("Mode", selection: $mode) {
                            ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        switch mode {
                        case .walks: walksSection
                        case .steps: stepsSection
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("History")
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: Walk.self) { walk in
                WalkDetailView(walkID: walk.id)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: mode)
    }

    // MARK: - Walks

    @ViewBuilder
    private var walksSection: some View {
        if store.walks.isEmpty {
            ContentUnavailableView {
                Label("No walks yet", systemImage: "figure.walk")
            } description: {
                Text("Tap Start a Walk on the Today tab. Your walks, routes and stats will show up here.")
            }
            .padding(.top, 60)
        } else {
            totalsCard
            ForEach(store.walksByDay, id: \.day) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(Format.dayName(group.day))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                    ForEach(group.walks) { walk in
                        NavigationLink(value: walk) {
                            WalkRow(walk: walk)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private var totalsCard: some View {
        GlassCard {
            HStack {
                totalItem(value: "\(store.walks.count)", label: store.walks.count == 1 ? "walk" : "walks", tint: Theme.mint)
                Divider().frame(height: 34)
                totalItem(value: Format.miles(store.totalDistanceMeters, digits: 1), label: "miles", tint: Theme.sky)
                Divider().frame(height: 34)
                totalItem(value: Format.steps(store.totalSteps), label: "steps", tint: Theme.violet)
                Divider().frame(height: 34)
                totalItem(value: Format.calories(store.totalCalories), label: "kcal", tint: Theme.flame)
            }
        }
    }

    private func totalItem(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Steps

    private var stepsSection: some View {
        VStack(spacing: 16) {
            Picker("Range", selection: $span) {
                ForEach(Span.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            let days = span == .week ? today.weeklySteps : today.monthlySteps

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Steps per day", systemImage: "chart.bar.fill")
                        .font(.headline)
                    if days.isEmpty {
                        Text("No step history yet. Connect Apple Health in Profile to see your full history.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else {
                        StepsChart(days: days, goal: profile.dailyGoal)
                            .frame(height: 220)
                    }
                }
            }

            if !days.isEmpty {
                HStack(spacing: 12) {
                    StatTile(icon: "chart.line.uptrend.xyaxis", value: Format.steps(average(days)), label: "Average", tint: Theme.sky)
                    StatTile(icon: "trophy.fill", value: Format.steps(days.map { $0.steps }.max() ?? 0), label: "Best day", tint: Theme.gold)
                    StatTile(icon: "checkmark.seal.fill", value: "\(days.filter { $0.steps >= profile.dailyGoal }.count)",
                             unit: "of \(days.count)", label: "Goal hit", tint: Theme.mint)
                }
            }
        }
    }

    private func average(_ days: [DailySteps]) -> Int {
        guard !days.isEmpty else { return 0 }
        return days.reduce(0) { $0 + $1.steps } / days.count
    }
}

/// One walk in the history list.
@MainActor
struct WalkRow: View {
    var walk: Walk

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.sky.opacity(0.12))
                if walk.hasRoute {
                    RoutePreview(segments: walk.routeSegments, lineWidth: 2.5)
                        .padding(6)
                } else {
                    Image(systemName: "figure.walk")
                        .font(.title2)
                        .foregroundStyle(Theme.sky)
                }
            }
            .frame(width: 72, height: 72)

            VStack(alignment: .leading, spacing: 4) {
                Text(Format.walkTitle(walk.start))
                    .font(.headline)
                Text(walk.start.formatted(date: .omitted, time: .shortened) + " · " + Format.shortDuration(walk.activeSeconds))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Label(Format.steps(walk.steps), systemImage: "figure.walk")
                    Label(Format.distance(walk.distanceMeters), systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill")
                    Label(Format.calories(walk.calories), systemImage: "flame.fill")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer(minLength: 0)
            if walk.savedToHealth {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.rose)
            }
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .foregroundStyle(.primary)
    }
}
