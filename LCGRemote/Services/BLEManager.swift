#if canImport(CoreBluetooth)
import Foundation
import CoreBluetooth
import Combine

// MARK: - LCGDevice

/// Represents a connected LCG hardware device with its BLE peripheral and metadata.
struct LCGDevice: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    let unitType: UnitType
    var name: String
}

// MARK: - BLEManager

/// Central BLE communication manager wrapping CoreBluetooth for LCG device interactions.
///
/// Handles scanning, connection management, characteristic discovery, data writes,
/// and automatic reconnection. Supports simultaneous connections to one Interior
/// and one Exterior unit.
///
/// Uses `ObservableObject` with `@Published` for iOS 16+ compatibility.
final class BLEManager: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var connectedInterior: LCGDevice?
    @Published var connectedExterior: LCGDevice?
    @Published var isScanning: Bool = false
    @Published var bluetoothState: CBManagerState = .unknown

    // MARK: - Private Properties

    private var centralManager: CBCentralManager!
    private var scanTimeoutTimer: Timer?
    private var reconnectAttempts: [UUID: Int] = [:]
    private let maxReconnectAttempts = 3
    private let scanTimeoutInterval: TimeInterval = 10.0
    private let connectionTimeoutInterval: TimeInterval = 5.0

    /// Stores discovered characteristics keyed by peripheral UUID.
    private var peripheralCharacteristics: [UUID: [CBUUID: CBCharacteristic]] = [:]

    /// Caches peripheral names from discovery (peripheral.name can be nil after connection).
    private var peripheralNames: [UUID: String] = [:]

    /// Continuations for pending async connect operations keyed by peripheral UUID.
    private var connectContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]

    /// Continuations for pending async write operations keyed by peripheral UUID.
    private var writeContinuations: [UUID: CheckedContinuation<Void, Error>] = [:]

    /// Continuations for pending async read operations keyed by peripheral UUID.
    private var readContinuations: [UUID: CheckedContinuation<Data, Error>] = [:]

    /// Publisher for BLE status characteristic notification data.
    /// Emits (peripheral UUID, notification data) tuples.
    let statusNotificationSubject = PassthroughSubject<(peripheralID: UUID, data: Data), Never>()

    /// Connection timeout work items keyed by peripheral UUID.
    private var connectionTimeoutItems: [UUID: DispatchWorkItem] = [:]

    /// Tracks which peripheral UUIDs were intentionally disconnected by the user.
    private var intentionalDisconnects: Set<UUID> = []

    // MARK: - Initialization

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    /// Initializer for dependency injection (testing).
    init(centralManager: CBCentralManager) {
        super.init()
        self.centralManager = centralManager
        self.centralManager.delegate = self
    }

    // MARK: - Public API

    /// Starts scanning for LCG Interior and Exterior units.
    ///
    /// Scans for all nearby BLE devices and filters by name prefix
    /// ("LiftGateIn" for interior, "LiftGateEx" for exterior).
    /// Automatically stops after 10 seconds.
    func startScan() {
        guard centralManager.state == .poweredOn else { return }

        discoveredDevices.removeAll()
        isScanning = true

        // Scan for all devices (no UUID filter) since each unit has a unique service UUID
        centralManager.scanForPeripherals(
            withServices: nil,
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )

        // Auto-stop scan after timeout
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = Timer.scheduledTimer(
            withTimeInterval: scanTimeoutInterval,
            repeats: false
        ) { [weak self] _ in
            self?.stopScan()
        }
    }

    /// Stops the active BLE scan.
    func stopScan() {
        scanTimeoutTimer?.invalidate()
        scanTimeoutTimer = nil
        centralManager.stopScan()
        isScanning = false
    }

    /// Connects to a discovered device asynchronously with a 5-second timeout.
    ///
    /// - Parameter device: The discovered device to connect to.
    /// - Throws: `CommandError.timeout` if connection is not established within 5 seconds.
    func connect(to device: DiscoveredDevice) async throws {
        let peripheralID = device.peripheral.identifier

        // Remove from intentional disconnects if reconnecting
        intentionalDisconnects.remove(peripheralID)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.connectContinuations[peripheralID] = continuation

            self.centralManager.connect(device.peripheral, options: nil)

            // Set up connection timeout
            let timeoutItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                if let pending = self.connectContinuations.removeValue(forKey: peripheralID) {
                    self.centralManager.cancelPeripheralConnection(device.peripheral)
                    pending.resume(throwing: CommandError.timeout)
                }
            }
            self.connectionTimeoutItems[peripheralID] = timeoutItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + self.connectionTimeoutInterval,
                execute: timeoutItem
            )
        }
    }

    /// Disconnects from a connected LCG device.
    ///
    /// - Parameter device: The LCG device to disconnect from.
    func disconnect(from device: LCGDevice) {
        intentionalDisconnects.insert(device.peripheral.identifier)
        reconnectAttempts.removeValue(forKey: device.peripheral.identifier)
        centralManager.cancelPeripheralConnection(device.peripheral)
    }

    /// Disconnects from a discovered device (convenience for pre-connection state).
    ///
    /// - Parameter device: The discovered device to disconnect from.
    func disconnect(from device: DiscoveredDevice) {
        intentionalDisconnects.insert(device.peripheral.identifier)
        reconnectAttempts.removeValue(forKey: device.peripheral.identifier)
        centralManager.cancelPeripheralConnection(device.peripheral)
    }

    /// Writes data to the command characteristic of a connected peripheral.
    ///
    /// - Parameters:
    ///   - data: The data bytes to write.
    ///   - peripheral: The target CBPeripheral.
    /// - Throws: `CommandError.notConnected` if no command characteristic found,
    ///           `CommandError.writeFailure` on BLE write error.
    func write(data: Data, to peripheral: CBPeripheral) async throws {
        let peripheralID = peripheral.identifier

        // Find the writable characteristic for this peripheral.
        // First try by known service UUIDs, then fall back to any stored characteristic.
        let serviceCharUUID: CBUUID
        if connectedInterior?.peripheral.identifier == peripheralID {
            serviceCharUUID = BLEConstants.interiorServiceCBUUID
        } else if connectedExterior?.peripheral.identifier == peripheralID {
            serviceCharUUID = BLEConstants.exteriorServiceCBUUID
        } else {
            // Fallback: use the shared LCG service UUID directly
            serviceCharUUID = BLEConstants.lcgServiceCBUUID
        }

        guard let characteristic = peripheralCharacteristics[peripheralID]?[serviceCharUUID] else {
            // Last fallback: find any writable characteristic for this peripheral
            guard let anyCharacteristic = peripheralCharacteristics[peripheralID]?.values.first(where: {
                $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse)
            }) else {
                throw CommandError.notConnected
            }
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.writeContinuations[peripheralID] = continuation
                peripheral.writeValue(data, for: anyCharacteristic, type: .withResponse)
            }
            return
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            self.writeContinuations[peripheralID] = continuation
            peripheral.writeValue(data, for: characteristic, type: .withResponse)
        }
    }

    /// Reads the status characteristic value from a connected device.
    ///
    /// - Parameter device: The LCG device to read from.
    /// - Returns: The characteristic data bytes.
    /// - Throws: `CommandError.notConnected` if no status characteristic found.
    func readCharacteristic(from device: LCGDevice) async throws -> Data {
        let peripheralID = device.peripheral.identifier

        let statusUUID: CBUUID
        switch device.unitType {
        case .interior:
            statusUUID = BLEConstants.interiorStatusCBUUID
        case .exterior:
            statusUUID = BLEConstants.exteriorStatusCBUUID
        }

        guard let characteristic = peripheralCharacteristics[peripheralID]?[statusUUID] else {
            throw CommandError.notConnected
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            self.readContinuations[peripheralID] = continuation
            device.peripheral.readValue(for: characteristic)
        }
    }

    // MARK: - Device Classification

    /// Classifies a peripheral as Interior or Exterior based on its name prefix.
    ///
    /// - Parameters:
    ///   - name: The peripheral's advertised name.
    ///   - advertisedServiceUUIDs: The service UUIDs from the advertisement data (fallback).
    /// - Returns: The unit type, or `nil` if the device doesn't match either known pattern.
    static func classifyDevice(name: String?, advertisedServiceUUIDs: [CBUUID]?) -> UnitType? {
        // Primary: classify by name prefix
        if let name = name {
            if name.hasPrefix("LiftGateIn") {
                return .interior
            } else if name.hasPrefix("LiftGateEx") {
                return .exterior
            }
        }
        // Fallback: classify by known service UUIDs
        if let serviceUUIDs = advertisedServiceUUIDs {
            if serviceUUIDs.contains(BLEConstants.interiorServiceCBUUID) {
                return .interior
            } else if serviceUUIDs.contains(BLEConstants.exteriorServiceCBUUID) {
                return .exterior
            }
        }
        return nil
    }
}

// MARK: - CBCentralManagerDelegate

extension BLEManager: CBCentralManagerDelegate {

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        bluetoothState = central.state
        if central.state != .poweredOn {
            stopScan()
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let name = peripheral.name
            ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String

        guard let unitType = BLEManager.classifyDevice(
            name: name,
            advertisedServiceUUIDs: advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID]
        ) else { return }

        let displayName = name ?? "Unknown Device"

        // Cache the name for use during characteristic discovery
        peripheralNames[peripheral.identifier] = displayName

        let device = DiscoveredDevice(
            id: peripheral.identifier,
            peripheral: peripheral,
            name: displayName,
            unitType: unitType,
            rssi: RSSI.intValue,
            lastSeen: Date()
        )

        // Update existing or append new
        if let index = discoveredDevices.firstIndex(where: { $0.id == peripheral.identifier }) {
            discoveredDevices[index].lastSeen = Date()
        } else {
            discoveredDevices.append(device)
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let peripheralID = peripheral.identifier

        // Cancel connection timeout
        connectionTimeoutItems[peripheralID]?.cancel()
        connectionTimeoutItems.removeValue(forKey: peripheralID)

        // Reset reconnect counter on successful connection
        reconnectAttempts.removeValue(forKey: peripheralID)

        // Set delegate and discover services
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }

    func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        let peripheralID = peripheral.identifier

        // Cancel connection timeout
        connectionTimeoutItems[peripheralID]?.cancel()
        connectionTimeoutItems.removeValue(forKey: peripheralID)

        // Resume continuation with error
        if let continuation = connectContinuations.removeValue(forKey: peripheralID) {
            let err = error ?? CommandError.timeout
            continuation.resume(throwing: err)
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        let peripheralID = peripheral.identifier

        // Clean up connected device state
        if connectedInterior?.peripheral.identifier == peripheralID {
            connectedInterior = nil
        }
        if connectedExterior?.peripheral.identifier == peripheralID {
            connectedExterior = nil
        }

        // Clean up characteristics
        peripheralCharacteristics.removeValue(forKey: peripheralID)

        // If intentional disconnect, no reconnection needed
        if intentionalDisconnects.remove(peripheralID) != nil {
            return
        }

        // Attempt automatic reconnection on unexpected disconnect
        if error != nil {
            let attempts = reconnectAttempts[peripheralID, default: 0]
            if attempts < maxReconnectAttempts {
                reconnectAttempts[peripheralID] = attempts + 1
                centralManager.connect(peripheral, options: nil)
            } else {
                reconnectAttempts.removeValue(forKey: peripheralID)
            }
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BLEManager: CBPeripheralDelegate {

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            let peripheralID = peripheral.identifier
            if let continuation = connectContinuations.removeValue(forKey: peripheralID) {
                continuation.resume(throwing: CommandError.writeFailure(underlying: error))
            }
            return
        }

        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        let peripheralID = peripheral.identifier

        if let error = error {
            if let continuation = connectContinuations.removeValue(forKey: peripheralID) {
                continuation.resume(throwing: CommandError.writeFailure(underlying: error))
            }
            return
        }

        guard let characteristics = service.characteristics else { return }

        // Store discovered characteristics
        if peripheralCharacteristics[peripheralID] == nil {
            peripheralCharacteristics[peripheralID] = [:]
        }

        for characteristic in characteristics {
            peripheralCharacteristics[peripheralID]?[characteristic.uuid] = characteristic

            // Subscribe to status notifications
            if characteristic.uuid == BLEConstants.interiorStatusCBUUID ||
               characteristic.uuid == BLEConstants.exteriorStatusCBUUID {
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }

        // Also store the service UUID as a key pointing to the first writable characteristic
        // This enables write(data:to:) to find the command characteristic by service UUID
        for characteristic in characteristics {
            if characteristic.properties.contains(.write) ||
               characteristic.properties.contains(.writeWithoutResponse) {
                peripheralCharacteristics[peripheralID]?[service.uuid] = characteristic
                break
            }
        }

        // Determine unit type by device name (since all units share the same service UUID)
        let unitType: UnitType
        let deviceName = peripheral.name ?? peripheralNames[peripheralID] ?? ""
        if deviceName.hasPrefix("LiftGateIn") {
            unitType = .interior
        } else if deviceName.hasPrefix("LiftGateEx") {
            unitType = .exterior
        } else if service.uuid == BLEConstants.interiorServiceCBUUID {
            // Fallback: classify as interior if we can't determine by name
            unitType = .interior
        } else {
            return
        }

        let device = LCGDevice(
            id: peripheralID,
            peripheral: peripheral,
            unitType: unitType,
            name: deviceName.isEmpty ? "LCG Device" : deviceName
        )

        switch unitType {
        case .interior:
            connectedInterior = device
        case .exterior:
            connectedExterior = device
        }

        // Resume connect continuation
        if let continuation = connectContinuations.removeValue(forKey: peripheralID) {
            continuation.resume()
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let peripheralID = peripheral.identifier

        if let continuation = writeContinuations.removeValue(forKey: peripheralID) {
            if let error = error {
                continuation.resume(throwing: CommandError.writeFailure(underlying: error))
            } else {
                continuation.resume()
            }
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        let peripheralID = peripheral.identifier

        // Handle read continuation
        if let continuation = readContinuations.removeValue(forKey: peripheralID) {
            if let error = error {
                continuation.resume(throwing: CommandError.writeFailure(underlying: error))
            } else if let data = characteristic.value {
                continuation.resume(returning: data)
            } else {
                continuation.resume(returning: Data())
            }
            return
        }

        // Publish status notifications for StatusMonitor
        if (characteristic.uuid == BLEConstants.interiorStatusCBUUID ||
            characteristic.uuid == BLEConstants.exteriorStatusCBUUID),
           let data = characteristic.value, error == nil {
            statusNotificationSubject.send((peripheralID: peripheralID, data: data))
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        // Notification state updated — no additional action needed here.
        // StatusMonitor handles notification values via its own subscription.
    }
}

#endif
