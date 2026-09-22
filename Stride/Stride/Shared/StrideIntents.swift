import AppIntents
import Foundation
import Combine

/// Starts a walk. Used by Siri, the Shortcuts app and the widget's button.
struct StartWalkIntent: AppIntent {
    static var title: LocalizedStringResource = "Start a Walk"
    static var description = IntentDescription("Starts tracking a walk in Stride, with the map and live stats.")
    static var openAppWhenRun: Bool = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentBridge.shared.startWalkRequested = true
        return .result()
    }
}

/// Opens the app straight to today's step count.
struct ShowStepsIntent: AppIntent {
    static var title: LocalizedStringResource = "Show My Steps"
    static var description = IntentDescription("Opens Stride on today's step count.")
    static var openAppWhenRun: Bool = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentBridge.shared.showTodayRequested = true
        return .result()
    }
}

/// Carries a request from Siri or a widget tap into the running app.
@MainActor
final class IntentBridge: ObservableObject {
    static let shared = IntentBridge()

    @Published var startWalkRequested = false
    @Published var showTodayRequested = false

    private init() {}
}
