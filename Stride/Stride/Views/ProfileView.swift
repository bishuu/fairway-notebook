import SwiftUI
import UniformTypeIdentifiers

/// Body inputs, goal, units, Apple Health, reminders, permissions and backup.
@MainActor
struct ProfileView: View {
    @EnvironmentObject private var profile: UserProfile
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var today: TodayModel
    @EnvironmentObject private var session: WalkSession
    @EnvironmentObject private var store: WalkStore
    @EnvironmentObject private var notifications: NotificationService

    @State private var message: String?
    @State private var isImporting = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var backupDocument: BackupDocument?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        bodyCard
                        goalCard
                        unitsCard
                        healthCard
                        remindersCard
                        backupCard
                        permissionsCard
                        aboutCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 30)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Profile")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .alert("Stride", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
        .fileExporter(isPresented: $showExporter,
                      document: backupDocument,
                      contentType: .json,
                      defaultFilename: BackupService.suggestedName) { result in
            switch result {
            case .success: message = "Backup saved. Pick iCloud Drive to reach it from another phone."
            case .failure(let error): message = error.localizedDescription
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                do {
                    let added = try BackupService.restore(from: url, store: store, profile: profile)
                    message = added == 0
                        ? "Settings restored. No new walks to add."
                        : "Restored \(added) walk\(added == 1 ? "" : "s") and your settings."
                } catch {
                    message = "That file could not be read as a Stride backup."
                }
            case .failure(let error):
                message = error.localizedDescription
            }
        }
        .task { await notifications.refreshStatus() }
    }

    // MARK: - Cards

    private var bodyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Body", systemImage: "person.text.rectangle")
                        .font(.headline)
                    Spacer()
                    if health.isAvailable {
                        Button {
                            importFromHealth()
                        } label: {
                            if isImporting {
                                ProgressView()
                            } else {
                                Label("Import from Health", systemImage: "heart.fill")
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.rose)
                        .disabled(isImporting)
                    }
                }
                BodyInputsForm()
                Text("Weight drives the calorie estimate the most. Height and gender set your stride length, which turns steps into distance when there is no GPS.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var goalCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Daily goal", systemImage: "target")
                        .font(.headline)
                    Spacer()
                    Text("\(Format.steps(profile.dailyGoal)) steps")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.mint)
                        .contentTransition(.numericText())
                }
                Slider(value: goalBinding, in: 2000...30000, step: 500)
                    .tint(Theme.teal)
                HStack {
                    Text("2,000").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("30,000").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var goalBinding: Binding<Double> {
        Binding(get: { Double(profile.dailyGoal) },
                set: { profile.dailyGoal = Int(($0 / 500).rounded()) * 500 })
    }

    private var unitsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Label("Units", systemImage: "ruler")
                    .font(.headline)
                Picker("Units", selection: $profile.units) {
                    ForEach(Units.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.segmented)
                Text("Changes distance, pace, speed, climbing and weight everywhere in the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var healthCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Apple Health", systemImage: "heart.fill")
                    .font(.headline)
                if !health.isAvailable {
                    Text("Apple Health is not available on this device.")
                        .font(.footnote).foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(health.hasRequestedAccess ? Theme.mint : Color.secondary)
                            .frame(width: 10, height: 10)
                        Text(statusText)
                            .font(.subheadline.weight(.semibold))
                    }
                    Text("Stride reads your steps so the total matches the Health app (including an Apple Watch), reads heart rate during walks, and saves each walk as a walking workout with its route.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if health.hasRequestedAccess {
                        Text("To change what Stride can access, open the Health app → your picture → Apps → Stride.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            Task {
                                await health.requestAuthorization()
                                await today.refresh()
                            }
                        } label: {
                            Label("Connect Apple Health", systemImage: "link")
                                .font(.subheadline.weight(.bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.rose)
                    }
                }
            }
        }
    }

    private var statusText: String {
        if health.canSaveWorkouts { return "Connected · workouts will be saved" }
        if health.workoutSharingDenied { return "Connected · workout saving is off" }
        if health.hasRequestedAccess { return "Connected" }
        return "Not connected"
    }

    private var remindersCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Evening nudge", systemImage: "bell.badge")
                    .font(.headline)
                Toggle(isOn: nudgeBinding) {
                    Text("Remind me if I'm short of my goal")
                        .font(.subheadline)
                }
                .tint(Theme.teal)

                if notifications.nudgeEnabled {
                    HStack {
                        Text("Time").font(.subheadline)
                        Spacer()
                        Picker("Hour", selection: $notifications.nudgeHour) {
                            ForEach(15...22, id: \.self) { hour in
                                Text(hourLabel(hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(Theme.teal)
                    }
                    Text("The reminder tells you how many steps are left, using the count from when you last closed the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var nudgeBinding: Binding<Bool> {
        Binding(get: { notifications.nudgeEnabled }, set: { wanted in
            guard wanted else {
                notifications.nudgeEnabled = false
                return
            }
            Task {
                let granted = notifications.authorized || await notifications.requestAuthorization()
                notifications.nudgeEnabled = granted
                if granted {
                    notifications.scheduleNudge(steps: today.steps, goal: profile.dailyGoal)
                } else {
                    message = "Turn on notifications for Stride in Settings to get the evening nudge."
                }
            }
        })
    }

    private func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        let date = Calendar.current.date(from: components) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private var backupCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Backup", systemImage: "icloud.and.arrow.up")
                    .font(.headline)
                Text("Saves your walks and settings to a single file. Choose iCloud Drive and you can restore it on another iPhone.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    Button {
                        backupDocument = BackupService.makeDocument(store: store, profile: profile)
                        showExporter = backupDocument != nil
                    } label: {
                        Label("Back up", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.teal)

                    Button {
                        showImporter = true
                    } label: {
                        Label("Restore", systemImage: "square.and.arrow.down")
                            .font(.subheadline.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.teal)
                }
            }
        }
    }

    private var permissionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Permissions", systemImage: "checkmark.shield")
                    .font(.headline)
                permissionRow(title: "Motion & Fitness", ok: !today.motionDenied, detail: today.motionDenied ? "Off" : "On")
                permissionRow(title: "Location", ok: !session.locationDenied,
                              detail: session.locationDenied ? "Off" : (session.location.isAuthorized ? "On" : "Asked when you start a walk"))
                permissionRow(title: "Notifications", ok: notifications.authorized,
                              detail: notifications.authorized ? "On" : "Off")
                Button("Open Settings") { openSettings() }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(Theme.teal)
            }
        }
    }

    private func permissionRow(title: String, ok: Bool, detail: String) -> some View {
        HStack {
            Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(ok ? Theme.mint : Theme.rose)
            Text(title).font(.subheadline)
            Spacer()
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
    }

    private var aboutCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Label("How calories are estimated", systemImage: "info.circle")
                    .font(.headline)
                Text("Stride multiplies a walking intensity value (a MET, from the Compendium of Physical Activities, chosen by your pace) by your weight and the time you walked. Numbers are estimates, not medical measurements.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if !AppGroup.isShared {
                    Divider()
                    Text("Widgets can't read your steps on this build. That needs the App Groups capability, which a paid Apple Developer account provides.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func importFromHealth() {
        isImporting = true
        Task {
            if !health.hasRequestedAccess {
                await health.requestAuthorization()
            }
            let metrics = await health.fetchBodyMetrics()
            var imported: [String] = []
            if let weight = metrics.weightLb, weight > 40, weight < 800 {
                profile.weightLb = (weight * 10).rounded() / 10
                imported.append("weight")
            }
            if let inches = metrics.heightInches, inches > 36, inches < 96 {
                let total = Int(inches.rounded())
                profile.heightFeet = total / 12
                profile.heightInches = total % 12
                imported.append("height")
            }
            if let gender = metrics.gender {
                profile.gender = gender
                imported.append("sex")
            }
            isImporting = false
            message = imported.isEmpty
                ? "No weight, height or sex found in Apple Health. Add them in the Health app, or make sure Stride is allowed to read them."
                : "Imported \(imported.joined(separator: ", ")) from Apple Health."
        }
    }
}

/// Weight, height and gender controls, shared by Profile and onboarding.
@MainActor
struct BodyInputsForm: View {
    @EnvironmentObject private var profile: UserProfile
    @FocusState private var weightFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label("Weight", systemImage: "scalemass")
                    .font(.subheadline)
                Spacer()
                HStack(spacing: 8) {
                    Button { adjustWeight(by: -1) } label: {
                        Image(systemName: "minus").frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.teal)

                    TextField(profile.units.weightSuffix, value: weightBinding,
                              format: FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...1)))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.center)
                        .font(.headline.monospacedDigit())
                        .frame(width: 70)
                        .padding(.vertical, 6)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .focused($weightFocused)

                    Button { adjustWeight(by: 1) } label: {
                        Image(systemName: "plus").frame(width: 30, height: 30)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.teal)
                }
                Text(profile.units.weightSuffix)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Height", systemImage: "ruler")
                    .font(.subheadline)
                Spacer()
                Picker("Feet", selection: $profile.heightFeet) {
                    ForEach(3...7, id: \.self) { feet in
                        Text("\(feet) ft").tag(feet)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.teal)
                Picker("Inches", selection: $profile.heightInches) {
                    ForEach(0...11, id: \.self) { inches in
                        Text("\(inches) in").tag(inches)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.teal)
            }

            VStack(alignment: .leading, spacing: 6) {
                Label("Gender", systemImage: "person.2")
                    .font(.subheadline)
                Picker("Gender", selection: $profile.gender) {
                    ForEach(Gender.allCases) { gender in
                        Text(gender.label).tag(gender)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { weightFocused = false }
                    .font(.headline)
            }
        }
    }

    private var weightBinding: Binding<Double> {
        Binding(get: { profile.displayWeight },
                set: { profile.displayWeight = $0 })
    }

    private func adjustWeight(by delta: Double) {
        let next = (profile.displayWeight + delta).rounded()
        let lower = profile.units == .metric ? 23.0 : 50.0
        let upper = profile.units == .metric ? 320.0 : 700.0
        profile.displayWeight = min(max(next, lower), upper)
    }
}
