import Foundation
import SwiftUI

/// ViewModel managing floor profile calibration: add, edit, delete, reorder, test, and validate.
/// Persists changes via JSONPersistenceService and triggers test commands via MockBLEService.
final class CalibrationViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var profiles: [FloorProfile] = []
    @Published var validationErrors: [String: String] = [:]

    // MARK: - Dependencies

    private let bleService: MockBLEService
    private let persistenceService: JSONPersistenceService

    // MARK: - Initialization

    init(bleService: MockBLEService, persistenceService: JSONPersistenceService) {
        self.bleService = bleService
        self.persistenceService = persistenceService
        loadProfiles()
    }

    // MARK: - Public API

    /// Adds a new floor profile after validation. Returns `true` if the profile was added successfully.
    @discardableResult
    func addProfile(label: String, x: Int, y: Int, z: Int) -> Bool {
        let errors = validate(x: x, y: y, z: z)
        validationErrors = errors

        guard errors.isEmpty else {
            return false
        }

        let newProfile = FloorProfile(
            id: UUID(),
            label: label,
            x: x,
            y: y,
            z: z,
            sortOrder: profiles.count
        )
        profiles.append(newProfile)
        persist()
        return true
    }

    /// Updates an existing floor profile after validation. Returns `true` if updated successfully.
    @discardableResult
    func updateProfile(_ profile: FloorProfile, label: String, x: Int, y: Int, z: Int) -> Bool {
        let errors = validate(x: x, y: y, z: z)
        validationErrors = errors

        guard errors.isEmpty else {
            return false
        }

        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            return false
        }

        profiles[index].label = label
        profiles[index].x = x
        profiles[index].y = y
        profiles[index].z = z
        persist()
        return true
    }

    /// Deletes a floor profile from the list.
    func deleteProfile(_ profile: FloorProfile) {
        profiles.removeAll { $0.id == profile.id }
        reindexSortOrders()
        persist()
    }

    /// Reorders floor profiles from the given source offsets to the destination index.
    func reorderProfiles(from source: IndexSet, to destination: Int) {
        profiles.move(fromOffsets: source, toOffset: destination)
        reindexSortOrders()
        persist()
    }

    /// Triggers a test command for the given profile via MockBLEService.
    func testProfile(_ profile: FloorProfile) {
        bleService.executeFloorCommand(profile: profile)
    }

    /// Validates X, Y, Z coordinate values.
    /// Returns a dictionary of field-specific error messages. An empty dictionary means all values are valid.
    /// - Keys: "x", "y", "z"
    /// - Values: Human-readable error messages
    func validate(x: Int, y: Int, z: Int) -> [String: String] {
        var errors: [String: String] = [:]

        if x < 0 || x > 144 {
            errors["x"] = "X must be between 0 and 144"
        }
        if y < 0 || y > 208 {
            errors["y"] = "Y must be between 0 and 208"
        }
        if z < 0 || z > 100 {
            errors["z"] = "Z must be between 0 and 100"
        }

        return errors
    }

    // MARK: - Private Helpers

    /// Loads profiles from the persistence service. Falls back to seed data if nothing is persisted.
    private func loadProfiles() {
        let buttonMaps = persistenceService.loadButtonMaps()
        if let firstMap = buttonMaps.first {
            profiles = firstMap.profiles.sorted { $0.sortOrder < $1.sortOrder }
        } else {
            profiles = SeedData.defaultButtonMap.profiles.sorted { $0.sortOrder < $1.sortOrder }
        }
    }

    /// Persists the current profiles into the first ButtonMap in storage.
    private func persist() {
        var buttonMaps = persistenceService.loadButtonMaps()

        if buttonMaps.isEmpty {
            // Create a new ButtonMap based on the seed default
            let newMap = ButtonMap(
                id: SeedData.defaultButtonMap.id,
                name: SeedData.defaultButtonMap.name,
                deviceID: SeedData.defaultButtonMap.deviceID,
                profiles: profiles,
                createdDate: SeedData.defaultButtonMap.createdDate,
                modifiedDate: Date()
            )
            buttonMaps = [newMap]
        } else {
            buttonMaps[0].profiles = profiles
            buttonMaps[0].modifiedDate = Date()
        }

        try? persistenceService.saveButtonMaps(buttonMaps)
    }

    /// Reassigns sort orders to match the current array index.
    private func reindexSortOrders() {
        for index in profiles.indices {
            profiles[index].sortOrder = index
        }
    }
}
