import Foundation

// MARK: - PersistenceServiceProtocol

/// Protocol abstraction for data persistence operations.
/// Both SwiftData (iOS 17+) and JSON-based fallback (iOS 16) implementations conform to this.
/// Validates: Requirements 5.5, 5.6, 6.4, 13.4, 13.5
protocol PersistenceServiceProtocol {
    associatedtype ButtonMapType
    associatedtype LocationPresetType
    associatedtype SavedDeviceType
    associatedtype CommandLogEntryType

    func saveButtonMap(_ map: ButtonMapType) throws
    func fetchButtonMap(for deviceUUID: UUID) throws -> ButtonMapType?
    func deleteButtonMap(_ map: ButtonMapType) throws
    func saveLocationPreset(_ preset: LocationPresetType) throws
    func fetchLocationPresets() throws -> [LocationPresetType]
    func saveDevice(_ device: SavedDeviceType) throws
    func fetchSavedDevices() throws -> [SavedDeviceType]
    func logCommand(_ entry: CommandLogEntryType) throws
    func fetchRecentLogs(limit: Int) throws -> [CommandLogEntryType]
}

// MARK: - SwiftData Implementation (iOS 17+)

#if canImport(SwiftData)
import SwiftData

@available(iOS 17, macOS 14, *)
final class SwiftDataPersistenceService: PersistenceServiceProtocol {

    typealias ButtonMapType = SDButtonMap
    typealias LocationPresetType = SDLocationPreset
    typealias SavedDeviceType = SDSavedDevice
    typealias CommandLogEntryType = SDCommandLogEntry

    private let modelContainer: ModelContainer
    private let modelContext: ModelContext

    /// Initializes the service with a SwiftData ModelContainer configured for all LCG schemas.
    /// - Parameter inMemory: If true, uses in-memory storage (useful for testing/previews).
    init(inMemory: Bool = false) throws {
        let schema = Schema([
            SDSavedDevice.self,
            SDButtonMap.self,
            SDFloorProfile.self,
            SDLocationPreset.self,
            SDCommandLogEntry.self
        ])

        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            configuration = ModelConfiguration(
                schema: schema
            )
        }

        self.modelContainer = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        self.modelContext = ModelContext(modelContainer)
    }

    /// Allows injection of an external ModelContainer (e.g., for shared container scenarios).
    init(container: ModelContainer) {
        self.modelContainer = container
        self.modelContext = ModelContext(container)
    }

    // MARK: - ButtonMap Operations

    /// Saves or updates a ButtonMap. If a map with the same id exists, it is updated.
    /// The cascade delete rule on SDButtonMap.floorProfiles ensures FloorProfiles
    /// are removed when their parent ButtonMap is deleted.
    func saveButtonMap(_ map: SDButtonMap) throws {
        modelContext.insert(map)
        try modelContext.save()
    }

    /// Fetches the ButtonMap associated with a specific device UUID.
    func fetchButtonMap(for deviceUUID: UUID) throws -> SDButtonMap? {
        let predicate = #Predicate<SDButtonMap> { buttonMap in
            buttonMap.deviceUUID == deviceUUID
        }
        var descriptor = FetchDescriptor<SDButtonMap>(predicate: predicate)
        descriptor.fetchLimit = 1
        let results = try modelContext.fetch(descriptor)
        return results.first
    }

    /// Deletes a ButtonMap and its associated FloorProfiles (via cascade delete rule).
    func deleteButtonMap(_ map: SDButtonMap) throws {
        modelContext.delete(map)
        try modelContext.save()
    }

    // MARK: - LocationPreset Operations

    /// Saves or updates a LocationPreset.
    func saveLocationPreset(_ preset: SDLocationPreset) throws {
        modelContext.insert(preset)
        try modelContext.save()
    }

    /// Fetches all LocationPresets, sorted by usage count descending (most used first).
    func fetchLocationPresets() throws -> [SDLocationPreset] {
        let descriptor = FetchDescriptor<SDLocationPreset>(
            sortBy: [SortDescriptor(\.usageCount, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - SavedDevice Operations

    /// Saves or updates a paired device record.
    func saveDevice(_ device: SDSavedDevice) throws {
        modelContext.insert(device)
        try modelContext.save()
    }

    /// Fetches all saved devices, sorted by last-seen date descending.
    func fetchSavedDevices() throws -> [SDSavedDevice] {
        let descriptor = FetchDescriptor<SDSavedDevice>(
            sortBy: [SortDescriptor(\.lastSeenDate, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Command Log Operations

    /// Logs a command execution entry for diagnostics.
    /// Maintains a bounded buffer of 100 most recent entries.
    func logCommand(_ entry: SDCommandLogEntry) throws {
        modelContext.insert(entry)
        try modelContext.save()

        // Enforce bounded buffer: keep only the 100 most recent entries
        try pruneOldLogs()
    }

    /// Fetches the most recent command log entries, up to the specified limit.
    func fetchRecentLogs(limit: Int) throws -> [SDCommandLogEntry] {
        var descriptor = FetchDescriptor<SDCommandLogEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Private Helpers

    /// Removes old log entries beyond the 100-entry cap.
    private func pruneOldLogs() throws {
        let countDescriptor = FetchDescriptor<SDCommandLogEntry>()
        let totalCount = try modelContext.fetchCount(countDescriptor)

        guard totalCount > 100 else { return }

        // Fetch entries sorted oldest first, skip the 100 most recent
        var descriptor = FetchDescriptor<SDCommandLogEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        descriptor.fetchLimit = totalCount - 100

        let entriesToDelete = try modelContext.fetch(descriptor)
        for entry in entriesToDelete {
            modelContext.delete(entry)
        }
        try modelContext.save()
    }
}
#endif
