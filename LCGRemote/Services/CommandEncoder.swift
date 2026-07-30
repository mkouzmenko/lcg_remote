import Foundation

/// Encodes user-level commands into BLE byte sequences for LCG hardware units.
struct CommandEncoder {

    // MARK: - Interior Unit Commands

    /// Encodes floor selection coordinates as sequential byte values for the Interior Unit.
    ///
    /// Each coordinate is offset by 0x01 to avoid sending a zero byte (reserved).
    /// - Parameters:
    ///   - x: Horizontal motor duration (0–144)
    ///   - y: Vertical motor duration (0–208)
    ///   - z: Push motor duration (0–100)
    /// - Returns: Array of 3 `Data` values: [0x01+x], [0x01+y], [0x01+z]
    /// - Throws: `CommandError.xExceedsMax`, `.yExceedsMax`, or `.zExceedsMax` if any value is out of range
    static func encodeFloorCommand(x: UInt8, y: UInt8, z: UInt8) throws -> [Data] {
        guard x <= 144 else { throw CommandError.xExceedsMax }
        guard y <= 208 else { throw CommandError.yExceedsMax }
        guard z <= 100 else { throw CommandError.zExceedsMax }
        return [
            Data([0x01 + x]),
            Data([0x01 + y]),
            Data([0x01 + z])
        ]
    }

    // MARK: - Exterior Unit Commands

    /// Encodes a call elevator command with the specified push duration for the Exterior Unit.
    ///
    /// - Parameter pushDuration: Duration in arbitrary units (default: 2)
    /// - Returns: Single-byte `Data` containing the push duration value
    static func encodeCallCommand(pushDuration: UInt8 = 2) -> Data {
        Data([pushDuration])
    }

    // MARK: - Special Commands

    /// Sends the carriage to its home position (Interior Unit).
    static let goHome = Data([0xFF])

    /// Triggers hardware component self-test (Interior Unit).
    static let componentTest = Data([0xFE])

    /// Requests current floor status (Exterior Unit).
    static let requestFloor = Data([0xFF])
}
