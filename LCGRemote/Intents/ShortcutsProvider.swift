import AppIntents
import Foundation

// MARK: - LCGShortcutsProvider (Requirement 11.4, 11.5)

/// Registers LCG Remote intents with the Shortcuts app for visibility and discovery.
/// Provides default shortcut phrases so users can invoke commands without manual setup.
/// Shortcut suggestions are based on the user's most frequently used presets.
@available(iOS 16.0, macOS 13.0, *)
struct LCGShortcutsProvider: AppShortcutsProvider {
    /// The app shortcuts exposed in the Shortcuts app and Siri suggestions.
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CallElevatorIntent(),
            phrases: [
                "Call elevator with \(.applicationName)",
                "Call the elevator using \(.applicationName)",
                "Use \(.applicationName) to call elevator"
            ],
            shortTitle: "Call Elevator",
            systemImageName: "arrow.up.square"
        )

        AppShortcut(
            intent: GoToFloorIntent(),
            phrases: [
                "Go to floor with \(.applicationName)",
                "Take me to a floor using \(.applicationName)",
                "Use \(.applicationName) to go to floor"
            ],
            shortTitle: "Go to Floor",
            systemImageName: "building.2"
        )
    }
}
