import Foundation

#if canImport(SwiftData)
import SwiftData

// MARK: - SwiftData Models for LCG Remote (iOS 17+ / macOS 14+)
// These @Model classes provide persistent storage via SwiftData.
// The prototype's Codable structs in Models.swift remain for iOS 16 / Simulator use.
// Models are prefixed with "SD" to avoid naming conflicts with the prototype structs.

// MARK: - SDSavedDevice

/// A BLE device the user has previously paired with.
/// Validates: Requirements 5.5, 13.5
@available(iOS 17, macOS 14, *)
@Model
final class SDSavedDevice {

    /// The unit type classification for LCG hardware.
    enum UnitType: String, Codable {
        case interior
        case exterior
    }

    @Attribute(.unique) var deviceUUID: UUID
    var customName: String
    var unitType: UnitType
    var lastSeenDate: Date
    var bleIdentifier: String

    init(
        deviceUUID: UUID = UUID(),
        customName: String,
        unitType: UnitType,
        lastSeenDate: Date = Date(),
        bleIdentifier: String
    ) {
        self.deviceUUID = deviceUUID
        self.customName = customName
        self.unitType = unitType
        self.lastSeenDate = lastSeenDate
        self.bleIdentifier = bleIdentifier
    }
}

// MARK: - SDButtonMap

/// A complete set of FloorProfiles for a specific Interior Unit.
/// Validates: Requirements 5.5
@available(iOS 17, macOS 14, *)
@Model
final class SDButtonMap {

    @Attribute(.unique) var id: UUID
    var deviceUUID: UUID
    var name: String
    @Relationship(deleteRule: .cascade, inverse: \SDFloorProfile.buttonMap)
    var floorProfiles: [SDFloorProfile]
    var createdDate: Date
    var modifiedDate: Date

    init(
        id: UUID = UUID(),
        deviceUUID: UUID,
        name: String,
        floorProfiles: [SDFloorProfile] = [],
        createdDate: Date = Date(),
        modifiedDate: Date = Date()
    ) {
        self.id = id
        self.deviceUUID = deviceUUID
        self.name = name
        self.floorProfiles = floorProfiles
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
    }
}

// MARK: - SDFloorProfile

/// A calibrated button position mapping a floor label to X, Y, Z motor coordinates.
/// Validates: Requirements 5.5
@available(iOS 17, macOS 14, *)
@Model
final class SDFloorProfile {

    @Attribute(.unique) var id: UUID
    var label: String
    /// Horizontal motor duration (0–144)
    var x: Int
    /// Vertical motor duration (0–208)
    var y: Int
    /// Push motor duration (0–100)
    var z: Int
    var sortOrder: Int
    var buttonMap: SDButtonMap?

    init(
        id: UUID = UUID(),
        label: String,
        x: Int,
        y: Int,
        z: Int,
        sortOrder: Int = 0,
        buttonMap: SDButtonMap? = nil
    ) {
        precondition((0...144).contains(x), "x must be 0–144")
        precondition((0...208).contains(y), "y must be 0–208")
        precondition((0...100).contains(z), "z must be 0–100")
        self.id = id
        self.label = label
        self.x = x
        self.y = y
        self.z = z
        self.sortOrder = sortOrder
        self.buttonMap = buttonMap
    }
}

// MARK: - SDLocationPreset

/// A user-defined favorite combining an Exterior Unit, Interior Unit, and target floor.
/// Validates: Requirements 6.1
@available(iOS 17, macOS 14, *)
@Model
final class SDLocationPreset {

    @Attribute(.unique) var id: UUID
    var name: String
    var exteriorDeviceUUID: UUID?
    var interiorDeviceUUID: UUID?
    var targetFloorProfileID: UUID?
    var usageCount: Int
    var lastUsedDate: Date?
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        exteriorDeviceUUID: UUID? = nil,
        interiorDeviceUUID: UUID? = nil,
        targetFloorProfileID: UUID? = nil,
        usageCount: Int = 0,
        lastUsedDate: Date? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.exteriorDeviceUUID = exteriorDeviceUUID
        self.interiorDeviceUUID = interiorDeviceUUID
        self.targetFloorProfileID = targetFloorProfileID
        self.usageCount = usageCount
        self.lastUsedDate = lastUsedDate
        self.sortOrder = sortOrder
    }
}

// MARK: - SDCommandLogEntry

/// A log entry recording a command execution result for diagnostics.
/// Validates: Requirements 16.4
@available(iOS 17, macOS 14, *)
@Model
final class SDCommandLogEntry {

    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var deviceUUID: UUID
    /// Command type identifier: "floorSelect", "callElevator", "goHome", "componentTest"
    var commandType: String
    /// JSON-encoded parameters string
    var parameters: String
    /// Outcome of the command: "success", "error", "timeout"
    var outcome: String
    /// Optional error description when outcome is not success
    var errorDescription: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        deviceUUID: UUID,
        commandType: String,
        parameters: String = "{}",
        outcome: String,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.deviceUUID = deviceUUID
        self.commandType = commandType
        self.parameters = parameters
        self.outcome = outcome
        self.errorDescription = errorDescription
    }
}

#endif
