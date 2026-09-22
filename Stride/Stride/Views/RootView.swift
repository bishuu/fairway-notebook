import SwiftUI
import WidgetKit

/// Tab bar shell: Today, History, Profile. The live walk opens over the top.
@MainActor
struct RootView: View {
    enum Tab: Hashable { case today, history, profile }

    @EnvironmentObject private var profile: UserProfile
    @EnvironmentObject private var session: WalkSession
    @EnvironmentObject private var today: TodayModel
    @EnvironmentObject private var notifications: NotificationService
    @EnvironmentObject private var intents: IntentBridge
    @Environment(\.scenePhase) private var scenePhase

    @State private var selectedTab: Tab = .today
    @State private var showWalk = false

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(openWalk: { showWalk = true })
                .tabItem { Label("Today", systemImage: "figure.walk") }
                .tag(Tab.today)

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
        }
        .tint(Theme.teal)
        .fullScreenCover(isPresented: $showWalk) {
            WalkView()
        }
        .overlay {
            if !profile.hasOnboarded {
                OnboardingView()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: profile.hasOnboarded)
        .onAppear {
            if profile.hasOnboarded { today.start() }
            Task { await notifications.refreshStatus() }
            // Siri and the widget set these before this view exists on a cold
            // launch, so onChange alone would miss them.
            handlePendingIntents()
        }
        .onChange(of: profile.hasOnboarded) { _, done in
            if done { today.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                Task { await today.refresh() }
            case .background:
                // Re-book tonight's nudge with the numbers as they stand.
                notifications.scheduleNudge(steps: today.steps, goal: profile.dailyGoal)
                today.publishSnapshot(walkActive: session.isRunning, force: true)
                WidgetCenter.shared.reloadAllTimelines()
            default:
                break
            }
        }
        .onChange(of: intents.startWalkRequested) { _, requested in
            if requested { handlePendingIntents() }
        }
        .onChange(of: intents.showTodayRequested) { _, requested in
            if requested { handlePendingIntents() }
        }
        .onOpenURL { url in
            switch url.host {
            case "walk":
                if session.isRunning { showWalk = true }
            default:
                selectedTab = .today
            }
        }
        .alert("Apple Health", isPresented: healthErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(session.healthSaveError ?? "")
        }
    }

    private func handlePendingIntents() {
        if intents.startWalkRequested {
            intents.startWalkRequested = false
            selectedTab = .today
            if !session.isRunning { session.start() }
            showWalk = true
        }
        if intents.showTodayRequested {
            intents.showTodayRequested = false
            selectedTab = .today
        }
    }

    private var healthErrorBinding: Binding<Bool> {
        Binding(get: { session.healthSaveError != nil },
                set: { if !$0 { session.healthSaveError = nil } })
    }
}
