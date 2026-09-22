import Foundation
import UserNotifications
import Combine

/// The evening nudge: a reminder when the daily goal is still within reach.
@MainActor
final class NotificationService: ObservableObject {
    private enum Keys {
        static let enabled = "notify.eveningNudge"
        static let hour = "notify.hour"
    }

    @Published var nudgeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(nudgeEnabled, forKey: Keys.enabled)
            if !nudgeEnabled { cancel() }
        }
    }
    @Published var nudgeHour: Int {
        didSet { UserDefaults.standard.set(nudgeHour, forKey: Keys.hour) }
    }
    @Published private(set) var authorized = false

    private let identifier = "stride.eveningNudge"

    init() {
        nudgeEnabled = UserDefaults.standard.bool(forKey: Keys.enabled)
        nudgeHour = UserDefaults.standard.object(forKey: Keys.hour) as? Int ?? 19
    }

    func refreshStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        authorized = granted
        return granted
    }

    /// Re-books tonight's reminder with the numbers as they stand now.
    /// Called when the app goes to the background, so the wording is current.
    func scheduleNudge(steps: Int, goal: Int) {
        cancel()
        guard nudgeEnabled, authorized, goal > 0 else { return }

        let remaining = max(goal - steps, 0)
        let content = UNMutableNotificationContent()
        content.sound = .default
        if remaining == 0 {
            content.title = "Goal complete"
            content.body = "\(Format.steps(steps)) steps today. Nice work."
        } else if remaining <= 2500 {
            content.title = "So close"
            content.body = "\(Format.steps(remaining)) steps to go. A quick loop around the block would do it."
        } else {
            content.title = "Time for a walk?"
            content.body = "You're at \(Format.steps(steps)) steps. \(Format.steps(remaining)) to reach your goal."
        }

        var components = DateComponents()
        components.hour = nudgeHour
        components.minute = 0
        // Fires once. The app re-books it on every backgrounding, so the
        // wording always reflects the latest step count.
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
