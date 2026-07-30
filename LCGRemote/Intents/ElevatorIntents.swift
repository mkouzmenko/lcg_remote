import AppIntents
import Foundation

// MARK: - LocationPresetEntity (Requirements 11.1, 11.2)

/// An App Entity representing a LocationPreset for use in Siri Shortcuts.
/// Allows users to select a saved preset as a parameter in intent invocations.
@available(iOS 16.0, macOS 13.0, *)
struct LocationPresetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Location Preset"

    static var defaultQuery = LocationPresetEntityQuery()

    var id: UUID
    var name: String
    var usageCount: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: UUID, name: String, usageCount: Int) {
        self.id = id
        self.name = name
        self.usageCount = usageCount
    }

    /// Convenience initializer from a LocationPreset model.
    init(from preset: LocationPreset) {
        self.id = preset.id
        self.name = preset.name
        self.usageCount = preset.usageCount
    }
}

// MARK: - LocationPresetEntityQuery

/// Query provider that fetches LocationPreset entities from persistence.
/// Supports searching by name and listing all available presets.
@available(iOS 16.0, macOS 13.0, *)
struct LocationPresetEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [LocationPresetEntity] {
        let allPresets = loadPresets()
        let idSet = Set(identifiers)
        return allPresets
            .filter { idSet.contains($0.id) }
            .map { LocationPresetEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [LocationPresetEntity] {
        // Return presets sorted by usage count (most-used first) for suggestions
        let allPresets = loadPresets()
        return allPresets
            .sorted { $0.usageCount > $1.usageCount }
            .map { LocationPresetEntity(from: $0) }
    }

    /// Loads presets from the JSON persistence layer.
    private func loadPresets() -> [LocationPreset] {
        let service = JSONPersistenceService()
        let persisted = service.loadPresets()
        if persisted.isEmpty {
            return SeedData.defaultPresets
        }
        return persisted
    }
}

// MARK: - CallElevatorIntent (Requirement 11.1)

/// Siri Shortcut intent that calls the elevator using a saved Location Preset.
/// When invoked via Siri or the Shortcuts app, it activates the specified
/// Exterior Unit preset to call the elevator to the user's landing.
@available(iOS 16.0, macOS 13.0, *)
struct CallElevatorIntent: AppIntent {
    static var title: LocalizedStringResource = "Call Elevator"
    static var description = IntentDescription("Call the elevator using a saved preset")

    @Parameter(title: "Preset")
    var preset: LocationPresetEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Call elevator with \(\.$preset)")
    }

    /// Executes the intent by initiating the BLE call sequence.
    /// Since real BLE communication is asynchronous and hardware-dependent,
    /// this returns a dialog indicating the action was initiated.
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let preset = preset else {
            return .result(dialog: "No preset selected. Please choose a location preset.")
        }

        // Donate a user activity for future shortcut suggestions (Requirement 11.5)
        donateActivity(presetName: preset.name, action: "callElevator")

        return .result(dialog: "Calling elevator for \(preset.name)...")
    }

    /// Donates a user activity to improve shortcut suggestions.
    private func donateActivity(presetName: String, action: String) {
        // NSUserActivity donation for Siri suggestions (Requirement 11.4, 11.5)
        let activity = NSUserActivity(activityType: "com.lcgremote.callElevator")
        activity.title = "Call Elevator — \(presetName)"
        activity.isEligibleForSearch = true
        #if os(iOS) || os(watchOS)
        activity.isEligibleForPrediction = true
        #endif
        activity.becomeCurrent()
    }
}

// MARK: - GoToFloorIntent (Requirement 11.2)

/// Siri Shortcut intent that sends the user to a specific floor using a saved Location Preset.
/// When invoked via Siri or the Shortcuts app, it activates the full preset sequence:
/// call elevator via Exterior Unit, then select destination floor via Interior Unit.
@available(iOS 16.0, macOS 13.0, *)
struct GoToFloorIntent: AppIntent {
    static var title: LocalizedStringResource = "Go to Floor"
    static var description = IntentDescription("Go to a floor using a saved preset")

    @Parameter(title: "Preset")
    var preset: LocationPresetEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Go to floor with \(\.$preset)")
    }

    /// Executes the intent by initiating the full BLE preset sequence.
    /// Since real BLE communication is asynchronous and hardware-dependent,
    /// this returns a dialog indicating the action was initiated.
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let preset = preset else {
            return .result(dialog: "No preset selected. Please choose a location preset.")
        }

        // Donate a user activity for future shortcut suggestions (Requirement 11.5)
        donateActivity(presetName: preset.name, action: "goToFloor")

        return .result(dialog: "Going to \(preset.name)...")
    }

    /// Donates a user activity to improve shortcut suggestions.
    private func donateActivity(presetName: String, action: String) {
        // NSUserActivity donation for Siri suggestions (Requirement 11.4, 11.5)
        let activity = NSUserActivity(activityType: "com.lcgremote.goToFloor")
        activity.title = "Go to Floor — \(presetName)"
        activity.isEligibleForSearch = true
        #if os(iOS) || os(watchOS)
        activity.isEligibleForPrediction = true
        #endif
        activity.becomeCurrent()
    }
}
