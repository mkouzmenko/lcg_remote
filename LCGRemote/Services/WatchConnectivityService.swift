#if canImport(WatchConnectivity)
#if os(iOS)
import Foundation
import WatchConnectivity
import Combine

// MARK: - WatchConnectivityService

/// Bridges iPhone ↔ Apple Watch communication for LCG Remote.
///
/// Transfers Location Presets to the Watch, receives preset activation commands,
/// executes BLE operations on the iPhone, and relays execution status back to the Watch.
///
/// All BLE communication happens on the iPhone; the Watch app relays commands
/// via WatchConnectivity since watchOS CoreBluetooth has severe background limitations.
final class WatchConnectivityService: NSObject, ObservableObject {

    // MARK: - Published State

    /// Whether the paired Apple Watch is currently reachable.
    @Published var isWatchReachable: Bool = false

    /// Whether the WCSession has been successfully activated.
    @Published var isSessionActive: Bool = false

    // MARK: - Message Keys

    private enum MessageKey {
        static let action = "action"
        static let presetID = "presetID"
        static let presets = "presets"
        static let status = "status"
    }

    private enum ActionValue {
        static let activatePreset = "activatePreset"
        static let presetsUpdate = "presetsUpdate"
        static let statusUpdate = "statusUpdate"
    }

    // MARK: - Dependencies

    private var bleManager: BLEManager?
    private var cancellables = Set<AnyCancellable>()

    /// Callback invoked when the Watch requests a preset activation.
    /// The host app should set this to wire up the actual BLE execution logic.
    var onPresetActivationRequest: ((_ presetID: UUID) async -> Void)?

    // MARK: - Initialization

    override init() {
        super.init()
    }

    /// Initializes with a BLEManager dependency for executing BLE operations
    /// triggered by Watch commands.
    ///
    /// - Parameter bleManager: The BLE manager used for device communication.
    init(bleManager: BLEManager) {
        self.bleManager = bleManager
        super.init()
    }

    // MARK: - Public API

    /// Activates the WCSession. Call this on app launch.
    ///
    /// Checks that WatchConnectivity is supported on this device before activating.
    func activateSession() {
        guard WCSession.isSupported() else { return }

        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Sends the user's Location Presets to the paired Apple Watch.
    ///
    /// Uses `transferUserInfo` for reliable background delivery if the Watch is not
    /// immediately reachable, or `sendMessage` for immediate delivery when reachable.
    ///
    /// - Parameter presets: The array of Location Presets to sync to the Watch.
    func sendPresets(_ presets: [LocationPreset]) {
        guard WCSession.default.activationState == .activated else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(presets),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }

        let message: [String: Any] = [
            MessageKey.action: ActionValue.presetsUpdate,
            MessageKey.presets: jsonString
        ]

        if WCSession.default.isReachable {
            // Send immediately if Watch is reachable
            WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] error in
                // Fallback to transferUserInfo on send failure
                self?.transferPresetsAsUserInfo(message)
            }
        } else {
            // Queue for background delivery
            transferPresetsAsUserInfo(message)
        }
    }

    /// Sends a status update to the Watch indicating the current execution phase.
    ///
    /// - Parameter status: The current execution status to relay to the Watch.
    func sendStatusUpdate(_ status: WatchStatus) {
        guard WCSession.default.activationState == .activated else { return }

        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(status),
              let jsonString = String(data: data, encoding: .utf8) else {
            return
        }

        let message: [String: Any] = [
            MessageKey.action: ActionValue.statusUpdate,
            MessageKey.status: jsonString
        ]

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
        } else {
            // Queue status for delivery when Watch becomes reachable
            WCSession.default.transferUserInfo(message)
        }
    }

    /// Handles a preset activation command received from the Apple Watch.
    ///
    /// Sends status updates back to the Watch during execution.
    ///
    /// - Parameter presetID: The UUID of the Location Preset to activate.
    func handlePresetActivation(_ presetID: UUID) async {
        // Notify Watch that we're starting
        sendStatusUpdate(WatchStatus(
            phase: "connecting",
            message: "Connecting to devices...",
            presetID: presetID
        ))

        // Delegate to the registered activation handler
        if let handler = onPresetActivationRequest {
            await handler(presetID)
        } else {
            // No handler registered — report error to Watch
            sendStatusUpdate(WatchStatus(
                phase: "error",
                message: "iPhone app is not ready to execute commands.",
                presetID: presetID
            ))
        }
    }

    // MARK: - Private Helpers

    /// Transfers presets via `transferUserInfo` for reliable background delivery.
    private func transferPresetsAsUserInfo(_ message: [String: Any]) {
        WCSession.default.transferUserInfo(message)
    }

    /// Processes an incoming message from the Watch.
    private func processMessage(_ message: [String: Any]) {
        guard let action = message[MessageKey.action] as? String else { return }

        switch action {
        case ActionValue.activatePreset:
            guard let presetIDString = message[MessageKey.presetID] as? String,
                  let presetID = UUID(uuidString: presetIDString) else {
                return
            }

            // Execute preset activation asynchronously
            Task {
                await handlePresetActivation(presetID)
            }

        default:
            break
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.isSessionActive = activationState == .activated
            self?.isWatchReachable = session.isReachable
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isSessionActive = false
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isSessionActive = false
        }
        // Reactivate session for multi-watch support
        session.activate()
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isWatchReachable = session.isReachable
        }
    }

    // MARK: - Receiving Messages

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        processMessage(message)
    }

    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        processMessage(message)
        replyHandler(["received": true])
    }

    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        processMessage(userInfo)
    }
}

#endif // os(iOS)
#endif // canImport(WatchConnectivity)
