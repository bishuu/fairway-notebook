import SwiftUI

/// A saved walk: the cinematic route replay, its numbers, and a share card.
@MainActor
struct WalkDetailView: View {
    let walk: Walk

    @EnvironmentObject private var store: WalkStore
    @EnvironmentObject private var health: HealthKitService
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var healthMessage: String?
    @State private var shareImage: Image?

    /// The stored copy, so heart rate and Health status arriving later show here.
    private var current: Walk { store.walk(with: walk.id) ?? walk }

    var body: some View {
        let item = current
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    if item.hasRoute {
                        ReplayView(walk: item)
                    } else {
                        GlassCard {
                            Label("No route was recorded for this walk (location was off, or you were indoors).",
                                  systemImage: "map")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    statsGrid(item)
                    shareButton(item)
                    detailsCard(item)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle(Format.walkTitle(item.start))
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if !item.savedToHealth, health.canSaveWorkouts {
                        Button {
                            saveToHealth(item)
                        } label: {
                            Label("Save to Apple Health", systemImage: "heart")
                        }
                    }
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Delete Walk", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog("Delete this walk?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                store.delete(item)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes it from Stride's history. Workouts already saved to Apple Health stay there.")
        }
        .alert("Apple Health", isPresented: Binding(get: { healthMessage != nil }, set: { if !$0 { healthMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(healthMessage ?? "")
        }
    }

    // MARK: - Pieces

    private func statsGrid(_ walk: Walk) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(icon: "figure.walk", value: Format.steps(walk.steps), label: "Steps", tint: Theme.mint)
            StatTile(icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                     value: Format.distanceValue(walk.distanceMeters),
                     unit: Format.units.distanceSuffix, label: "Distance", tint: Theme.sky)
            StatTile(icon: "flame.fill", value: Format.calories(walk.calories), unit: "kcal", label: "Calories", tint: Theme.flame)
            StatTile(icon: "timer", value: Format.duration(walk.activeSeconds), label: "Duration", tint: Theme.violet)
            StatTile(icon: "speedometer", value: Format.pace(secondsPerMeter: walk.paceSecondsPerMeter),
                     unit: "/\(Format.units.distanceSuffix)", label: "Avg pace", tint: Theme.gold)
            StatTile(icon: "gauge.with.dots.needle.33percent",
                     value: Format.speed(metersPerSecond: walk.averageSpeedMetersPerSecond),
                     label: "Avg speed", tint: Theme.rose)
            if walk.elevationGainMeters > 2 {
                StatTile(icon: "mountain.2.fill", value: Format.elevation(walk.elevationGainMeters),
                         label: "Climbed", tint: Theme.teal)
            }
            if let average = walk.averageHeartRate {
                StatTile(icon: "heart.fill", value: Format.heartRate(average), unit: "bpm",
                         label: walk.maxHeartRate.map { "Avg · peak \(Format.heartRate($0))" } ?? "Avg heart rate",
                         tint: Theme.rose)
            }
        }
    }

    private func shareButton(_ walk: Walk) -> some View {
        Group {
            if let shareImage {
                ShareLink(item: shareImage,
                          preview: SharePreview(Format.walkTitle(walk.start), image: shareImage)) {
                    Label("Share this walk", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            } else {
                Button {
                    shareImage = ShareCardRenderer.image(for: walk)
                } label: {
                    Label("Make a share card", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())
            }
        }
    }

    private func detailsCard(_ walk: Walk) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                row("Started", Format.dateTime(walk.start))
                row("Finished", walk.end.formatted(date: .omitted, time: .shortened))
                if !walk.pauses.isEmpty {
                    row("Paused", "\(walk.pauses.count) time\(walk.pauses.count == 1 ? "" : "s")")
                }
                row("Apple Health", walk.savedToHealth ? "Saved as a walking workout" : "Not saved")
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
        .font(.subheadline)
    }

    private func saveToHealth(_ walk: Walk) {
        Task {
            do {
                try await health.saveWorkout(walk)
                var saved = walk
                saved.savedToHealth = true
                store.update(saved)
                healthMessage = "Saved to Apple Health."
            } catch {
                healthMessage = error.localizedDescription
            }
        }
    }
}
