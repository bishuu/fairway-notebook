import SwiftUI
import MapKit
import Combine
import CoreLocation

/// The cinematic replay: a camera that flies along the route behind the
/// walker, a line coloured by how fast each stretch was, a glowing comet head,
/// and counters that climb as the walk replays.
@MainActor
struct ReplayView: View {
    enum CameraMode: String, CaseIterable, Identifiable {
        case follow = "Follow"
        case overview = "Whole route"
        var id: String { rawValue }
    }

    private let walk: Walk
    private let track: RouteTrack
    private let runs: [RouteTrack.PaceRun]
    private let overviewRegion: MKCoordinateRegion

    /// Frames per second for the marker and counters.
    private let frameRate: Double = 20
    private let ticker: Publishers.Autoconnect<Timer.TimerPublisher>

    @State private var progress: Double = 0
    @State private var isPlaying = false
    @State private var speed: Double = 1
    @State private var mode: CameraMode = .follow
    @State private var camera: MapCameraPosition
    @State private var frame = 0
    @State private var finishedPulse = 0

    init(walk: Walk) {
        self.walk = walk
        let track = RouteTrack(points: walk.route)
        self.track = track
        runs = track.paceRuns()
        let region = track.region ?? MKCoordinateRegion()
        overviewRegion = region
        ticker = Timer.publish(every: 1 / 20, on: .main, in: .common).autoconnect()
        if let start = track.samples.first {
            _camera = State(initialValue: .camera(MapCamera(centerCoordinate: start.coordinate,
                                                            distance: 420,
                                                            heading: start.heading,
                                                            pitch: 55)))
        } else {
            _camera = State(initialValue: .region(region))
        }
    }

    /// How long a full replay takes: longer walks get a little longer, but
    /// never so long that watching it becomes a chore.
    private var baseDuration: Double {
        let minutes = walk.activeSeconds / 60
        return min(max(8, 6 + minutes * 0.35), 26)
    }

    var body: some View {
        VStack(spacing: 14) {
            mapCard
            counters
            controls
        }
        .onReceive(ticker) { _ in advance() }
        .sensoryFeedback(.success, trigger: finishedPulse)
    }

    // MARK: - Map

    private var mapCard: some View {
        let head = track.distance(at: progress)
        let headPoint = track.coordinate(at: progress)
        let tail = track.tail(endingAt: progress, metres: max(track.total * 0.04, 40))

        return Map(position: $camera, interactionModes: mode == .overview ? [.pan, .zoom] : []) {
            // The whole route, dimmed, so its shape reads at once.
            ForEach(runs) { run in
                MapPolyline(coordinates: run.coordinates)
                    .stroke(Theme.paceColor(band: run.band).opacity(0.28),
                            style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            }
            // The part replayed so far, at full strength.
            ForEach(runs) { run in
                let walked = track.clip(run, toDistance: head)
                if walked.count > 1 {
                    MapPolyline(coordinates: walked)
                        .stroke(Theme.paceColor(band: run.band),
                                style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                }
            }
            // A bright comet tail just behind the walker.
            if tail.count > 1 {
                MapPolyline(coordinates: tail)
                    .stroke(.white.opacity(0.85),
                            style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            if let start = track.samples.first?.coordinate {
                Annotation("Start", coordinate: start, anchor: .center) { StartPin() }
                    .annotationTitles(.hidden)
            }
            if let end = track.samples.last?.coordinate {
                Annotation("Finish", coordinate: end, anchor: .center) { EndPin() }
                    .annotationTitles(.hidden)
            }
            if let headPoint {
                Annotation("Walker", coordinate: headPoint, anchor: .center) {
                    CometHead(isMoving: isPlaying)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .frame(height: 380)
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        .overlay(alignment: .topTrailing) { modePicker }
        .overlay(alignment: .bottomLeading) { paceLegend }
        .overlay(
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(CameraMode.allCases) { option in
                Button {
                    mode = option
                    updateCamera(force: true)
                } label: {
                    Image(systemName: option == .follow ? "video.fill" : "map.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(width: 34, height: 30)
                        .background(mode == option ? Theme.teal.opacity(0.9) : .clear, in: Capsule())
                        .foregroundStyle(mode == option ? .white : .primary)
                }
            }
        }
        .padding(3)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(10)
    }

    private var paceLegend: some View {
        HStack(spacing: 6) {
            Text("slow").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
            HStack(spacing: 0) {
                ForEach(0..<Theme.paceRamp.count, id: \.self) { index in
                    Rectangle().fill(Theme.paceRamp[index]).frame(width: 13, height: 6)
                }
            }
            .clipShape(Capsule())
            Text("fast").font(.system(size: 9, weight: .bold)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(10)
        .opacity(track.total > 100 ? 1 : 0)
    }

    // MARK: - Counters

    private var counters: some View {
        HStack(spacing: 8) {
            replayStat(Format.distanceValue(track.distance(at: progress)),
                       Format.units.distanceSuffix, "Distance", Theme.sky)
            replayStat(Format.duration(track.elapsed(at: progress)), nil, "Elapsed", Theme.violet)
            replayStat(paceNow, "/\(Format.units.distanceSuffix)", "Pace", Theme.mint)
        }
    }

    private var paceNow: String {
        let speed = track.speed(at: progress)
        guard speed > 0.2 else { return "--'--\"" }
        return Format.pace(secondsPerMeter: 1 / speed)
    }

    private func replayStat(_ value: String, _ unit: String?, _ label: String, _ tint: Color) -> some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                if let unit {
                    Text(unit).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(tint)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Controls

    private var controls: some View {
        GlassCard(padding: 14) {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    Button {
                        if isPlaying {
                            isPlaying = false
                        } else {
                            if progress >= 1 { restart() }
                            isPlaying = true
                        }
                    } label: {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold))
                            .frame(width: 52, height: 52)
                            .background(Theme.buttonGradient, in: Circle())
                            .foregroundStyle(.black.opacity(0.85))
                            .shadow(color: Theme.mint.opacity(0.4), radius: 8, y: 4)
                    }
                    .buttonStyle(PressableStyle())

                    Button {
                        restart()
                        isPlaying = true
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 15, weight: .bold))
                            .frame(width: 40, height: 40)
                            .background(.thinMaterial, in: Circle())
                    }
                    .buttonStyle(PressableStyle())

                    Spacer()

                    ForEach([1.0, 2.0, 4.0], id: \.self) { option in
                        Button {
                            speed = option
                        } label: {
                            Text(option == 1 ? "1×" : (option == 2 ? "2×" : "4×"))
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .frame(width: 38, height: 32)
                                .background(speed == option ? Theme.teal.opacity(0.9) : Color.primary.opacity(0.07),
                                            in: Capsule())
                                .foregroundStyle(speed == option ? .white : .primary)
                        }
                        .buttonStyle(PressableStyle())
                    }
                }

                Slider(value: $progress, in: 0...1) { editing in
                    if editing { isPlaying = false }
                    updateCamera(force: true)
                }
                .tint(Theme.teal)
            }
        }
    }

    // MARK: - Playback

    private func restart() {
        progress = 0
        updateCamera(force: true)
    }

    private func advance() {
        guard isPlaying else { return }
        frame &+= 1
        let step = (1 / frameRate) * speed / baseDuration
        progress = min(progress + step, 1)
        if progress >= 1 {
            isPlaying = false
            finishedPulse += 1
            withAnimation(.easeInOut(duration: 0.9)) { camera = .region(overviewRegion) }
            mode = .overview
            return
        }
        updateCamera(force: false)
    }

    /// The camera is nudged a few times a second and MapKit smooths between,
    /// which looks like a flight and costs far less than moving it every frame.
    private func updateCamera(force: Bool) {
        guard mode == .follow else {
            if force { withAnimation(.easeInOut(duration: 0.6)) { camera = .region(overviewRegion) } }
            return
        }
        guard force || frame % 2 == 0 else { return }
        guard let point = track.coordinate(at: progress) else { return }
        let target = MapCamera(centerCoordinate: point,
                               distance: 420,
                               heading: track.heading(at: progress),
                               pitch: 55)
        if force {
            withAnimation(.easeInOut(duration: 0.4)) { camera = .camera(target) }
        } else {
            withAnimation(.linear(duration: 2 / frameRate)) { camera = .camera(target) }
        }
    }
}

/// The glowing head of the replay: a walker inside a soft halo with a spark.
@MainActor
struct CometHead: View {
    var isMoving: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !isMoving)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 1.4) / 1.4
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Theme.mint.opacity(0.55), .clear],
                                         center: .center, startRadius: 2, endRadius: 34))
                    .frame(width: 68, height: 68)

                Circle()
                    .stroke(Color.white.opacity(0.75 * (1 - phase)), lineWidth: 2)
                    .frame(width: 26 + 40 * phase, height: 26 + 40 * phase)

                Circle()
                    .fill(Theme.mint)
                    .frame(width: 26, height: 26)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 3))
                    .shadow(color: Theme.mint.opacity(0.9), radius: 8)

                Image(systemName: "figure.walk")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.black.opacity(0.8))
            }
            .frame(width: 70, height: 70)
        }
    }
}
