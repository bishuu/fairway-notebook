import SwiftUI

/// Body inputs, daily goal, Apple Health connection and permissions.
struct ProfileView: View {
    @EnvironmentObject private var profile: UserProfile
    @EnvironmentObject private var health: HealthKitService
    @EnvironmentObject private var today: TodayModel
    @EnvironmentObject private var session: WalkSession

    @State private var importMessage: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        bodyCard
                        goalCard
                        healthCard
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
        .alert("Apple Health", isPresented: Binding(get: { importMessage != nil }, set: { if !$0 { importMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importMessage ?? "")
        }
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
                    Text("Stride reads your steps so the total matches the Health app (including an Apple Watch), and saves each walk as a walking workout with its route.")
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

    private var permissionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Permissions", systemImage: "checkmark.shield")
                    .font(.headline)
                permissionRow(title: "Motion & Fitness", ok: !today.motionDenied, detail: today.motionDenied ? "Off" : "On")
                permissionRow(title: "Location", ok: !session.locationDenied, detail: session.locationDenied ? "Off" : (session.location.isAuthorized ? "On" : "Asked when you start a walk"))
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
            importMessage = imported.isEmpty
                ? "No weight, height or sex found in Apple Health. Add them in the Health app, or make sure Stride is allowed to read them."
                : "Imported \(imported.joined(separator: ", ")) from Apple Health."
        }
    }
}

/// Weight, height and gender controls, shared by Profile and onboarding.
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

                    TextField("lb", value: $profile.weightLb, format: .number.precision(.fractionLength(0...1)))
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
                Text("lb")
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

    private func adjustWeight(by delta: Double) {
        profile.weightLb = min(max((profile.weightLb + delta).rounded(), 50), 700)
    }
}
