import AppIntents
import Foundation

// MARK: - ElevatorEntity

/// An App Entity representing an Elevator for use in Siri Shortcuts.
@available(iOS 16.0, macOS 13.0, *)
struct ElevatorEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Elevator"

    static var defaultQuery = ElevatorEntityQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }

    init(from elevator: ElevatorConfig) {
        self.id = elevator.id
        self.name = elevator.name
    }
}

// MARK: - ElevatorEntityQuery

@available(iOS 16.0, macOS 13.0, *)
struct ElevatorEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [ElevatorEntity] {
        let allElevators = loadElevators()
        let idSet = Set(identifiers)
        return allElevators
            .filter { idSet.contains($0.id) }
            .map { ElevatorEntity(from: $0) }
    }

    func suggestedEntities() async throws -> [ElevatorEntity] {
        let allElevators = loadElevators()
        return allElevators.map { ElevatorEntity(from: $0) }
    }

    private func loadElevators() -> [ElevatorConfig] {
        let service = JSONPersistenceService()
        let persisted = service.loadElevators()
        if persisted.isEmpty {
            return SeedData.defaultElevators
        }
        return persisted
    }
}

// MARK: - CallElevatorIntent

/// Siri Shortcut intent that calls the elevator.
@available(iOS 16.0, macOS 13.0, *)
struct CallElevatorIntent: AppIntent {
    static var title: LocalizedStringResource = "Call Elevator"
    static var description = IntentDescription("Call the elevator using a configured elevator")

    @Parameter(title: "Elevator")
    var elevator: ElevatorEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Call elevator \(\.$elevator)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let elevator = elevator else {
            return .result(dialog: "No elevator selected. Please choose an elevator.")
        }

        donateActivity(elevatorName: elevator.name, action: "callElevator")

        return .result(dialog: "Calling elevator \(elevator.name)...")
    }

    private func donateActivity(elevatorName: String, action: String) {
        let activity = NSUserActivity(activityType: "com.lcgremote.callElevator")
        activity.title = "Call Elevator — \(elevatorName)"
        activity.isEligibleForSearch = true
        #if os(iOS) || os(watchOS)
        activity.isEligibleForPrediction = true
        #endif
        activity.becomeCurrent()
    }
}

// MARK: - GoToFloorIntent

/// Siri Shortcut intent that sends the user to a specific floor.
@available(iOS 16.0, macOS 13.0, *)
struct GoToFloorIntent: AppIntent {
    static var title: LocalizedStringResource = "Go to Floor"
    static var description = IntentDescription("Go to a floor using a configured elevator")

    @Parameter(title: "Elevator")
    var elevator: ElevatorEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Go to floor with \(\.$elevator)")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let elevator = elevator else {
            return .result(dialog: "No elevator selected. Please choose an elevator.")
        }

        donateActivity(elevatorName: elevator.name, action: "goToFloor")

        return .result(dialog: "Going to floor with \(elevator.name)...")
    }

    private func donateActivity(elevatorName: String, action: String) {
        let activity = NSUserActivity(activityType: "com.lcgremote.goToFloor")
        activity.title = "Go to Floor — \(elevatorName)"
        activity.isEligibleForSearch = true
        #if os(iOS) || os(watchOS)
        activity.isEligibleForPrediction = true
        #endif
        activity.becomeCurrent()
    }
}
