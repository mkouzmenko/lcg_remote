import Combine
import Foundation

/// ViewModel driving the Settings View. Manages elevator configurations,
/// diagnostics log display, and reset operations.
@MainActor
final class SettingsViewModel<Service: BLEServiceProtocol>: ObservableObject {
    // MARK: - Published Properties

    @Published var elevators: [ElevatorConfig] = []
    @Published var diagnosticsLog: [DiagnosticsEntry] = []

    // MARK: - Dependencies

    private let persistenceService: JSONPersistenceService
    private let bleService: Service
    private var cancellables = Set<AnyCancellable>()

    /// UserDefaults key used by OnboardingViewModel to track onboarding completion.
    private static var onboardingCompletedKey: String { "hasCompletedOnboarding" }

    // MARK: - Initializer

    init(persistenceService: JSONPersistenceService, bleService: Service) {
        self.persistenceService = persistenceService
        self.bleService = bleService

        loadElevators()
        loadDiagnostics()
    }

    // MARK: - Elevator Management

    /// Adds a new elevator with default configuration.
    func addElevator() {
        let elevatorNumber = elevators.count + 1
        let name = elevatorNumber == 1 ? "Elevator A" : "Elevator \(Character(UnicodeScalar(64 + elevatorNumber)!))"
        let newElevator = ElevatorConfig(
            id: UUID(),
            name: name,
            interiorDeviceID: nil,
            interiorDeviceName: nil,
            floorButtons: [
                FloorButtonConfig(id: UUID(), label: "Lobby", x: 10, y: 20, z: 30, sortOrder: 0),
                FloorButtonConfig(id: UUID(), label: "1", x: 10, y: 50, z: 30, sortOrder: 1),
            ],
            exteriorButtons: [
                ExteriorButtonConfig(id: UUID(), label: "Call Elevator", deviceID: nil, deviceName: nil, x: 50, y: 100, z: 30, sortOrder: 0),
            ]
        )
        elevators.append(newElevator)
        persist()
    }

    /// Updates an existing elevator.
    func updateElevator(_ elevator: ElevatorConfig) {
        if let index = elevators.firstIndex(where: { $0.id == elevator.id }) {
            elevators[index] = elevator
            persist()
        }
    }

    /// Deletes an elevator.
    func deleteElevator(_ elevator: ElevatorConfig) {
        elevators.removeAll { $0.id == elevator.id }
        persist()
    }

    // MARK: - Reset Operations

    /// Clears the onboarding completion flag so the onboarding flow is shown on next launch.
    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: Self.onboardingCompletedKey)
    }

    /// Clears all persisted JSON data, restoring hardcoded defaults.
    func resetAllData() {
        do {
            try persistenceService.resetAllData()
        } catch {
            // Reset error — non-fatal for prototype
        }

        // Reload from seed data
        loadElevators()
    }

    // MARK: - Private Helpers

    private func loadElevators() {
        let persisted = persistenceService.loadElevators()
        if persisted.isEmpty {
            elevators = SeedData.defaultElevators
        } else {
            elevators = persisted
        }
    }

    private func loadDiagnostics() {
        diagnosticsLog = SeedData.sampleDiagnostics
    }

    private func persist() {
        try? persistenceService.saveElevators(elevators)
    }
}
