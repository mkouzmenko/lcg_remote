#if canImport(CoreBluetooth)
import Foundation
import CoreBluetooth
import Combine

// MARK: - StatusMonitor

/// Subscribes to BLE status characteristic notifications and interprets device state.
///
/// Monitors the device state (Idle, Busy, Done, Error) via BLE notifications and
/// provides an async interface for waiting on command completion. Detects firmware
/// timeout (5-second gap between sequential writes) to trigger full re-send.
///
/// Requirements: 4.3, 4.4, 4.5, 4.6, 7.1, 7.2, 7.3, 7.4, 16.2
final class StatusMonitor: ObservableObject {

    // MARK: - Published State

    /// The current device state as reported by BLE notifications.
    @Published var currentState: DeviceState = .idle

    // MARK: - Private Properties

    /// Combine subscription for BLE status notifications.
    private var notificationCancellable: AnyCancellable?

    /// Continuation for the current `waitForCompletion` call, if any.
    private var completionContinuation: CheckedContinuation<DeviceState, Error>?

    /// Tracks whether we are currently subscribed to a device.
    private var subscribedPeripheralID: UUID?

    /// Timer for detecting firmware timeout (5-second gap between sequential writes).
    private var firmwareTimeoutTimer: Timer?

    /// Callback invoked when firmware timeout is detected, signaling need for full re-send.
    /// The caller (e.g., DeviceControlViewModel) sets this to trigger re-send of all bytes.
    var onFirmwareTimeout: (() -> Void)?

    /// Tracks the last notification time for firmware timeout detection.
    private var lastNotificationTime: Date?

    /// Whether we are in an active command sequence (between first write and Done/Error).
    private var isCommandActive: Bool = false

    // MARK: - Initialization

    init() {}

    deinit {
        unsubscribe()
    }

    // MARK: - Public API

    /// Subscribes to BLE status notifications from a connected device.
    ///
    /// Enables notifications on the status characteristic and begins monitoring
    /// device state changes.
    ///
    /// - Parameters:
    ///   - device: The connected LCG device to monitor.
    ///   - bleManager: The BLE manager providing notification data.
    func subscribe(to device: LCGDevice, via bleManager: BLEManager) async throws {
        let peripheralID = device.peripheral.identifier
        subscribedPeripheralID = peripheralID

        // Enable notifications on the status characteristic
        let statusUUID: CBUUID
        switch device.unitType {
        case .interior:
            statusUUID = BLEConstants.interiorStatusCBUUID
        case .exterior:
            statusUUID = BLEConstants.exteriorStatusCBUUID
        }

        // Find and enable notifications for the status characteristic
        if let services = device.peripheral.services {
            for service in services {
                if let characteristics = service.characteristics {
                    for characteristic in characteristics where characteristic.uuid == statusUUID {
                        if characteristic.properties.contains(.notify) {
                            device.peripheral.setNotifyValue(true, for: characteristic)
                        }
                    }
                }
            }
        }

        // Subscribe to notification data from BLEManager's publisher
        notificationCancellable = bleManager.statusNotificationSubject
            .filter { $0.peripheralID == peripheralID }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleNotification(data: notification.data)
            }
    }

    /// Unsubscribes from BLE status notifications and cleans up resources.
    func unsubscribe() {
        notificationCancellable?.cancel()
        notificationCancellable = nil
        subscribedPeripheralID = nil
        cancelFirmwareTimeoutTimer()
        isCommandActive = false
        lastNotificationTime = nil
    }

    /// Waits for the device to report completion (Done or Error) or times out.
    ///
    /// Suspends the caller until the status notification indicates Done (2) or Error (3),
    /// or the specified timeout elapses.
    ///
    /// - Parameter timeout: Maximum time to wait in seconds. Defaults to 30 seconds.
    /// - Returns: The terminal `DeviceState` (`.done` or `.error`).
    /// - Throws: `CommandError.timeout` if no terminal state is received within the timeout.
    func waitForCompletion(timeout: TimeInterval = 30.0) async throws -> DeviceState {
        // If already in a terminal state, return immediately
        if currentState == .done || currentState == .error {
            let state = currentState
            return state
        }

        // Mark command as active for firmware timeout detection
        isCommandActive = true
        lastNotificationTime = Date()
        startFirmwareTimeoutTimer()

        return try await withCheckedThrowingContinuation { continuation in
            self.completionContinuation = continuation

            // Set up command timeout
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                guard let self = self else { return }
                if let pending = self.completionContinuation {
                    self.completionContinuation = nil
                    self.isCommandActive = false
                    self.cancelFirmwareTimeoutTimer()
                    pending.resume(throwing: CommandError.timeout)
                }
            }
        }
    }

    /// Signals that a write operation has been sent, resetting the firmware timeout timer.
    ///
    /// Call this after each sequential byte write to the Interior Unit so that firmware
    /// timeout detection can track gaps between writes.
    func notifyWriteSent() {
        lastNotificationTime = Date()
        if isCommandActive {
            resetFirmwareTimeoutTimer()
        }
    }

    // MARK: - Private Methods

    /// Handles incoming BLE notification data by mapping the byte to a DeviceState.
    ///
    /// Maps byte values 0–3 to corresponding states; values > 3 map to `.error`.
    private func handleNotification(data: Data) {
        guard let byte = data.first else { return }

        let newState = DeviceState(fromByte: byte)
        currentState = newState
        lastNotificationTime = Date()

        // Reset firmware timeout on any notification
        if isCommandActive {
            resetFirmwareTimeoutTimer()
        }

        // Check for terminal states
        switch newState {
        case .done, .error:
            isCommandActive = false
            cancelFirmwareTimeoutTimer()

            if let continuation = completionContinuation {
                completionContinuation = nil
                continuation.resume(returning: newState)
            }
        case .busy:
            // Device is working, keep waiting
            break
        case .idle:
            // Idle during a command could indicate a reset; keep waiting for terminal
            break
        }
    }

    // MARK: - Firmware Timeout Detection

    /// Starts the 5-second firmware timeout timer.
    ///
    /// If the timer fires, it means the firmware didn't receive all parameters
    /// within 5 seconds, triggering a full re-send of the X, Y, Z sequence.
    private func startFirmwareTimeoutTimer() {
        cancelFirmwareTimeoutTimer()
        firmwareTimeoutTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: false
        ) { [weak self] _ in
            self?.handleFirmwareTimeout()
        }
    }

    /// Resets the firmware timeout timer after each write or notification.
    private func resetFirmwareTimeoutTimer() {
        cancelFirmwareTimeoutTimer()
        guard isCommandActive else { return }
        firmwareTimeoutTimer = Timer.scheduledTimer(
            withTimeInterval: 5.0,
            repeats: false
        ) { [weak self] _ in
            self?.handleFirmwareTimeout()
        }
    }

    /// Cancels the firmware timeout timer.
    private func cancelFirmwareTimeoutTimer() {
        firmwareTimeoutTimer?.invalidate()
        firmwareTimeoutTimer = nil
    }

    /// Called when the firmware timeout (5 seconds) elapses without completion.
    ///
    /// Triggers a full re-send of the command sequence via the `onFirmwareTimeout` callback.
    private func handleFirmwareTimeout() {
        guard isCommandActive else { return }

        cancelFirmwareTimeoutTimer()
        isCommandActive = false

        // Notify that firmware timeout occurred — caller should re-send full sequence
        DispatchQueue.main.async { [weak self] in
            self?.onFirmwareTimeout?()
        }

        // Resume completion continuation with firmware timeout error
        if let continuation = completionContinuation {
            completionContinuation = nil
            continuation.resume(throwing: CommandError.firmwareTimeout)
        }
    }
}

#endif
