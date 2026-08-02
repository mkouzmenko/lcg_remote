import Foundation
import SwiftUI

/// Mock Bluetooth Low Energy service replacing all real BLE communication.
/// Uses timer-driven state transitions to simulate realistic device interactions.
@MainActor
final class MockBLEService: ObservableObject, BLEServiceProtocol {
    // MARK: - Published Properties

    @Published var discoveredDevices: [BLEDevice] = []
    @Published var isScanning: Bool = false
    @Published var connectedDevice: BLEDevice? = nil
    @Published var connectionState: BLEConnectionState = .disconnected
    @Published var deviceStatus: BLEDeviceStatus = .idle
    @Published var statusMessage: String = ""

    /// Stored call button profile for exterior unit calibration.
    var callButtonProfile: FloorProfile? = FloorProfile(id: UUID(), label: "Call Elevator", x: 50, y: 100, z: 30, sortOrder: 0)

    // MARK: - Configuration

    var commandDuration: TimeInterval = 2.0
    var connectionDelay: TimeInterval = 1.5
    var scanDelay: TimeInterval = 1.5
    private var commandCount: Int = 0

    // MARK: - Scanning

    func startScan() {
        isScanning = true
        discoveredDevices = []

        DispatchQueue.main.asyncAfter(deadline: .now() + scanDelay) { [weak self] in
            guard let self = self, self.isScanning else { return }
            self.discoveredDevices = SeedData.devices
            self.isScanning = false
        }
    }

    func stopScan() {
        isScanning = false
    }

    // MARK: - Connection

    func connect(to device: BLEDevice) {
        connectionState = .connecting
        statusMessage = "Connecting..."

        if device.isReachable {
            DispatchQueue.main.asyncAfter(deadline: .now() + connectionDelay) { [weak self] in
                guard let self = self else { return }
                self.connectedDevice = device
                self.connectionState = .connected
                self.deviceStatus = .idle
                self.statusMessage = "Connected"
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                self.connectionState = .disconnected
                self.connectedDevice = nil
                self.statusMessage = "Connection failed. Device not reachable."
            }
        }
    }

    func disconnect() {
        connectedDevice = nil
        connectionState = .disconnected
        deviceStatus = .idle
        statusMessage = ""
    }

    // MARK: - Elevator Commands

    /// Simulates sending a floor command for an elevator's interior device.
    func sendFloorCommand(elevator: ElevatorConfig, button: FloorButtonConfig) {
        commandCount += 1
        let shouldError = (commandCount % 7 == 0)

        deviceStatus = .busy
        statusMessage = "Connecting..."

        DispatchQueue.main.asyncAfter(deadline: .now() + connectionDelay) { [weak self] in
            guard let self = self else { return }

            // Simulate finding interior device
            let device = SeedData.devices.first(where: { $0.id == elevator.interiorDeviceID })
                ?? BLEDevice(
                    id: elevator.interiorDeviceID ?? "interior-lobby",
                    name: elevator.interiorDeviceName ?? "LiftGateIn-Device",
                    unitType: .interior,
                    rssi: -50,
                    isReachable: true
                )
            self.connectedDevice = device
            self.connectionState = .connected
            self.statusMessage = "Pressing button..."

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }

                if shouldError {
                    self.deviceStatus = .error
                    self.statusMessage = "Command failed. Please retry."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.deviceStatus = .idle
                        self?.statusMessage = ""
                    }
                } else {
                    self.deviceStatus = .done
                    self.statusMessage = "Floor selected"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.deviceStatus = .idle
                        self?.statusMessage = ""
                    }
                }
            }
        }
    }

    /// Simulates sending an exterior call command.
    func sendExteriorCommand(button: ExteriorButtonConfig) {
        commandCount += 1
        let shouldError = (commandCount % 7 == 0)

        deviceStatus = .busy
        statusMessage = "Connecting..."

        DispatchQueue.main.asyncAfter(deadline: .now() + connectionDelay) { [weak self] in
            guard let self = self else { return }

            // Simulate finding exterior device
            let device = SeedData.devices.first(where: { $0.id == button.deviceID })
                ?? BLEDevice(
                    id: button.deviceID ?? "exterior-main",
                    name: button.deviceName ?? "LiftGateEx-Device",
                    unitType: .exterior,
                    rssi: -50,
                    isReachable: true
                )
            self.connectedDevice = device
            self.connectionState = .connected
            self.statusMessage = "Calling elevator..."

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }

                if shouldError {
                    self.deviceStatus = .error
                    self.statusMessage = "Command failed. Please retry."
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        self?.deviceStatus = .idle
                        self?.statusMessage = ""
                    }
                } else {
                    self.deviceStatus = .done
                    self.statusMessage = "Elevator called"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                        self?.deviceStatus = .idle
                        self?.statusMessage = ""
                    }
                }
            }
        }
    }

    // MARK: - Legacy Commands

    func executeFloorCommand(profile: FloorProfile) {
        commandCount += 1
        let shouldError = (commandCount % 5 == 0)

        deviceStatus = .busy
        statusMessage = "Pressing button..."

        DispatchQueue.main.asyncAfter(deadline: .now() + commandDuration) { [weak self] in
            guard let self = self else { return }

            if shouldError {
                self.deviceStatus = .error
                self.statusMessage = "Command failed. Please retry."
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.deviceStatus = .idle
                    self?.statusMessage = ""
                }
            } else {
                self.deviceStatus = .done
                self.statusMessage = "Floor selected"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.deviceStatus = .idle
                    self?.statusMessage = ""
                }
            }
        }
    }

    func executeCallCommand() {
        commandCount += 1
        let shouldError = (commandCount % 5 == 0)

        deviceStatus = .busy
        statusMessage = "Calling elevator..."

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }

            if shouldError {
                self.deviceStatus = .error
                self.statusMessage = "Command failed. Please retry."
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                    self?.deviceStatus = .idle
                    self?.statusMessage = ""
                }
            } else {
                self.deviceStatus = .done
                self.statusMessage = "Elevator called"
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.deviceStatus = .idle
                    self?.statusMessage = ""
                }
            }
        }
    }

    // MARK: - Preset Execution

    func executePresetSequence(
        preset: LocationPreset,
        onPhaseChange: @escaping (PresetPhase) -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        let phases: [(PresetPhase, TimeInterval)] = [
            (.connectingExterior, 1.0),
            (.callingElevator, 2.0),
            (.connectingInterior, 1.0),
            (.selectingFloor, 2.0),
        ]

        executePhases(phases, index: 0, onPhaseChange: onPhaseChange) { success in
            if success {
                onPhaseChange(.done)
            }
            completion(success)
        }
    }

    private func executePhases(
        _ phases: [(PresetPhase, TimeInterval)],
        index: Int,
        onPhaseChange: @escaping (PresetPhase) -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        guard index < phases.count else {
            completion(true)
            return
        }

        let (phase, duration) = phases[index]
        onPhaseChange(phase)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self else {
                completion(false)
                return
            }
            self.executePhases(phases, index: index + 1, onPhaseChange: onPhaseChange, completion: completion)
        }
    }
}

/// Phases of a preset execution sequence.
enum PresetPhase: String {
    case connectingExterior = "Connecting to exterior..."
    case callingElevator = "Calling elevator..."
    case connectingInterior = "Connecting to interior..."
    case selectingFloor = "Selecting floor..."
    case done = "Done"
}
