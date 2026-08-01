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

    /// The underlying CoreBluetooth manager.
    private let bleManager: BLEManager

    /// Lookup dictionary mapping BLEDevice.id (UUID string) to the original DiscoveredDevice.
    /// Used to resolve the CBPeripheral when connect(to:) is called with a BLEDevice.
    private var discoveredDeviceLookup: [String: DiscoveredDevice] = [:]

    /// Combine subscriptions.
    private var cancellables = Set<AnyCancellable>()

    /// Task for the 5-second command timeout.
    private var commandTimeoutTask: Task<Void, Never>?

    /// Task for auto-resetting status back to idle after done/error.
    private var statusResetTask: Task<Void, Never>?

    /// Tracks reconnection attempts for the current device.
    private var reconnectCount: Int = 0

    /// Maximum number of automatic reconnection attempts.
    private let maxReconnectAttempts = 3

    /// Flag indicating whether the user initiated the disconnect.
    /// When true, auto-reconnect is suppressed.
    private var isUserDisconnect = false

    /// The device currently being connected to (used for reconnect).
    private var lastConnectedBLEDevice: BLEDevice?

    // MARK: - Initialization

    init(bleManager: BLEManager = BLEManager()) {
        self.bleManager = bleManager
        setupBindings()
    }

    // MARK: - Bindings

    /// Sets up Combine subscriptions to forward BLEManager state to protocol properties.
    private func setupBindings() {
        // Forward isScanning
        bleManager.$isScanning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] scanning in
                self?.isScanning = scanning
            }
            .store(in: &cancellables)

        // Map discoveredDevices from DiscoveredDevice to BLEDevice
        bleManager.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] discovered in
                guard let self = self else { return }
                // Update lookup dictionary
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

        // Monitor Bluetooth state for error messages
        bleManager.$bluetoothState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                guard let self = self else { return }
                self.handleBluetoothStateChange(state)
            }
            .store(in: &cancellables)

        // Subscribe to connectedInterior to update connectedDevice
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
                    // Interior disconnected — handle unexpected disconnect
                    self.handleDeviceDisconnected()
                }
            }
            .store(in: &cancellables)

        // Subscribe to connectedExterior to update connectedDevice
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
                    // Exterior disconnected — handle unexpected disconnect
                    self.handleDeviceDisconnected()
                }
            }
            .store(in: &cancellables)

        // Subscribe to status notifications and map bytes to BLEDeviceStatus
        bleManager.statusNotificationSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                self.handleStatusNotification(data: notification.data)
            }
            .store(in: &cancellables)
    }

    // MARK: - Disconnection Handling

    /// Handles unexpected disconnection by attempting auto-reconnect.
    private func handleDeviceDisconnected() {
        // If both interior and exterior are nil, device is truly disconnected
        guard bleManager.connectedInterior == nil && bleManager.connectedExterior == nil else {
            return
        }

        // If user initiated disconnect, skip auto-reconnect
        guard !isUserDisconnect else {
            isUserDisconnect = false
            return
        }

        // Auto-reconnect logic
        if reconnectCount < maxReconnectAttempts, let device = lastConnectedBLEDevice {
            reconnectCount += 1
            connectionState = .connecting
            statusMessage = "Reconnecting... (attempt \(reconnectCount)/\(maxReconnectAttempts))"

            // Attempt reconnection
            Task {
                // Small delay before reconnect attempt
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                self.connect(to: device)
            }
        } else {
            // Exhausted reconnect attempts or no device to reconnect to
            connectedDevice = nil
            connectionState = .disconnected
            deviceStatus = .idle
            statusMessage = "Device disconnected unexpectedly."
            reconnectCount = 0
            lastConnectedBLEDevice = nil
        }
    }

    // MARK: - Bluetooth State Handling

    /// Updates statusMessage based on the current Bluetooth hardware state.
    private func handleBluetoothStateChange(_ state: CBManagerState) {
        switch state {
        case .unauthorized:
            statusMessage = "Bluetooth permission denied. Enable in Settings."
            isScanning = false
        case .poweredOff, .unsupported:
            statusMessage = "Bluetooth is not available"
            connectionState = .disconnected
        case .poweredOn:
            // Clear any previous Bluetooth-related error messages
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
        // Block scan if Bluetooth is unauthorized
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
                // Connection successful — state will be updated via
                // the connectedInterior/connectedExterior subscription
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

        // Disconnect from currently connected device(s)
        if let interior = bleManager.connectedInterior {
            bleManager.disconnect(from: interior)
        }
        if let exterior = bleManager.connectedExterior {
            bleManager.disconnect(from: exterior)
        }

        // Reset published state to defaults
        connectedDevice = nil
        connectionState = .disconnected
        deviceStatus = .idle
        statusMessage = ""
        lastConnectedBLEDevice = nil
    }

    // MARK: - Commands

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
                // Command sent successfully — show done immediately
                // (hardware doesn't send status notifications)
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
                // If call button profile is calibrated, send X/Y/Z coordinates (same as floor command)
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
                    // Fallback: send simple call command (push duration only)
                    let data = CommandEncoder.encodeCallCommand()
                    try await bleManager.write(data: data, to: exterior.peripheral)
                }
                // Command sent successfully — show done immediately
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

    // MARK: - Status Notification Handling

    /// Processes a status notification from the connected device.
    /// Maps the first byte to a DeviceState, then to BLEDeviceStatus.
    private func handleStatusNotification(data: Data) {
        guard let firstByte = data.first else { return }

        // Cancel the command timeout since we received a notification
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

    // MARK: - Command Timeout

    /// Starts a 5-second timeout. If no status notification is received within
    /// that window, sets deviceStatus to .error with a timeout message.
    private func startCommandTimeout() {
        commandTimeoutTask?.cancel()
        commandTimeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                guard let self = self, !Task.isCancelled else { return }
                self.deviceStatus = .error
                self.statusMessage = "Command timed out"
                self.scheduleAutoReset()
            } catch {
                // Task was cancelled — notification was received in time
            }
        }
    }

    // MARK: - Auto-Reset

    /// Schedules an automatic reset of deviceStatus to .idle.
    /// .done resets after 1 second, .error resets after 2 seconds.
    private func scheduleAutoReset() {
        statusResetTask?.cancel()

        let delayNanoseconds: UInt64
        switch deviceStatus {
        case .done:
            delayNanoseconds = 1_000_000_000 // 1 second
        case .error:
            delayNanoseconds = 2_000_000_000 // 2 seconds
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
            // Auto-scan if needed devices aren't in the lookup
            let needsExterior = preset.exteriorDeviceID != nil && discoveredDeviceLookup[preset.exteriorDeviceID!] == nil
            let needsInterior = preset.interiorDeviceID != nil && discoveredDeviceLookup[preset.interiorDeviceID!] == nil

            if needsExterior || needsInterior {
                // Scan for devices before executing
                bleManager.startScan()
                // Wait up to 8 seconds for devices to appear
                for _ in 0..<16 {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    let foundExterior = preset.exteriorDeviceID == nil || discoveredDeviceLookup[preset.exteriorDeviceID!] != nil
                    let foundInterior = preset.interiorDeviceID == nil || discoveredDeviceLookup[preset.interiorDeviceID!] != nil
                    if foundExterior && foundInterior { break }
                }
                bleManager.stopScan()
            }

            // Step 1: Connect to the Exterior device
            onPhaseChange(.connectingExterior)

            guard let exteriorID = preset.exteriorDeviceID,
                  let exteriorDiscovered = discoveredDeviceLookup[exteriorID] else {
                statusMessage = "Exterior device not found. Try scanning first."
                completion(false)
                return
            }

            do {
                try await bleManager.connect(to: exteriorDiscovered)
                // Wait for characteristic discovery to complete
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
                statusMessage = "Failed to connect to exterior device."
                completion(false)
                return
            }

            // Step 2: Send call command to the Exterior device
            onPhaseChange(.callingElevator)

            guard let exteriorDevice = bleManager.connectedExterior else {
                statusMessage = "Exterior device not ready."
                completion(false)
                return
            }

            do {
                // Use calibrated coordinates if available
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

            // Wait for exterior unit to complete its movement
            // Hardware doesn't send status notifications, so use a fixed delay
            try? await Task.sleep(nanoseconds: 5_000_000_000)

            // Step 3: Connect to the Interior device
            onPhaseChange(.connectingInterior)

            guard let interiorID = preset.interiorDeviceID,
                  let interiorDiscovered = discoveredDeviceLookup[interiorID] else {
                statusMessage = "Interior device not found."
                completion(false)
                return
            }

            do {
                try await bleManager.connect(to: interiorDiscovered)
                // Wait for characteristic discovery to complete
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            } catch {
                statusMessage = "Failed to connect to interior device."
                completion(false)
                return
            }

            // Step 4: Send floor command to the Interior device
            onPhaseChange(.selectingFloor)

            // Use the peripheral directly rather than relying on connectedInterior classification
            let interiorPeripheral = interiorDiscovered.peripheral

            if let floorProfileID = preset.targetFloorProfileID,
               let profile = resolveFloorProfile(id: floorProfileID) {
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
            } else if preset.targetFloorProfileID != nil {
                // Floor profile was specified but not found — try using the first available profile
                let persistenceService = JSONPersistenceService()
                let buttonMaps = persistenceService.loadButtonMaps()
                if let firstProfile = buttonMaps.first?.profiles.first {
                    do {
                        let chunks = try CommandEncoder.encodeFloorCommand(
                            x: UInt8(firstProfile.x),
                            y: UInt8(firstProfile.y),
                            z: UInt8(firstProfile.z)
                        )
                        for chunk in chunks {
                            try await bleManager.write(data: chunk, to: interiorPeripheral)
                        }
                    } catch {
                        statusMessage = "Floor command failed."
                        completion(false)
                        return
                    }
                } else {
                    // No profiles at all — skip floor selection, still succeed
                    statusMessage = "No floor profiles configured."
                }
            }
            // If no targetFloorProfileID set, use the first available floor profile
            if preset.targetFloorProfileID == nil {
                let persistenceService = JSONPersistenceService()
                let buttonMaps = persistenceService.loadButtonMaps()
                if let firstProfile = buttonMaps.first?.profiles.first {
                    do {
                        let chunks = try CommandEncoder.encodeFloorCommand(
                            x: UInt8(firstProfile.x),
                            y: UInt8(firstProfile.y),
                            z: UInt8(firstProfile.z)
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
            }

            // Step 5: All steps completed successfully
            onPhaseChange(.done)
            completion(true)
        }
    }

    // MARK: - Wait for Device Idle

    /// Waits for the device status to return to idle (indicating movement complete).
    /// Returns true if idle was reached, false on timeout.
    private func waitForDeviceIdle(timeout: TimeInterval) async -> Bool {
        let startTime = Date()
        // Small initial delay to let the command start
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        while Date().timeIntervalSince(startTime) < timeout {
            if deviceStatus == .done || deviceStatus == .idle {
                // Give a small buffer after done
                try? await Task.sleep(nanoseconds: 500_000_000)
                return true
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
        return false
    }

    // MARK: - Floor Profile Resolution

    /// Resolves a FloorProfile by its UUID from persisted button maps.
    /// Searches all saved ButtonMaps for a profile matching the given ID.
    private nonisolated func resolveFloorProfile(id: UUID) -> FloorProfile? {
        let persistenceService = JSONPersistenceService()
        let buttonMaps = persistenceService.loadButtonMaps()
        for buttonMap in buttonMaps {
            if let profile = buttonMap.profiles.first(where: { $0.id == id }) {
                return profile
            }
        }
        return nil
    }
}

#endif
