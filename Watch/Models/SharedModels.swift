import Foundation

// MARK: - Watch-side LocationPreset (mirrored from iPhone target)

/// Minimal representation of a Location Preset for Watch display and activation.
struct WatchLocationPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var usageCount: Int
    var sortOrder: Int
}

// MARK: - WatchStatus

/// Status phases relayed from the iPhone during preset execution.
struct WatchStatus: Codable, Hashable {
    let phase: WatchPhase
    let message: String
    let presetID: UUID?

    enum WatchPhase: String, Codable, Hashable {
        case connecting
        case calling
        case pressing
        case done
        case error
    }
}

// MARK: - Watch Message Keys

/// Constants for WatchConnectivity message dictionaries.
enum WatchMessageKey {
    static let action = "action"
    static let presetID = "presetID"
    static let presetsData = "presetsData"
    static let statusData = "statusData"

    // Actions
    static let activatePreset = "activatePreset"
}
