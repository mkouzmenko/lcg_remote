import Foundation
import WatchConnectivity

/// Manages WatchConnectivity session on the Apple Watch side.
/// Receives presets from iPhone, sends activation commands, and receives status updates.
final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    @Published var presets: [WatchLocationPreset] = []
    @Published var currentStatus: WatchStatus?
    @Published var isPhoneReachable: Bool = false

    private var session: WCSession?

    private override init() {
        super.init()
    }

    // MARK: - Session Activation

    /// Activate the WCSession. Call this at app launch.
    func activate() {
        guard WCSession.isSupported() else { return }
        session = WCSession.default
        session?.delegate = self
        session?.activate()
    }

    // MARK: - Send Preset Activation

    /// Send a message to the iPhone requesting activation of the given preset.
    /// - Parameter presetID: The UUID of the LocationPreset to activate.
    func activatePreset(_ presetID: UUID) {
        guard let session = session, session.isReachable else {
            currentStatus = WatchStatus(
                phase: .error,
                message: "iPhone not reachable",
                presetID: presetID
            )
            return
        }

        let message: [String: Any] = [
            WatchMessageKey.action: WatchMessageKey.activatePreset,
            WatchMessageKey.presetID: presetID.uuidString
        ]

        currentStatus = WatchStatus(
            phase: .connecting,
            message: "Connecting…",
            presetID: presetID
        )

        session.sendMessage(message, replyHandler: nil) { [weak self] error in
            DispatchQueue.main.async {
                self?.currentStatus = WatchStatus(
                    phase: .error,
                    message: "Send failed: \(error.localizedDescription)",
                    presetID: presetID
                )
            }
        }
    }

    // MARK: - Helpers

    private func decodePresets(from data: Data) {
        do {
            let decoded = try JSONDecoder().decode([WatchLocationPreset].self, from: data)
            DispatchQueue.main.async {
                self.presets = decoded.sorted { $0.usageCount > $1.usageCount }
            }
        } catch {
            print("[WatchSessionManager] Failed to decode presets: \(error)")
        }
    }

    private func decodeStatus(from data: Data) {
        do {
            let decoded = try JSONDecoder().decode(WatchStatus.self, from: data)
            DispatchQueue.main.async {
                self.currentStatus = decoded
            }
        } catch {
            print("[WatchSessionManager] Failed to decode status: \(error)")
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isPhoneReachable = session.isReachable
        }
    }

    /// Receive real-time messages from iPhone (status updates).
    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if let statusBase64 = message[WatchMessageKey.statusData] as? String,
           let data = Data(base64Encoded: statusBase64) {
            decodeStatus(from: data)
        }
    }

    /// Receive user info transfers from iPhone (preset sync).
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let presetsBase64 = userInfo[WatchMessageKey.presetsData] as? String,
           let data = Data(base64Encoded: presetsBase64) {
            decodePresets(from: data)
        }
    }

    /// Receive application context updates (preset sync fallback).
    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        if let presetsBase64 = applicationContext[WatchMessageKey.presetsData] as? String,
           let data = Data(base64Encoded: presetsBase64) {
            decodePresets(from: data)
        }
    }
}
