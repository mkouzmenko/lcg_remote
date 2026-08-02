import Foundation

// MARK: - UnitType

/// Indicates whether a device is an interior or exterior LCG unit.
enum UnitType: String, Codable, Hashable {
    case interior
    case exterior
}

// MARK: - ElevatorConfig

/// Top-level configuration for a single elevator.
/// Groups an interior device (shared by all floor buttons) with floor and exterior buttons.
struct ElevatorConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String                        // e.g., "Elevator A"
    var interiorDeviceID: String?           // BLE device for interior (shared by all floor buttons)
    var interiorDeviceName: String?         // Display name
    var floorButtons: [FloorButtonConfig]   // Lobby, 1, 2, 3...
    var exteriorButtons: [ExteriorButtonConfig]  // Call F1, Call F2...
}

// MARK: - FloorButtonConfig

/// Configuration for a single floor button inside the elevator.
/// All floor buttons share the elevator's interior BLE device.
struct FloorButtonConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String       // "Lobby", "1", "2"...
    var x: Int              // 0-250
    var y: Int              // 0-250
    var z: Int              // 0-250
    var sortOrder: Int
}

// MARK: - ExteriorButtonConfig

/// Configuration for an exterior call button (e.g., hallway call button).
/// Each exterior button can have its own BLE device.
struct ExteriorButtonConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String       // "Call F1", "Call F2"...
    var deviceID: String?   // Specific BLE device for this button
    var deviceName: String? // Display name
    var x: Int              // 0-250
    var y: Int              // 0-250
    var z: Int              // 0-250
    var sortOrder: Int
}

// MARK: - FloorProfile (Legacy)

/// A saved configuration mapping a floor button label to its X, Y, Z motor coordinates.
/// Kept for backward compatibility with persistence and calibration.
struct FloorProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    var x: Int   // 0–250
    var y: Int   // 0–250
    var z: Int   // 0–250
    var sortOrder: Int
}

// MARK: - LocationPreset

/// A user-defined favorite combining an Exterior Unit, Interior Unit, and target floor.
struct LocationPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var exteriorDeviceID: String?
    var interiorDeviceID: String?
    var targetFloorProfileID: UUID?
    var usageCount: Int = 0
    var sortOrder: Int
}

// MARK: - Outcome

/// The result of a simulated command execution.
enum Outcome: String, Codable, Hashable {
    case success
    case error
    case timeout
}

// MARK: - DiagnosticsEntry

/// A log entry recording a command execution result.
struct DiagnosticsEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let deviceName: String
    let commandType: String
    let outcome: Outcome
}
