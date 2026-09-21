import SwiftUI

/// First-launch welcome: body inputs plus the three permissions the app needs.
struct OnboardingView: View {
    @EnvironmentObject private var profile: UserProfile
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var today: TodayModel
    @EnvironmentObject private var session: WalkSession

    @State private var motionAsked = false
    @State private var healthAsked = false
    @State private var locationAsked = false
    @State private var appear = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("About you", systemImage: "person.text.rectangle")
                                .font(.headline)
                            Text("Used only to estimate calories and stride length. You can change these any time in Profile.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            BodyInputsForm()
                        }
                    }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Label("Permissions", systemImage: "checkmark.shield")
                                .font(.headline)
                            permissionRow(icon: "figure.walk.motion", tint: Theme.mint,
                                          title: "Motion & Fitness",
                                          detail: "Counts your steps in real time.",
                                          done: motionAsked) {
                                motionAsked = true
                                today.start()
                            }
                            permissionRow(icon: "heart.fill", tint: Theme.rose,
                                          title: "Apple Health",
                                          detail: "Shows your Health step total and saves walks as workouts.",
                                          done: healthAsked) {
                                Task {
                                    await health.requestAuthorization()
                                    healthAsked = true
                                    await today.refresh()
                                }
                            }
                            permissionRow(icon: "location.fill", tint: Theme.sky,
                                          title: "Location",
                                          detail: "Draws your walks on the map.",
                                          done: locationAsked) {
                                locationAsked = true
                                session.location.requestPermission()
                            }
                        }
                    }
                    Button {
                        if !motionAsked { today.start() }
                        profile.hasOnboarded = true
                    } label: {
                        Text("Start Stepping")
                            .font(.title3.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(Theme.buttonGradient, in: Capsule())
                            .foregroundStyle(.black.opacity(0.85))
                            .shadow(color: Theme.mint.opacity(0.45), radius: 16, y: 8)
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.7).delay(0.1)) { appear = true }
        }
    }

    private var hero: some View {
        VStack(spacing: 10) {
            ZStack {
                ProgressRing(progress: appear ? 0.72 : 0.02, lineWidth: 16)
                    .frame(width: 130, height: 130)
                Image(systemName: "figure.walk")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Theme.stepsGradient)
                    .symbolEffect(.pulse)
            }
            .scaleEffect(appear ? 1 : 0.6)
            .opacity(appear ? 1 : 0)

            Text("Stride")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
            Text("Every step, counted. Every walk, mapped.")
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private func permissionRow(icon: String, tint: Color, title: String, detail: String,
                               done: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(tint.gradient, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: action) {
                if done {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.mint)
                } else {
                    Text("Allow")
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(tint.opacity(0.18), in: Capsule())
                        .foregroundStyle(tint)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.6), value: done)
        }
    }
}
