import Foundation
import Combine

/// ViewModel managing the Device Control screen.
/// Displays floor buttons for interior units or a call button for exterior units,
/// tracks device status transitions, and provides haptic feedback.
final class DeviceControlViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var connectedDevice: MockDevice?
    @Published var floorProfiles: [FloorProfile] = []
    @Published var deviceStatus: MockBLEService.DeviceStatus = .idle
    @Published var statusMessage: String = ""

    // MARK: - Dependencies

    private let bleService: MockBLEService
    private let hapticsService: HapticsService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Command Tracking

    private enum LastCommand {
        case selectFloor(FloorProfile)
        case callElevator
    }

    private var lastCommand: LastCommand?

    // MARK: - Initialization

    init(bleService: MockBLEService, hapticsService: HapticsService) {
        self.bleService = bleService
        self.hapticsService = hapticsService

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
        // Observe connected device
        bleService.$connectedDevice
            .receive(on: DispatchQueue.main)
            .assign(to: &$connectedDevice)

        // Observe device status and trigger haptics on transitions
        bleService.$deviceStatus
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newStatus in
                guard let self = self else { return }
                let previousStatus = self.deviceStatus
                self.deviceStatus = newStatus

                // Trigger haptics based on status transitions
                if previousStatus == .busy && newStatus == .done {
                    self.hapticsService.commandSuccess()
                } else if previousStatus == .busy && newStatus == .error {
                    self.hapticsService.commandError()
                }
            }
            .store(in: &cancellables)

        // Observe status message
        bleService.$statusMessage
            .receive(on: DispatchQueue.main)
            .assign(to: &$statusMessage)
    }
}
