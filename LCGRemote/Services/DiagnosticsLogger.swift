import Foundation

// MARK: - DiagnosticsLogger

/// A bounded-buffer diagnostics logger that records command execution history.
/// Provides a simple facade for the ViewModel layer to log and retrieve command entries.
/// Enforces a maximum of 100 entries, pruning the oldest by timestamp when the cap is exceeded.
///
/// Uses JSON file-based persistence (iOS 16 compatible) via the app's Documents directory.
/// For the SwiftData path (iOS 17+), the `SwiftDataPersistenceService` handles its own pruning
/// internally; this logger provides the unified API regardless of backend.
///
/// Validates: Requirements 16.4
final class DiagnosticsLogger: ObservableObject {

    // MARK: - Published State

    /// The most recently loaded log entries, in chronological order (oldest first).
    @Published var recentLogs: [DiagnosticsEntry] = []

    // MARK: - Configuration

    /// Maximum number of log entries to retain.
    let maxEntries: Int

    // MARK: - Private Storage

    private let logsFile = "diagnostics_logs.json"
    private let fileManager = FileManager.default

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var logsFileURL: URL {
        documentsDirectory.appendingPathComponent(logsFile)
    }

    // MARK: - Initialization

    /// Creates a new DiagnosticsLogger.
    /// - Parameter maxEntries: The maximum number of log entries to retain (default: 100).
    init(maxEntries: Int = 100) {
        self.maxEntries = maxEntries
    }

    // MARK: - Public API

    /// Logs a command execution entry and enforces the bounded buffer cap.
    /// - Parameters:
    ///   - deviceName: The name or identifier of the device the command was sent to.
    ///   - commandType: The type of command (e.g., "floorSelect", "callElevator", "goHome").
    ///   - outcome: The result of the command execution.
    func logCommand(deviceName: String, commandType: String, outcome: Outcome) {
        let entry = DiagnosticsEntry(
            id: UUID(),
            timestamp: Date(),
            deviceName: deviceName,
            commandType: commandType,
            outcome: outcome
        )

        var logs = loadAllLogs()
        logs.append(entry)

        // Enforce bounded buffer: keep only the most recent `maxEntries` entries
        if logs.count > maxEntries {
            // Sort by timestamp to ensure we keep the most recent
            logs.sort { $0.timestamp < $1.timestamp }
            // Remove oldest entries to bring count down to maxEntries
            logs = Array(logs.suffix(maxEntries))
        }

        saveLogs(logs)

        // Update published state (chronological order, oldest first)
        recentLogs = logs.sorted { $0.timestamp < $1.timestamp }
    }

    /// Fetches the most recent log entries up to the specified limit, in chronological order.
    /// - Parameter limit: Maximum number of entries to return (default: 100).
    /// - Returns: Log entries sorted by timestamp ascending (oldest first), capped at `limit`.
    func fetchRecentLogs(limit: Int = 100) -> [DiagnosticsEntry] {
        let logs = loadAllLogs()
        // Sort chronologically (oldest first)
        let sorted = logs.sorted { $0.timestamp < $1.timestamp }
        // Return the most recent `limit` entries
        if sorted.count > limit {
            return Array(sorted.suffix(limit))
        }
        return sorted
    }

    /// Reloads the logs from disk and updates the published `recentLogs` property.
    func loadLogs() {
        recentLogs = fetchRecentLogs(limit: maxEntries)
    }

    /// Clears all diagnostics log entries.
    func clearLogs() {
        saveLogs([])
        recentLogs = []
    }

    // MARK: - Private Helpers

    /// Loads all log entries from the JSON file on disk.
    private func loadAllLogs() -> [DiagnosticsEntry] {
        guard fileManager.fileExists(atPath: logsFileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: logsFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode([DiagnosticsEntry].self, from: data)
        } catch {
            return []
        }
    }

    /// Persists the given log entries array to the JSON file on disk.
    private func saveLogs(_ logs: [DiagnosticsEntry]) {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(logs)
            try data.write(to: logsFileURL, options: .atomic)
        } catch {
            // Silently fail on write errors — diagnostics logging should never crash the app
        }
    }
}
