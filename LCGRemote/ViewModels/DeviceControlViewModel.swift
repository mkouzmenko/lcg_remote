import Foundation
import Combine

/// ViewModel managing the unified Control screen with elevator-based grouping.
/// Shows exterior (call) buttons and floor buttons for the selected elevator.
@MainActor
final class DeviceControlViewModel<Service: BLEServiceProtocol>: ObservableObject {

    // MARK: - Published Properties

    @Published var elevators: [ElevatorConfig] = []
    @Published var selectedElevatorID: UUID?
    @Published var deviceStatus: BLEDeviceStatus = .idle
    @Published var statusMessage: String = ""

    // MARK: - Dependencies

    private let bleService: Service
    private let hapticsService: HapticsService
    private let persistenceService: JSONPersistenceService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Command Tracking

    private enum LastCommand {
        case floor(ElevatorConfig, FloorButtonConfig)
        case exterior(ExteriorButtonConfig)
    }
    private var lastCommand: LastCommand?

    // MARK: - Computed

    var selectedElevator: ElevatorConfig? {
        elevators.first(where: { $0.id == selectedElevatorID })
    }

    var floorButtons: [FloorButtonConfig] {
        selectedElevator?.floorButtons.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []
    }

    var exteriorButtons: [ExteriorButtonConfig] {
        selectedElevator?.exteriorButtons.sorted(by: { $0.sortOrder < $1.sortOrder }) ?? []
    }

    var hasMultipleElevators: Bool {
        elevators.count > 1
    }

    // MARK: - Initialization

    init(bleService: Service, hapticsService: HapticsService, persistenceService: JSONPersistenceService) {
        self.bleService = bleService
        self.hapticsService = hapticsService
        self.persistenceService = persistenceService

        loadElevators()
        self.deviceStatus = bleService.deviceStatus
        self.statusMessage = bleService.statusMessage

        setupBindings()
    }

    // MARK: - Public API

    /// Taps a floor button — auto-connects to elevator's interior device and sends X/Y/Z.
    func tapFloorButton(_ button: FloorButtonConfig) {
        guard deviceStatus == .idle, let elevator = selectedElevator else { return }

        lastCommand = .floor(elevator, button)
        hapticsService.buttonTap()
        bleService.sendFloorCommand(elevator: elevator, button: button)
    }

    /// Taps an exterior button — auto-connects to the button's device and sends X/Y/Z.
    func tapExteriorButton(_ button: ExteriorButtonConfig) {
        guard deviceStatus == .idle else { return }

        lastCommand = .exterior(button)
        hapticsService.buttonTap()
        bleService.sendExteriorCommand(button: button)
    }

    /// Re-executes the last failed command.
    func retryLastCommand() {
        guard let last = lastCommand else { return }
        switch last {
        case .floor(_, let button):
            tapFloorButton(button)
        case .exterior(let button):
            tapExteriorButton(button)
        }
    }

    /// Selects an elevator by ID.
    func selectElevator(_ id: UUID) {
        selectedElevatorID = id
    }

    /// Reloads elevator configs (called when returning from settings).
    func reloadElevators() {
        loadElevators()
    }

    /// Triggers a BLE scan to discover nearby devices.
    func startScan() {
        bleService.startScan()
    }

    /// Disconnects from the current device.
    func disconnect() {
        bleService.disconnect()
    }

    // MARK: - Private

    private func loadElevators() {
        let persisted = persistenceService.loadElevators()
        if persisted.isEmpty {
            elevators = SeedData.defaultElevators
        } else {
            elevators = persisted
        }

        // Select first elevator if nothing selected
        if selectedElevatorID == nil {
            selectedElevatorID = elevators.first?.id
        }
    }

    private func setupBindings() {
        bleService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    let previousStatus = self.deviceStatus
                    let newStatus = self.bleService.deviceStatus
                    self.deviceStatus = newStatus

                    if previousStatus == .busy && newStatus == .done {
                        self.hapticsService.commandSuccess()
                    } else if previousStatus == .busy && newStatus == .error {
                        self.hapticsService.commandError()
                    }

                    self.statusMessage = self.bleService.statusMessage
                }
            }
            .store(in: &cancellables)
    }
}
