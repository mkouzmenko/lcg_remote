import Foundation
import Combine

/// ViewModel managing the unified Control screen.
/// Shows all buttons (call + floors) on one screen. Each button auto-connects
/// to its configured BLE device and sends X/Y/Z coordinates.
@MainActor
final class DeviceControlViewModel<Service: BLEServiceProtocol>: ObservableObject {

    // MARK: - Published Properties

    @Published var buttonConfigs: [ButtonConfig] = []
    @Published var deviceStatus: BLEDeviceStatus = .idle
    @Published var statusMessage: String = ""

    // MARK: - Dependencies

    private let bleService: Service
    private let hapticsService: HapticsService
    private let persistenceService: JSONPersistenceService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Command Tracking

    private var lastButtonConfig: ButtonConfig?

    // MARK: - Computed

    var connectedDevice: BLEDevice? {
        bleService.connectedDevice
    }

    // MARK: - Initialization

    init(bleService: Service, hapticsService: HapticsService, persistenceService: JSONPersistenceService) {
        self.bleService = bleService
        self.hapticsService = hapticsService
        self.persistenceService = persistenceService

        loadButtonConfigs()
        self.deviceStatus = bleService.deviceStatus
        self.statusMessage = bleService.statusMessage

        setupBindings()
    }

    /// Convenience init without persistenceService for backward compatibility.
    init(bleService: Service, hapticsService: HapticsService) {
        self.bleService = bleService
        self.hapticsService = hapticsService
        self.persistenceService = JSONPersistenceService()

        loadButtonConfigs()
        self.deviceStatus = bleService.deviceStatus
        self.statusMessage = bleService.statusMessage

        setupBindings()
    }

    // MARK: - Public API

    /// Taps a button — auto-connects to the configured device and sends X/Y/Z.
    func tapButton(_ config: ButtonConfig) {
        guard deviceStatus == .idle else { return }

        lastButtonConfig = config
        hapticsService.buttonTap()
        bleService.sendCommand(buttonConfig: config)
    }

    /// Re-executes the last failed command.
    func retryLastCommand() {
        guard let config = lastButtonConfig else { return }
        tapButton(config)
    }

    /// Disconnects from the current device.
    func disconnect() {
        bleService.disconnect()
    }

    /// Reloads button configs (called when returning from settings/calibration).
    func reloadButtonConfigs() {
        loadButtonConfigs()
    }

    /// Triggers a BLE scan to discover nearby devices.
    func startScan() {
        bleService.startScan()
    }

    /// Legacy support: select floor via FloorProfile.
    func selectFloor(_ profile: FloorProfile) {
        let config = ButtonConfig(
            id: profile.id,
            label: profile.label,
            deviceType: .interior,
            x: profile.x,
            y: profile.y,
            z: profile.z,
            sortOrder: profile.sortOrder
        )
        tapButton(config)
    }

    /// Legacy support: call elevator.
    func callElevator() {
        if let callConfig = buttonConfigs.first(where: { $0.deviceType == .exterior }) {
            tapButton(callConfig)
        }
    }

    // MARK: - Private

    private func loadButtonConfigs() {
        let persisted = persistenceService.loadButtonConfigs()
        if persisted.isEmpty {
            buttonConfigs = SeedData.defaultButtonConfigs
        } else {
            buttonConfigs = persisted.sorted(by: { $0.sortOrder < $1.sortOrder })
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
