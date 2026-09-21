import SwiftUI

/// Shown when a walk ends: review the numbers, then save or discard.
@MainActor
struct WalkSummaryView: View {
    var onDone: () -> Void

    @EnvironmentObject private var session: WalkSession
    @EnvironmentObject private var health: HealthKitService
    @Environment(\.dismiss) private var dismiss

    @State private var appear = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        hero
                        statsGrid
                        if session.route.count > 1 {
                            GlassCard(padding: 12) {
                                RoutePreview(segments: session.routeSegments, lineWidth: 4)
                                    .frame(height: 180)
                            }
                        }
                        healthNote
                        buttons
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Walk Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) { appear = true }
        }
    }

    private var hero: some View {
        VStack(spacing: 8) {
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Theme.stepsGradient)
                .symbolEffect(.bounce, value: appear)
                .scaleEffect(appear ? 1 : 0.5)
            Text(headline)
                .font(.system(.title, design: .rounded).weight(.bold))
            Text("\(Format.steps(session.steps)) steps in \(Format.shortDuration(session.elapsed))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 10)
    }

    private var headline: String {
        if session.steps >= 5000 { return "Huge walk!" }
        if session.steps >= 2000 { return "Nice walk!" }
        if session.steps >= 500 { return "Good stretch of the legs" }
        return "Short and sweet"
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(icon: "figure.walk", value: Format.steps(session.steps), label: "Steps", tint: Theme.mint)
            StatTile(icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                     value: Format.miles(session.distanceMeters), unit: "mi", label: "Distance", tint: Theme.sky)
            StatTile(icon: "flame.fill", value: Format.calories(session.calories), unit: "kcal", label: "Calories", tint: Theme.flame)
            StatTile(icon: "speedometer", value: Format.pace(secondsPerMile: session.averagePaceSecondsPerMile),
                     unit: "/mi", label: "Avg pace", tint: Theme.violet)
        }
    }

    private var healthNote: some View {
        HStack(spacing: 10) {
            Image(systemName: "heart.fill")
                .foregroundStyle(health.canSaveWorkouts ? Theme.rose : .secondary)
            Text(health.canSaveWorkouts
                 ? "Saving will also add this walk to Apple Health as a workout."
                 : "Connect Apple Health in Profile to save walks as workouts.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 4)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            Button {
                session.save()
                dismiss()
                onDone()
            } label: {
                Label("Save Walk", systemImage: "checkmark.circle.fill")
                    .font(.title3.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Theme.buttonGradient, in: Capsule())
                    .foregroundStyle(.black.opacity(0.85))
                    .shadow(color: Theme.mint.opacity(0.4), radius: 14, y: 8)
            }
            .buttonStyle(PressableStyle())

            Button(role: .destructive) {
                session.discard()
                dismiss()
                onDone()
            } label: {
                Text("Discard")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
        }
        .padding(.top, 6)
    }
}
