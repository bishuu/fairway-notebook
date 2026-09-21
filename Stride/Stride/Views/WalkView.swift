import SwiftUI
import MapKit
import CoreLocation

/// The live walk: a real-time map with the growing route and a pulsing
/// walker marker, plus timer, steps, distance, calories and pace.
@MainActor
struct WalkView: View {
    @EnvironmentObject private var session: WalkSession
    @EnvironmentObject private var health: HealthKitService
    @Environment(\.dismiss) private var dismiss

    @State private var camera: MapCameraPosition = .automatic
    @State private var isFollowing = true
    @State private var showSummary = false
    @State private var showEndConfirm = false
    @State private var hasCentered = false

    var body: some View {
        ZStack(alignment: .bottom) {
            map
                .ignoresSafeArea()

            VStack {
                topBar
                if session.locationDenied {
                    locationWarning
                }
                Spacer()
                if !isFollowing {
                    recenterButton
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 240)

            statsPanel
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isFollowing)
        .onAppear {
            if session.state == .idle { session.start() }
            follow(session.currentLocation, animated: false)
        }
        .onChange(of: session.currentLocation) { _, location in
            follow(location, animated: hasCentered)
        }
        .onChange(of: camera.positionedByUser) { _, byUser in
            if byUser { isFollowing = false }
        }
        .onChange(of: session.state) { _, state in
            if state == .finished { showSummary = true }
        }
        .sheet(isPresented: $showSummary) {
            WalkSummaryView(onDone: { dismiss() })
        }
        .confirmationDialog("End this walk?", isPresented: $showEndConfirm, titleVisibility: .visible) {
            Button("End Walk", role: .destructive) { session.finish() }
            Button("Keep Walking", role: .cancel) {}
        } message: {
            Text("You can review the walk and save it to your history and Apple Health.")
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: session.state)
    }

    // MARK: - Map

    private var map: some View {
        Map(position: $camera, interactionModes: [.pan, .zoom, .rotate]) {
            ForEach(Array(session.routeSegments.enumerated()), id: \.offset) { _, segment in
                MapPolyline(coordinates: segment)
                    .stroke(Theme.routeGlow.opacity(0.45), lineWidth: 13)
                MapPolyline(coordinates: segment)
                    .stroke(Theme.routeColor, lineWidth: 5)
            }
            if let start = session.route.first {
                Annotation("Start", coordinate: start.coordinate, anchor: .center) {
                    StartPin()
                }
                .annotationTitles(.hidden)
            }
            if let location = session.currentLocation {
                Annotation("You", coordinate: location.coordinate, anchor: .center) {
                    PulsingMarker(isMoving: session.state == .active)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .mapControls {
            MapCompass()
        }
    }

    private func follow(_ location: CLLocation?, animated: Bool) {
        guard isFollowing, let location else { return }
        let target = MapCameraPosition.camera(
            MapCamera(centerCoordinate: location.coordinate, distance: 650, heading: 0, pitch: 35)
        )
        if animated {
            withAnimation(.easeInOut(duration: 0.9)) { camera = target }
        } else {
            camera = target
        }
        hasCentered = true
    }

    private var recenterButton: some View {
        HStack {
            Spacer()
            Button {
                isFollowing = true
                follow(session.currentLocation, animated: true)
            } label: {
                Label("Recenter", systemImage: "location.fill")
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
    }

    // MARK: - Top bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(PressableStyle())

            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(session.state == .active ? Theme.mint : Theme.gold)
                    .frame(width: 9, height: 9)
                    .shadow(color: session.state == .active ? Theme.mint : .clear, radius: 5)
                Text(session.state == .paused ? "Paused" : "Walking")
                    .font(.subheadline.weight(.bold))
                Text("·").foregroundStyle(.secondary)
                Image(systemName: gpsSymbol)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(gpsLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.ultraThinMaterial, in: Capsule())

            Spacer()

            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.top, 8)
    }

    private var gpsSymbol: String {
        guard let accuracy = session.gpsAccuracy, accuracy > 0 else { return "location.slash" }
        return accuracy <= 15 ? "location.fill" : "location"
    }

    private var gpsLabel: String {
        guard let accuracy = session.gpsAccuracy, accuracy > 0 else { return "No GPS" }
        if accuracy <= 15 { return "GPS good" }
        if accuracy <= 40 { return "GPS ok" }
        return "GPS weak"
    }

    private var locationWarning: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash.fill").foregroundStyle(Theme.gold)
            Text("Location is off, so the map can't follow you. Steps and time still count.")
                .font(.caption.weight(.semibold))
            Spacer()
            Button("Settings") { openSettings() }
                .font(.caption.weight(.bold))
                .buttonStyle(.borderedProminent)
                .tint(Theme.teal)
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.top, 8)
    }

    // MARK: - Stats panel

    private var statsPanel: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 40, height: 5)

            VStack(spacing: 2) {
                Text(Format.duration(session.elapsed))
                    .font(.system(size: 52, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("DURATION")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                BigStat(value: Format.steps(session.steps), label: "Steps", tint: Theme.mint)
                BigStat(value: Format.miles(session.distanceMeters), label: "Miles", tint: Theme.sky)
                BigStat(value: Format.calories(session.calories), label: "kcal", tint: Theme.flame)
                BigStat(value: Format.pace(secondsPerMile: session.currentPaceSecondsPerMile ?? session.averagePaceSecondsPerMile),
                        label: "Pace", tint: Theme.violet)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.9), value: session.steps)
            .animation(.spring(response: 0.5, dampingFraction: 0.9), value: session.elapsed)

            HStack(spacing: 16) {
                Button {
                    if session.state == .active { session.pause() } else { session.resume() }
                } label: {
                    Label(session.state == .active ? "Pause" : "Resume",
                          systemImage: session.state == .active ? "pause.fill" : "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.thinMaterial, in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(PressableStyle())

                Button {
                    showEndConfirm = true
                } label: {
                    Label("End", systemImage: "stop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(LinearGradient(colors: [Theme.rose, Theme.flame], startPoint: .leading, endPoint: .trailing), in: Capsule())
                        .foregroundStyle(.white)
                        .shadow(color: Theme.rose.opacity(0.4), radius: 12, y: 6)
                }
                .buttonStyle(PressableStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous))
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(topLeadingRadius: 30, topTrailingRadius: 30, style: .continuous)
                .strokeBorder(.white.opacity(0.15), lineWidth: 1)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
