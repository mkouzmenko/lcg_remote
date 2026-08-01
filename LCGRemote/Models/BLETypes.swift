import Foundation
#if canImport(CoreBluetooth)
import CoreBluetooth
#endif

// MARK: - CommandError

/// Errors that can occur during BLE command encoding and transmission.
enum CommandError: LocalizedError {
    case xExceedsMax
    case yExceedsMax
    case zExceedsMax
    case notConnected
    case writeFailure(underlying: Error)
    case timeout
    case firmwareTimeout
    case deviceError

    var errorDescription: String? {
        switch self {
        case .xExceedsMax:
            return "X coordinate exceeds maximum value of 250"
        case .yExceedsMax:
            return "Y coordinate exceeds maximum value of 250"
        case .zExceedsMax:
            return "Z coordinate exceeds maximum value of 250"
        case .notConnected:
            return "Not connected to a BLE device"
        case .writeFailure(let underlying):
            return "BLE write failed: \(underlying.localizedDescription)"
        case .timeout:
            return "Command timed out waiting for response"
        case .firmwareTimeout:
            return "Firmware did not receive all parameters within 5 seconds"
        case .deviceError:
            return "Device reported an error"
        }
    }
}

// MARK: - BLEConstants

/// BLE UUID constants for LCG Interior and Exterior units.
enum BLEConstants {
    /// Shared service UUID for all LCG units (Interior and Exterior)
    static let lcgServiceUUID = "19B10001-E8F2-537E-4F6C-D104768A1211"
    /// Shared characteristic UUID for status notifications
    static let lcgStatusUUID = "19B10002-E8F2-537E-4F6C-D104768A1211"

    /// Legacy UUIDs (kept for backward compatibility)
    static let interiorServiceUUID = "19B10001-E8F2-537E-4F6C-D104768A1211"
    static let interiorStatusUUID = "19B10002-E8F2-537E-4F6C-D104768A1211"
    static let exteriorServiceUUID = "19B10001-E8F2-537E-4F6C-D104768A1211"
    static let exteriorStatusUUID = "19B10002-E8F2-537E-4F6C-D104768A1211"

    #if canImport(CoreBluetooth)
    /// CBUUID for the shared LCG service
    static let lcgServiceCBUUID = CBUUID(string: lcgServiceUUID)
    /// CBUUID for the shared status characteristic
    static let lcgStatusCBUUID = CBUUID(string: lcgStatusUUID)
    /// CBUUID for Interior service (same as shared)
    static let interiorServiceCBUUID = CBUUID(string: interiorServiceUUID)
    /// CBUUID for Interior status characteristic
    static let interiorStatusCBUUID = CBUUID(string: interiorStatusUUID)
    /// CBUUID for Exterior service (same as shared)
    static let exteriorServiceCBUUID = CBUUID(string: exteriorServiceUUID)
    /// CBUUID for Exterior status characteristic
    static let exteriorStatusCBUUID = CBUUID(string: exteriorStatusUUID)
    #endif
}

// MARK: - DiscoveredDevice

#if canImport(CoreBluetooth)
/// A BLE peripheral discovered during scanning.
struct DiscoveredDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    let name: String
    let unitType: UnitType
    let rssi: Int
    var lastSeen: Date
}
#endif

// MARK: - WatchStatus

/// Status information sent between iPhone and Apple Watch.
struct WatchStatus: Codable {
    let phase: String       // "connecting", "calling", "pressing", "done", "error"
    let message: String
    let presetID: UUID?
}

// MARK: - DeviceState

/// Maps status byte values received via BLE notifications to device states.
enum DeviceState: UInt8 {
    case idle = 0
    case busy = 1
    case done = 2
    case error = 3

    /// Initializes from a raw byte, defaulting to `.error` for unknown values.
    init(fromByte byte: UInt8) {
        self = DeviceState(rawValue: byte) ?? .error
    }
}
