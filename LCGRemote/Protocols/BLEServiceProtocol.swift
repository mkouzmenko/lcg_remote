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

    // MARK: - Commands

    /// Sends a floor selection command to the connected Interior Unit.
    /// - Parameter profile: The floor profile containing X, Y, Z coordinates.
    func executeFloorCommand(profile: FloorProfile)

    /// Sends an elevator call command to the connected Exterior Unit.
    /// Uses the stored call button profile coordinates if available.
    func executeCallCommand()
    
    /// The stored call button profile (X, Y, Z) for the exterior unit.
    var callButtonProfile: FloorProfile? { get set }

    // MARK: - Preset Execution

    /// Executes a multi-step preset sequence: connect exterior → call → connect interior → select floor.
    /// - Parameters:
    ///   - preset: The location preset defining the exterior/interior devices and target floor.
    ///   - onPhaseChange: Callback invoked when the sequence transitions between phases.
    ///   - completion: Callback invoked with `true` on success or `false` if any step fails.
    func executePresetSequence(
        preset: LocationPreset,
        onPhaseChange: @escaping (PresetPhase) -> Void,
        completion: @escaping (Bool) -> Void
    )
}
