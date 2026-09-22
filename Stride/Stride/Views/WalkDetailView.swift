import SwiftUI
import MapKit
import Combine

/// A saved walk: the route on a map with an animated replay, plus its stats.
@MainActor
struct WalkDetailView: View {
    let walk: Walk

    @EnvironmentObject private var store: WalkStore
    @EnvironmentObject private var health: HealthKitService
    @Environment(\.dismiss) private var dismiss

    @State private var showDeleteConfirm = false
    @State private var healthMessage: String?

    /// The stored copy, so a later "Save to Apple Health" shows up here too.
    private var current: Walk { store.walk(with: walk.id) ?? walk }

    var body: some View {
        let item = current
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 16) {
                    if item.hasRoute {
                        ReplayMapCard(walk: item)
                    } else {
                        GlassCard {
                            Label("No route was recorded for this walk (location was off or indoors).", systemImage: "map")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    statsGrid(item)
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

    // MARK: - Stats

    private func statsGrid(_ walk: Walk) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            StatTile(icon: "figure.walk", value: Format.steps(walk.steps), label: "Steps", tint: Theme.mint)
            StatTile(icon: "point.topleft.down.to.point.bottomright.curvepath.fill",
                     value: Format.miles(walk.distanceMeters), unit: "mi", label: "Distance", tint: Theme.sky)
            StatTile(icon: "flame.fill", value: Format.calories(walk.calories), unit: "kcal", label: "Calories", tint: Theme.flame)
            StatTile(icon: "timer", value: Format.duration(walk.activeSeconds), label: "Duration", tint: Theme.violet)
            StatTile(icon: "speedometer", value: Format.pace(secondsPerMile: walk.paceSecondsPerMile), unit: "/mi", label: "Avg pace", tint: Theme.gold)
            StatTile(icon: "gauge.with.dots.needle.33percent", value: Format.speedMph(metersPerSecond: walk.averageSpeedMetersPerSecond), label: "Avg speed", tint: Theme.rose)
        }
    }

    private func detailsCard(_ walk: Walk) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                row("Started", Format.dateTime(walk.start))
                row("Finished", walk.end.formatted(date: .omitted, time: .shortened))
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

/// The route map with the replay animation. Kept as its own view so only
/// this part redraws while the replay is running.
@MainActor
struct ReplayMapCard: View {
    private let walk: Walk
    private let track: RouteTrack
    private let region: MKCoordinateRegion
    private let replayDuration: Double = 9
    private let ticker = Timer.publish(every: 1 / 30, on: .main, in: .common).autoconnect()

    @State private var progress: Double = 0
    @State private var isReplaying = false

    init(walk: Walk) {
        self.walk = walk
        let track = RouteTrack(points: walk.route)
        self.track = track
        region = track.region ?? MKCoordinateRegion()
    }

    var body: some View {
        VStack(spacing: 16) {
            map
            controls
        }
        .onReceive(ticker) { _ in
            guard isReplaying else { return }
            progress += (1 / 30) / replayDuration
            if progress >= 1 {
                progress = 1
                isReplaying = false
            }
        }
    }

    private var map: some View {
        // The trail polyline only changes in coarse steps (cheap); the marker moves every frame.
        let trailFraction = (progress * 150).rounded(.down) / 150
        let trail = track.trail(to: trailFraction)
        let head = track.coordinate(at: progress)
        let segments = walk.routeSegments
        return Map(initialPosition: .region(region), interactionModes: [.pan, .zoom]) {
            // Faint full route underneath.
            ForEach(0..<segments.count, id: \.self) { index in
                MapPolyline(coordinates: segments[index])
                    .stroke(Theme.routeColor.opacity(0.28), lineWidth: 5)
            }
            // The part "walked" so far in the replay.
            if trail.count > 1 {
                MapPolyline(coordinates: trail)
                    .stroke(Theme.routeGlow.opacity(0.45), lineWidth: 12)
                MapPolyline(coordinates: trail)
                    .stroke(Theme.routeColor, lineWidth: 5)
            }
            if let start = track.points.first {
                Annotation("Start", coordinate: start, anchor: .center) { StartPin() }
                    .annotationTitles(.hidden)
            }
            if let end = track.points.last {
                Annotation("Finish", coordinate: end, anchor: .center) { EndPin() }
                    .annotationTitles(.hidden)
            }
            if let head {
                Annotation("Walker", coordinate: head, anchor: .center) {
                    PulsingMarker(isMoving: isReplaying)
                        .scaleEffect(0.8)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .frame(height: 340)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var controls: some View {
        GlassCard(padding: 14) {
            HStack(spacing: 14) {
                Button {
                    if isReplaying {
                        isReplaying = false
                    } else {
                        if progress >= 1 { progress = 0 }
                        isReplaying = true
                    }
                } label: {
                    Image(systemName: isReplaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 18, weight: .bold))
                        .frame(width: 46, height: 46)
                        .background(Theme.buttonGradient, in: Circle())
                        .foregroundStyle(.black.opacity(0.85))
                }
                .buttonStyle(PressableStyle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(isReplaying ? "Replaying your walk…" : (progress >= 1 ? "Replay finished" : "Replay this walk"))
                        .font(.subheadline.weight(.semibold))
                    Slider(value: $progress, in: 0...1) { editing in
                        if editing { isReplaying = false }
                    }
                    .tint(Theme.teal)
                }
            }
        }
    }
}
