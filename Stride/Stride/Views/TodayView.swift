import SwiftUI

/// Home screen: the live step ring, today's numbers, the Start Walk button
/// and a glance at the week.
@MainActor
struct TodayView: View {
    var openWalk: () -> Void

    @EnvironmentObject private var today: TodayModel
    @EnvironmentObject private var profile: UserProfile
    @EnvironmentObject private var session: WalkSession
    @EnvironmentObject private var health: HealthKitService
    @Environment(\.scenePhase) private var scenePhase

    @State private var goalCelebrations = 0
    @State private var appeared = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    ringCard
                    statsRow
                    if session.isRunning {
                        walkInProgressCard
                    } else {
                        startButton
                    }
                    weekCard
                    if today.motionDenied {
                        motionWarning
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
            ConfettiBurst(trigger: goalCelebrations)
                .ignoresSafeArea()
        }
        .onAppear {
            if profile.hasOnboarded { today.start() }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.8)) { appeared = true }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await today.refresh() } }
        }
        .onChange(of: today.goalReached) { wasReached, isReached in
            if isReached && !wasReached && appeared { goalCelebrations += 1 }
        }
        .sensoryFeedback(.success, trigger: goalCelebrations)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Date().formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Text(greeting)
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
            }
            Spacer()
            healthBadge
        }
        .padding(.top, 8)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Night owl"
        }
    }

    private var healthBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "heart.fill")
                .foregroundStyle(health.hasRequestedAccess ? Theme.rose : .secondary)
            Text(health.hasRequestedAccess ? "Health" : "Not linked")
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private var ringCard: some View {
        GlassCard(padding: 20) {
            VStack(spacing: 14) {
                ZStack {
                    ProgressRing(progress: appeared ? today.goalProgress : 0,
                                 lineWidth: 24,
                                 goalReached: today.goalReached)
                        .frame(width: 250, height: 250)

                    VStack(spacing: 4) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.stepsGradient)
                            .symbolEffect(.bounce, value: today.steps)
                        Text(Format.steps(today.steps))
                            .font(.system(size: 54, weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.5, dampingFraction: 0.9), value: today.steps)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("of \(Format.steps(profile.dailyGoal)) steps")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 36)
                }

                HStack(spacing: 6) {
                    Image(systemName: today.goalReached ? "checkmark.seal.fill" : "target")
                        .foregroundStyle(today.goalReached ? Theme.mint : Theme.sky)
                    Text(today.goalReached
                         ? "Goal reached! Keep it going."
                         : "\(Int((today.goalProgress * 100).rounded()))% of your goal · \(Format.steps(max(profile.dailyGoal - today.steps, 0))) to go")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                     value: Format.miles(today.distanceMeters), unit: "mi",
                     label: "Distance", tint: Theme.sky)
            StatTile(icon: "flame.fill",
                     value: Format.calories(today.calories), unit: "kcal",
                     label: "Calories", tint: Theme.flame)
            StatTile(icon: "chart.bar.fill",
                     value: Format.steps(today.weeklyAverage),
                     label: "7-day avg", tint: Theme.violet)
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.9), value: today.steps)
    }

    private var startButton: some View {
        Button {
            session.start()
            openWalk()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 22, weight: .bold))
                    .symbolEffect(.pulse)
                Text("Start a Walk")
                    .font(.title3.weight(.bold))
                Spacer()
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(Theme.buttonGradient, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .foregroundStyle(.black.opacity(0.85))
            .shadow(color: Theme.mint.opacity(0.45), radius: 18, y: 10)
        }
        .buttonStyle(PressableStyle())
    }

    private var walkInProgressCard: some View {
        Button(action: openWalk) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Theme.mint.opacity(0.2)).frame(width: 46, height: 46)
                    Image(systemName: session.state == .paused ? "pause.fill" : "figure.walk.motion")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.mint)
                        .symbolEffect(.pulse, isActive: session.state == .active)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.state == .paused ? "Walk paused" : "Walk in progress")
                        .font(.headline)
                    Text("\(Format.duration(session.elapsed)) · \(Format.steps(session.steps)) steps · \(Format.distance(session.distanceMeters))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                Image(systemName: "chevron.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.mint)
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(Theme.mint.opacity(0.5), lineWidth: 1.5)
            )
        }
        .buttonStyle(PressableStyle())
    }

    private var weekCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("This week", systemImage: "calendar")
                        .font(.headline)
                    Spacer()
                    Text("avg \(Format.steps(today.weeklyAverage))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                if today.weeklySteps.isEmpty {
                    Text("Your last seven days will appear here once there is some step data.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    StepsChart(days: today.weeklySteps, goal: profile.dailyGoal, compact: true)
                        .frame(height: 130)
                }
            }
        }
    }

    private var motionWarning: some View {
        GlassCard {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.gold)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Motion access is off").font(.subheadline.weight(.semibold))
                    Text("Turn on Motion & Fitness for Stride in Settings to count steps.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button("Settings") { openSettings() }
                    .font(.caption.weight(.bold))
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.teal)
            }
        }
    }
}

/// Opens the app's page in the iOS Settings app.
@MainActor
func openSettings() {
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
}
