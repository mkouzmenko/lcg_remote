#if canImport(CoreBluetooth)
import Foundation
import CoreBluetooth
import Combine

// MARK: - BLEAdapter

/// Concrete adapter wrapping BLEManager for real BLE communication.
/// Conforms to BLEServiceProtocol and translates CoreBluetooth events
/// into the protocol's published state.
@MainActor
final class BLEAdapter: ObservableObject, BLEServiceProtocol {

    // MARK: - Published Protocol State

    @Published var discoveredDevices: [BLEDevice] = []
    @Published var isScanning: Bool = false
    @Published var connectedDevice: BLEDevice? = nil
    @Published var connectionState: BLEConnectionState = .disconnected
    @Published var deviceStatus: BLEDeviceStatus = .idle
    @Published var statusMessage: String = ""

    /// Stored call button profile for exterior unit calibration.
    var callButtonProfile: FloorProfile? = FloorProfile(id: UUID(), label: "Call Elevator", x: 50, y: 100, z: 30, sortOrder: 0)

    // MARK: - Internal State

    private let bleManager: BLEManager
    private var discoveredDeviceLookup: [String: DiscoveredDevice] = [:]
    private var cancellables = Set<AnyCancellable>()
    private var commandTimeoutTask: Task<Void, Never>?
    private var statusResetTask: Task<Void, Never>?
    private var reconnectCount: Int = 0
    private let maxReconnectAttempts = 3
    private var isUserDisconnect = false
    private var lastConnectedBLEDevice: BLEDevice?

    // MARK: - Initialization

    init(bleManager: BLEManager = BLEManager()) {
        self.bleManager = bleManager
        setupBindings()
    }

    // MARK: - Bindings

    private func setupBindings() {
        bleManager.$isScanning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scanning in
                self?.isScanning = scanning
            }
            .store(in: &cancellables)

        bleManager.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] discovered in
                guard let self = self else { return }
                var lookup: [String: DiscoveredDevice] = [:]
                var bleDevices: [BLEDevice] = []
                for device in discovered {
                    let bleDevice = BLEDevice(from: device)
                    lookup[bleDevice.id] = device
                    bleDevices.append(bleDevice)
                }
                self.discoveredDeviceLookup = lookup
                self.discoveredDevices = bleDevices
            }
            .store(in: &cancellables)

        bleManager.$bluetoothState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleBluetoothStateChange(state)
            }
            .store(in: &cancellables)

        bleManager.$connectedInterior
            .receive(on: DispatchQueue.main)
            .sink { [weak self] interior in
                guard let self = self else { return }
                if let device = interior {
                    let bleDevice = BLEDevice(
                        id: device.id.uuidString,
                        name: device.name,
                        unitType: device.unitType,
                        rssi: 0,
                        isReachable: true
                    )
                    self.connectedDevice = bleDevice
                } else {
                    self.handleDeviceDisconnected()
                }
            }
            .store(in: &cancellables)

        bleManager.$connectedExterior
            .receive(on: DispatchQueue.main)
            .sink { [weak self] exterior in
                guard let self = self else { return }
                if let device = exterior {
                    let bleDevice = BLEDevice(
                        id: device.id.uuidString,
                        name: device.name,
                        unitType: device.unitType,
                        rssi: 0,
                        isReachable: true
                    )
                    self.connectedDevice = bleDevice
                } else {
                    self.handleDeviceDisconnected()
                }
            }
            .store(in: &cancellables)

        bleManager.statusNotificationSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleStatusNotification(data: notification.data)
            }
            .store(in: &cancellables)
    }

    // MARK: - Disconnection Handling

    private func handleDeviceDisconnected() {
        guard bleManager.connectedInterior == nil && bleManager.connectedExterior == nil else {
            return
        }

        guard !isUserDisconnect else {
            isUserDisconnect = false
            return
        }

        if reconnectCount < maxReconnectAttempts, let device = lastConnectedBLEDevice {
            reconnectCount += 1
            connectionState = .connecting
            statusMessage = "Reconnecting... (attempt \(reconnectCount)/\(maxReconnectAttempts))"

            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.connect(to: device)
            }
        } else {
            connectedDevice = nil
            connectionState = .disconnected
            deviceStatus = .idle
            statusMessage = "Device disconnected unexpectedly."
            reconnectCount = 0
            lastConnectedBLEDevice = nil
        }
    }

    // MARK: - Bluetooth State Handling

    private func handleBluetoothStateChange(_ state: CBManagerState) {
        switch state {
        case .unauthorized:
            statusMessage = "Bluetooth permission denied. Enable in Settings."
            isScanning = false
        case .poweredOff, .unsupported:
            statusMessage = "Bluetooth is not available"
            connectionState = .disconnected
        case .poweredOn:
            if statusMessage == "Bluetooth is not available" ||
               statusMessage == "Bluetooth permission denied. Enable in Settings." {
                statusMessage = ""
            }
        case .unknown, .resetting:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Scanning

    func startScan() {
        guard bleManager.bluetoothState != .unauthorized else {
            statusMessage = "Bluetooth permission denied. Enable in Settings."
            return
        }
        guard bleManager.bluetoothState == .poweredOn else {
            statusMessage = "Bluetooth is not available"
            return
        }
        bleManager.startScan()
    }

    func stopScan() {
        bleManager.stopScan()
    }

    // MARK: - Connection

    func connect(to device: BLEDevice) {
        guard let discoveredDevice = discoveredDeviceLookup[device.id] else {
            statusMessage = "Device not found. Try scanning again."
            connectionState = .disconnected
            return
        }

        connectionState = .connecting
        statusMessage = ""
        lastConnectedBLEDevice = device

        Task {
            do {
                try await bleManager.connect(to: discoveredDevice)
                self.connectionState = .connected
                self.reconnectCount = 0
                self.statusMessage = ""
            } catch {
                self.connectionState = .disconnected
                if error is CommandError {
                    self.statusMessage = "Connection timed out. Device may be out of range."
                } else {
                    self.statusMessage = "Connection failed. Device not reachable."
                }
            }
        }
    }

    func disconnect() {
        isUserDisconnect = true
        reconnectCount = 0

        if let interior = bleManager.connectedInterior {
            bleManager.disconnect(from: interior)
        }
        if let exterior = bleManager.connectedExterior {
            bleManager.disconnect(from: exterior)
        }

        connectedDevice = nil
        connectionState = .disconnected
        deviceStatus = .idle
        statusMessage = ""
        lastConnectedBLEDevice = nil
    }

    // MARK: - Elevator Commands

    func sendFloorCommand(elevator: ElevatorConfig, button: FloorButtonConfig) {
        deviceStatus = .busy
        statusMessage = "Connecting..."

        Task {
            let targetDeviceID = elevator.interiorDeviceID

            // Find the device
            var discoveredDevice = findDevice(deviceID: targetDeviceID, name: elevator.interiorDeviceName, unitType: .interior)

            // If not found, scan for up to 8 seconds
            if discoveredDevice == nil {
                bleManager.startScan()
                for _ in 0..<16 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if let found = findDevice(deviceID: targetDeviceID, name: elevator.interiorDeviceName, unitType: .interior) {
                        discoveredDevice = found
                        break
                    }
                }
                bleManager.stopScan()
            }

            guard let device = discoveredDevice else {
                self.deviceStatus = .error
                self.statusMessage = "Interior device not found. Check Settings."
                self.scheduleAutoReset()
                return
            }

            // Disconnect existing connections
            if let interior = bleManager.connectedInterior {
                bleManager.disconnect(from: interior)
            }
            if let exterior = bleManager.connectedExterior {
                bleManager.disconnect(from: exterior)
            }

            // Connect
            do {
                try await bleManager.connect(to: device)
            } catch {
                self.deviceStatus = .error
                self.statusMessage = "Connection failed."
                self.scheduleAutoReset()
                return
            }

            self.connectionState = .connected
            self.statusMessage = "Pressing button..."

            // Send command
            let peripheral = device.peripheral
            do {
                let chunks = try CommandEncoder.encodeFloorCommand(
                    x: UInt8(button.x),
                    y: UInt8(button.y),
                    z: UInt8(button.z)
                )
                for chunk in chunks {
                    try await bleManager.write(data: chunk, to: peripheral)
                }
                self.deviceStatus = .done
                self.statusMessage = "Floor selected"
                self.scheduleAutoReset()
            } catch {
                self.deviceStatus = .error
                self.statusMessage = "Command failed. Please retry."
                self.scheduleAutoReset()
            }
        }
    }

    func sendExteriorCommand(button: ExteriorButtonConfig) {
        deviceStatus = .busy
        statusMessage = "Connecting..."

        Task {
            let targetDeviceID = button.deviceID

            // Find the device
            var discoveredDevice = findDevice(deviceID: targetDeviceID, name: button.deviceName, unitType: .exterior)

            // If not found, scan for up to 8 seconds
            if discoveredDevice == nil {
                bleManager.startScan()
                for _ in 0..<16 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    if let found = findDevice(deviceID: targetDeviceID, name: button.deviceName, unitType: .exterior) {
                        discoveredDevice = found
                        break
                    }
                }
                bleManager.stopScan()
            }

            guard let device = discoveredDevice else {
                self.deviceStatus = .error
                self.statusMessage = "Exterior device not found. Check Settings."
                self.scheduleAutoReset()
                return
            }

            // Disconnect existing connections
            if let interior = bleManager.connectedInterior {
                bleManager.disconnect(from: interior)
            }
            if let exterior = bleManager.connectedExterior {
                bleManager.disconnect(from: exterior)
            }

            // Connect
            do {
                try await bleManager.connect(to: device)
            } catch {
                self.deviceStatus = .error
                self.statusMessage = "Connection failed."
                self.scheduleAutoReset()
                return
            }

            self.connectionState = .connected
            self.statusMessage = "Calling elevator..."

            // Send command
            let peripheral = device.peripheral
            do {
                let chunks = try CommandEncoder.encodeFloorCommand(
                    x: UInt8(button.x),
                    y: UInt8(button.y),
                    z: UInt8(button.z)
                )
                for chunk in chunks {
                    try await bleManager.write(data: chunk, to: peripheral)
                }
                self.deviceStatus = .done
                self.statusMessage = "Elevator called"
                self.scheduleAutoReset()
            } catch {
                self.deviceStatus = .error
                self.statusMessage = "Command failed. Please retry."
                self.scheduleAutoReset()
            }
        }
    }

    // MARK: - Legacy Commands

    func executeFloorCommand(profile: FloorProfile) {
        guard let interior = bleManager.connectedInterior else {
            deviceStatus = .error
            statusMessage = "Not connected to a device"
            scheduleAutoReset()
            return
        }

        deviceStatus = .busy
        statusMessage = "Pressing button..."

        Task {
            do {
                let chunks = try CommandEncoder.encodeFloorCommand(
                    x: UInt8(profile.x),
                    y: UInt8(profile.y),
                    z: UInt8(profile.z)
                )
                for chunk in chunks {
                    try await bleManager.write(data: chunk, to: interior.peripheral)
                }
                self.deviceStatus = .done
                self.statusMessage = "Floor selected"
                self.scheduleAutoReset()
            } catch {
                self.deviceStatus = .error
                self.statusMessage = "Command failed. Please retry."
                self.scheduleAutoReset()
            }
        }
    }

    func executeCallCommand() {
        guard let exterior = bleManager.connectedExterior else {
            deviceStatus = .error
            statusMessage = "Not connected to a device"
            scheduleAutoReset()
            return
        }

        deviceStatus = .busy
        statusMessage = "Pressing button..."

        Task {
            do {
                if let profile = callButtonProfile {
                    let chunks = try CommandEncoder.encodeFloorCommand(
                        x: UInt8(profile.x),
                        y: UInt8(profile.y),
                        z: UInt8(profile.z)
                    )
                    for chunk in chunks {
                        try await bleManager.write(data: chunk, to: exterior.peripheral)
                    }
                } else {
                    let data = CommandEncoder.encodeCallCommand()
                    try await bleManager.write(data: data, to: exterior.peripheral)
                }
                self.deviceStatus = .done
                self.statusMessage = "Command sent"
                self.scheduleAutoReset()
            } catch {
                self.deviceStatus = .error
                self.statusMessage = "Command failed. Please retry."
                self.scheduleAutoReset()
            }
        }
    }

    // MARK: - Helpers

    private func findDevice(deviceID: String?, name: String?, unitType: UnitType) -> DiscoveredDevice? {
        if let id = deviceID, let found = discoveredDeviceLookup[id] {
            return found
        }
        if let name = name, let found = discoveredDeviceLookup.values.first(where: { $0.name == name }) {
            return found
        }
        return discoveredDeviceLookup.values.first { $0.unitType == unitType }
    }

    // MARK: - Status Notification Handling

    private func handleStatusNotification(data: Data) {
        guard let firstByte = data.first else { return }

        commandTimeoutTask?.cancel()
        commandTimeoutTask = nil

        let deviceState = DeviceState(fromByte: firstByte)
        let newStatus = BLEDeviceStatus(from: deviceState)

        deviceStatus = newStatus

        switch newStatus {
        case .idle:
            statusMessage = ""
        case .busy:
            statusMessage = "Pressing button..."
        case .done:
            statusMessage = "Command completed"
            scheduleAutoReset()
        case .error:
            statusMessage = "Device reported an error"
            scheduleAutoReset()
        }
    }

    // MARK: - Auto-Reset

    private func scheduleAutoReset() {
        statusResetTask?.cancel()

        let delayNanoseconds: UInt64
        switch deviceStatus {
        case .done:
            delayNanoseconds = 1_000_000_000
        case .error:
            delayNanoseconds = 2_000_000_000
        default:
            return
        }

        statusResetTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: delayNanoseconds)
                guard let self = self, !Task.isCancelled else { return }
                self.deviceStatus = .idle
                self.statusMessage = ""
            } catch {
                // Task was cancelled
            }
        }
    }

    // MARK: - Preset Execution

    func executePresetSequence(
        preset: LocationPreset,
        onPhaseChange: @escaping (PresetPhase) -> Void,
        completion: @escaping (Bool) -> Void
    ) {
        Task {
            let needsExterior = preset.exteriorDeviceID != nil && discoveredDeviceLookup[preset.exteriorDeviceID!] == nil
            let needsInterior = preset.interiorDeviceID != nil && discoveredDeviceLookup[preset.interiorDeviceID!] == nil

            if needsExterior || needsInterior {
                bleManager.startScan()
                for _ in 0..<16 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    let foundExterior = preset.exteriorDeviceID == nil || discoveredDeviceLookup[preset.exteriorDeviceID!] != nil
                    let foundInterior = preset.interiorDeviceID == nil || discoveredDeviceLookup[preset.interiorDeviceID!] != nil
                    if foundExterior && foundInterior { break }
                }
                bleManager.stopScan()
            }

            onPhaseChange(.connectingExterior)

            guard let exteriorID = preset.exteriorDeviceID,
                  let exteriorDiscovered = discoveredDeviceLookup[exteriorID] else {
                statusMessage = "Exterior device not found."
                completion(false)
                return
            }

            do {
                try await bleManager.connect(to: exteriorDiscovered)
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                statusMessage = "Failed to connect to exterior device."
                completion(false)
                return
            }

            onPhaseChange(.callingElevator)

            guard let exteriorDevice = bleManager.connectedExterior else {
                statusMessage = "Exterior device not ready."
                completion(false)
                return
            }

            do {
                if let profile = callButtonProfile {
                    let chunks = try CommandEncoder.encodeFloorCommand(
                        x: UInt8(profile.x),
                        y: UInt8(profile.y),
                        z: UInt8(profile.z)
                    )
                    for chunk in chunks {
                        try await bleManager.write(data: chunk, to: exteriorDevice.peripheral)
                    }
                } else {
                    let callData = CommandEncoder.encodeCallCommand()
                    try await bleManager.write(data: callData, to: exteriorDevice.peripheral)
                }
            } catch {
                statusMessage = "Call command failed."
                completion(false)
                return
            }

            try? await Task.sleep(nanoseconds: 5_000_000_000)

            onPhaseChange(.connectingInterior)

            guard let interiorID = preset.interiorDeviceID,
                  let interiorDiscovered = discoveredDeviceLookup[interiorID] else {
                statusMessage = "Interior device not found."
                completion(false)
                return
            }

            do {
                try await bleManager.connect(to: interiorDiscovered)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                statusMessage = "Failed to connect to interior device."
                completion(false)
                return
            }

            onPhaseChange(.selectingFloor)

            let interiorPeripheral = interiorDiscovered.peripheral

            if let profile = callButtonProfile {
                do {
                    let chunks = try CommandEncoder.encodeFloorCommand(
                        x: UInt8(profile.x),
                        y: UInt8(profile.y),
                        z: UInt8(profile.z)
                    )
                    for chunk in chunks {
                        try await bleManager.write(data: chunk, to: interiorPeripheral)
                    }
                } catch {
                    statusMessage = "Floor command failed."
                    completion(false)
                    return
                }
            }

            onPhaseChange(.done)
            completion(true)
        }
    }
}

#endif
