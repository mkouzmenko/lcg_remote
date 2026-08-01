import Foundation

/// Encodes user-level commands into BLE byte sequences for LCG hardware units.
struct CommandEncoder {

    // MARK: - Coordinate Commands

    /// Encodes X, Y, Z coordinates as sequential raw byte values.
    /// The firmware collects 3 sequential byte writes, then on the 3rd byte triggers position(X, Y, Z).
    ///
    /// - Parameters:
    ///   - x: X coordinate (0–250)
    ///   - y: Y coordinate (0–250)
    ///   - z: Z coordinate (0–250)
    /// - Returns: Array of 3 `Data` values: [x], [y], [z] as raw bytes
    /// - Throws: `CommandError.xExceedsMax`, `.yExceedsMax`, or `.zExceedsMax` if any value is out of range
    static func encodeFloorCommand(x: UInt8, y: UInt8, z: UInt8) throws -> [Data] {
        guard x <= 250 else { throw CommandError.xExceedsMax }
        guard y <= 250 else { throw CommandError.yExceedsMax }
        guard z <= 250 else { throw CommandError.zExceedsMax }
        // Send raw byte values — no offset. Firmware expects raw X, Y, Z.
        return [
            Data([x]),
            Data([y]),
            Data([z])
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
