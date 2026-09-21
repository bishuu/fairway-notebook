import SwiftUI

/// Tab bar shell: Today, History, Profile. The live walk opens over the top.
@MainActor
struct RootView: View {
    enum Tab: Hashable { case today, history, profile }

    @EnvironmentObject private var profile: UserProfile
    @EnvironmentObject private var session: WalkSession
    @EnvironmentObject private var today: TodayModel

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
        }
        .onChange(of: profile.hasOnboarded) { _, done in
            if done { today.start() }
        }
        .alert("Apple Health", isPresented: healthErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(session.healthSaveError ?? "")
        }
    }

    private var healthErrorBinding: Binding<Bool> {
        Binding(get: { session.healthSaveError != nil },
                set: { if !$0 { session.healthSaveError = nil } })
    }
}
