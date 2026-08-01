import Foundation
import Combine

/// ViewModel managing the Device Control screen.
/// Displays floor buttons for interior units or a call button for exterior units,
/// tracks device status transitions, and provides haptic feedback.
@MainActor
final class DeviceControlViewModel<Service: BLEServiceProtocol>: ObservableObject {

    // MARK: - Published Properties

    @Published var connectedDevice: BLEDevice?
    @Published var floorProfiles: [FloorProfile] = []
    @Published var deviceStatus: BLEDeviceStatus = .idle
    @Published var statusMessage: String = ""

    // MARK: - Dependencies

    private let bleService: Service
    private let hapticsService: HapticsService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Command Tracking

    private enum LastCommand {
        case selectFloor(FloorProfile)
        case callElevator
    }

    private var lastCommand: LastCommand?

    // MARK: - Initialization

    init(bleService: Service, hapticsService: HapticsService) {
        self.bleService = bleService
        self.hapticsService = hapticsService

        // Set initial values from service
        self.connectedDevice = bleService.connectedDevice
        self.deviceStatus = bleService.deviceStatus
        self.statusMessage = bleService.statusMessage

        setupBindings()
    }

    // MARK: - Public API

    /// Selects a floor by executing the corresponding BLE command.
    /// Triggers a button tap haptic immediately and tracks the command for retry.
    func selectFloor(_ profile: FloorProfile) {
        guard deviceStatus == .idle else { return }
        lastCommand = .selectFloor(profile)
        hapticsService.buttonTap()
        bleService.executeFloorCommand(profile: profile)
    }

    /// Calls the elevator for exterior units.
    /// Triggers a button tap haptic immediately and tracks the command for retry.
    func callElevator() {
        guard deviceStatus == .idle else { return }
        lastCommand = .callElevator
        hapticsService.buttonTap()
        bleService.executeCallCommand()
    }

    /// Disconnects from the currently connected device.
    func disconnect() {
        bleService.disconnect()
    }

    /// Re-executes the last failed command.
    /// Only meaningful when the device is in error or idle state after an error.
    func retryLastCommand() {
        guard let command = lastCommand else { return }
        switch command {
        case .selectFloor(let profile):
            hapticsService.buttonTap()
            bleService.executeFloorCommand(profile: profile)
        case .callElevator:
            hapticsService.buttonTap()
            bleService.executeCallCommand()
        }
    }

    // MARK: - Private

    private func setupBindings() {
        bleService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.connectedDevice = self.bleService.connectedDevice

                    let previousStatus = self.deviceStatus
                    let newStatus = self.bleService.deviceStatus
                    self.deviceStatus = newStatus

                    // Trigger haptics based on status transitions
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
