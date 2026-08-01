import Foundation

// MARK: - BLEConnectionState

/// Connection lifecycle states exposed through the BLE service protocol.
enum BLEConnectionState: String {
    case disconnected
    case connecting
    case connected
}

// MARK: - BLEDeviceStatus

/// Device operational status mapped from BLE notification bytes.
enum BLEDeviceStatus: String, CaseIterable {
    case idle
    case busy
    case done
    case error

    /// Maps a DeviceState (from BLE notification byte) to BLEDeviceStatus.
    init(from deviceState: DeviceState) {
        switch deviceState {
        case .idle: self = .idle
        case .busy: self = .busy
        case .done: self = .done
        case .error: self = .error
        }
    }
}

// MARK: - BLEDevice

/// Protocol-compatible device model used by all views and view models.
/// Replaces MockDevice as the canonical device representation.
struct BLEDevice: Identifiable, Hashable {
    let id: String
    var name: String
    let unitType: UnitType
    var rssi: Int
    var isReachable: Bool

    // MARK: - Hashable

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: BLEDevice, rhs: BLEDevice) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - BLEDevice Mapping from DiscoveredDevice

#if canImport(CoreBluetooth)
extension BLEDevice {
    /// Creates a BLEDevice from a CoreBluetooth DiscoveredDevice.
    init(from discovered: DiscoveredDevice) {
        self.id = discovered.id.uuidString
        self.name = discovered.name
        self.unitType = discovered.unitType
        self.rssi = discovered.rssi
        self.isReachable = true
    }
}
#endif
