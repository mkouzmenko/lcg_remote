import Foundation
import Combine

// MARK: - BLEServiceProtocol

/// Unified protocol defining all BLE operations consumed by views and view models.
/// Both `BLEAdapter` (real CoreBluetooth) and `MockBLEService` (simulator) conform to this protocol.
@MainActor
protocol BLEServiceProtocol: ObservableObject {
    // MARK: - Published State

    /// Devices discovered during an active BLE scan.
    var discoveredDevices: [BLEDevice] { get }

    /// Whether a BLE scan is currently in progress.
    var isScanning: Bool { get }

    /// The currently connected device, if any.
    var connectedDevice: BLEDevice? { get }

    /// The current connection lifecycle state.
    var connectionState: BLEConnectionState { get }

    /// The operational status of the connected device (idle, busy, done, error).
    var deviceStatus: BLEDeviceStatus { get }

    /// A human-readable message describing the current status or error.
    var statusMessage: String { get }

    // MARK: - Scanning

    /// Starts scanning for nearby LCG BLE devices.
    func startScan()

    /// Stops the active BLE scan.
    func stopScan()

    // MARK: - Connection

    /// Connects to the specified BLE device.
    /// - Parameter device: The device to connect to.
    func connect(to device: BLEDevice)

    /// Disconnects from the currently connected device.
    func disconnect()

    // MARK: - Elevator Commands

    /// Sends a floor command: connects to the elevator's interior device and sends X/Y/Z.
    /// - Parameters:
    ///   - elevator: The elevator configuration containing the interior device ID.
    ///   - button: The floor button with X/Y/Z coordinates.
    func sendFloorCommand(elevator: ElevatorConfig, button: FloorButtonConfig)

    /// Sends an exterior call command: connects to the button's device and sends X/Y/Z.
    /// - Parameter button: The exterior button with its own device ID and X/Y/Z coordinates.
    func sendExteriorCommand(button: ExteriorButtonConfig)

    // MARK: - Legacy Commands

    /// Sends a floor selection command to the connected Interior Unit.
    /// - Parameter profile: The floor profile containing X, Y, Z coordinates.
    func executeFloorCommand(profile: FloorProfile)

    /// Sends an elevator call command to the connected Exterior Unit.
    func executeCallCommand()

    /// The stored call button profile (X, Y, Z) for the exterior unit.
    var callButtonProfile: FloorProfile? { get set }

    // MARK: - Preset Execution

    /// Executes a multi-step preset sequence: connect exterior → call → connect interior → select floor.
    func executePresetSequence(
        preset: LocationPreset,
        onPhaseChange: @escaping (PresetPhase) -> Void,
        completion: @escaping (Bool) -> Void
    )
}
