import SwiftUI

@main
struct StrideApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(container.profile)
                .environmentObject(container.store)
                .environmentObject(container.health)
                .environmentObject(container.today)
                .environmentObject(container.session)
                .environmentObject(container.notifications)
                .environmentObject(container.intents)
        }
    }
}

/// Builds the shared services and models once and keeps them alive.
@MainActor
final class AppContainer: ObservableObject {
    let profile: UserProfile
    let store: WalkStore
    let health: HealthKitService
    let today: TodayModel
    let session: WalkSession
    let notifications: NotificationService
    let intents: IntentBridge

    init() {
        let profile = UserProfile()
        let store = WalkStore()
        let health = HealthKitService()
        self.profile = profile
        self.store = store
        self.health = health
        today = TodayModel(pedometer: PedometerService(), health: health, profile: profile)
        session = WalkSession(location: LocationService(),
                              pedometer: PedometerService(),
                              health: health,
                              profile: profile,
                              store: store)
        notifications = NotificationService()
        intents = IntentBridge.shared
    }
}
