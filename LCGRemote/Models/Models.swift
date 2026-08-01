import Foundation

// MARK: - UnitType

/// Indicates whether a device is an interior or exterior LCG unit.
enum UnitType: String, Codable, Hashable {
    case interior
    case exterior
}

// MARK: - FloorProfile

/// A saved configuration mapping a floor button label to its X, Y, Z motor coordinates.
struct FloorProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    var x: Int   // 0–144
    var y: Int   // 0–208
    var z: Int   // 0–100
    var sortOrder: Int
}

// MARK: - ButtonMap

/// A complete set of FloorProfiles for a simulated Interior Unit.
struct ButtonMap: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var deviceID: String
    var profiles: [FloorProfile]
    var createdDate: Date
    var modifiedDate: Date
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
