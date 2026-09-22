import AppIntents

/// The phrases Siri listens for, and the entries in the Shortcuts app.
struct StrideShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartWalkIntent(),
            phrases: [
                "Start a walk in \(.applicationName)",
                "Start a \(.applicationName) walk",
                "Begin a walk in \(.applicationName)",
                "Track my walk with \(.applicationName)"
            ],
            shortTitle: "Start a Walk",
            systemImageName: "figure.walk.motion"
        )
        AppShortcut(
            intent: ShowStepsIntent(),
            phrases: [
                "Show my steps in \(.applicationName)",
                "Check my \(.applicationName) steps",
                "Open \(.applicationName) steps"
            ],
            shortTitle: "Show Steps",
            systemImageName: "figure.walk"
        )
    }
}
