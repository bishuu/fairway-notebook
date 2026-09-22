import SwiftUI

/// Streak, personal bests and the badge collection.
@MainActor
struct AwardsView: View {
    @EnvironmentObject private var today: TodayModel
    @EnvironmentObject private var store: WalkStore
    @EnvironmentObject private var profile: UserProfile

    @State private var selected: Achievement?

    private var achievements: [Achievement] {
        AchievementEngine.achievements(walks: store.walks, days: today.monthlySteps, goal: profile.dailyGoal)
    }

    private var records: [PersonalRecord] {
        AchievementEngine.records(walks: store.walks, days: today.monthlySteps)
    }

    var body: some View {
        let badges = achievements
        let earned = badges.filter { $0.unlocked }
        let locked = badges.filter { !$0.unlocked }.sorted { $0.progress > $1.progress }

        VStack(spacing: 16) {
            streakCard(earnedCount: earned.count, total: badges.count)

            if !records.isEmpty {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Personal bests", systemImage: "trophy.fill")
                            .font(.headline)
                        ForEach(records) { record in
                            HStack(spacing: 12) {
                                Image(systemName: record.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(record.tint.gradient, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(record.title).font(.subheadline.weight(.semibold))
                                    Text(record.caption).font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(record.value)
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .monospacedDigit()
                            }
                        }
                    }
                }
            }

            badgeGrid(title: "Earned", badges: earned, showProgress: false)
            badgeGrid(title: "In progress", badges: locked, showProgress: true)
        }
        .sheet(item: $selected) { badge in
            badgeDetail(badge)
        }
    }

    private func streakCard(earnedCount: Int, total: Int) -> some View {
        GlassCard {
            HStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Theme.flame.opacity(0.35), .clear],
                                             center: .center, startRadius: 2, endRadius: 40))
                        .frame(width: 76, height: 76)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Theme.flameGradient)
                        .symbolEffect(.pulse, isActive: today.streakDays > 0)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(today.streakDays == 0 ? "No streak yet" : "\(today.streakDays) day streak")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                    Text(today.streakDays == 0
                         ? "Hit your daily goal to start one."
                         : "Days in a row you have hit your goal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(earnedCount) of \(total) badges earned")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.mint)
                }
                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func badgeGrid(title: String, badges: [Achievement], showProgress: Bool) -> some View {
        if !badges.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12)], spacing: 12) {
                    ForEach(badges) { badge in
                        Button {
                            selected = badge
                        } label: {
                            BadgeTile(badge: badge, showProgress: showProgress)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }
            }
        }
    }

    private func badgeDetail(_ badge: Achievement) -> some View {
        VStack(spacing: 18) {
            Capsule().fill(.secondary.opacity(0.4)).frame(width: 40, height: 5).padding(.top, 10)
            BadgeTile(badge: badge, showProgress: !badge.unlocked)
                .frame(width: 150)
                .scaleEffect(1.15)
                .padding(.top, 12)
            Text(badge.title)
                .font(.system(.title2, design: .rounded).weight(.bold))
            Text(badge.detail)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let unlockedOn = badge.unlockedOn {
                Label("Earned \(unlockedOn.formatted(.dateTime.month(.wide).day().year()))",
                      systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.mint)
            } else {
                Text("\(Int((badge.progress * 100).rounded()))% of the way there")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 28)
        .presentationDetents([.height(430)])
        .presentationBackground(.regularMaterial)
    }
}

/// One badge: earned badges glow, unearned ones show how far along you are.
@MainActor
struct BadgeTile: View {
    var badge: Achievement
    var showProgress: Bool

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(badge.unlocked
                          ? AnyShapeStyle(badge.tint.gradient)
                          : AnyShapeStyle(Color.primary.opacity(0.08)))
                    .frame(width: 56, height: 56)
                    .shadow(color: badge.unlocked ? badge.tint.opacity(0.5) : .clear, radius: 8, y: 3)

                if showProgress && badge.progress > 0 {
                    Circle()
                        .trim(from: 0, to: badge.progress)
                        .stroke(badge.tint.opacity(0.85), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .frame(width: 64, height: 64)
                }

                Image(systemName: badge.icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(badge.unlocked ? .white : .secondary)
            }
            Text(badge.title)
                .font(.caption2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .foregroundStyle(badge.unlocked ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(badge.unlocked ? badge.tint.opacity(0.4) : .white.opacity(0.1), lineWidth: 1)
        )
    }
}
