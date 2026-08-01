import Combine
import Foundation

/// ViewModel driving the Presets View. Manages location preset CRUD operations,
/// multi-step preset execution via BLEService, and persistence through
/// JSONPersistenceService. Presets are displayed sorted by usage count descending.
@MainActor
final class PresetsViewModel<Service: BLEServiceProtocol>: ObservableObject {
    // MARK: - Published Properties

    @Published var presets: [LocationPreset] = []
    @Published var isExecuting: Bool = false
    @Published var currentPhase: PresetPhase? = nil
    @Published var executionProgress: Double = 0.0
    @Published var errorMessage: String? = nil
    @Published var showError: Bool = false

    // MARK: - Dependencies

    private let bleService: Service
    private let persistenceService: JSONPersistenceService
    private let hapticsService: HapticsService

    // MARK: - Initializer

    init(bleService: Service, persistenceService: JSONPersistenceService, hapticsService: HapticsService) {
        self.bleService = bleService
        self.persistenceService = persistenceService
        self.hapticsService = hapticsService

        loadPresets()
    }

    // MARK: - Preset Execution (Requirements 6.2, 6.3, 6.4, 6.7)

    /// Executes a multi-step preset sequence via the BLE service.
    /// Updates `currentPhase` and `executionProgress` as each phase completes.
    /// Shows an error alert if a required device is unavailable.
    func executePreset(_ preset: LocationPreset) {
        // Check device availability (Requirement 6.7)
        if let exteriorID = preset.exteriorDeviceID {
            let exteriorDevice = SeedData.devices.first { $0.id == exteriorID }
            if let device = exteriorDevice, !device.isReachable {
                errorMessage = "Device \"\(device.name)\" is not reachable."
                showError = true
                hapticsService.commandError()
                return
            }
        }

        if let interiorID = preset.interiorDeviceID {
            let interiorDevice = SeedData.devices.first { $0.id == interiorID }
            if let device = interiorDevice, !device.isReachable {
                errorMessage = "Device \"\(device.name)\" is not reachable."
                showError = true
                hapticsService.commandError()
                return
            }
        }

        isExecuting = true
        currentPhase = nil
        executionProgress = 0.0

        hapticsService.buttonTap()

        bleService.executePresetSequence(preset: preset, onPhaseChange: { [weak self] phase in
            guard let self = self else { return }
            self.currentPhase = phase
            self.updateProgress(for: phase)
        }, completion: { [weak self] success in
            guard let self = self else { return }
            self.isExecuting = false

            if success {
                self.hapticsService.commandSuccess()
                self.incrementUsageCount(for: preset)
            } else {
                self.hapticsService.commandError()
                let detail = self.bleService.statusMessage
                self.errorMessage = detail.isEmpty ? "Preset execution failed." : detail
                self.showError = true
            }
        })
    }

    // MARK: - CRUD Operations (Requirements 6.5, 6.6)

    /// Creates a new location preset and persists it.
    func createPreset(name: String, exteriorID: String?, interiorID: String?, floorID: UUID?) {
        let nextSortOrder = (presets.map(\.sortOrder).max() ?? -1) + 1
        let newPreset = LocationPreset(
            id: UUID(),
            name: name,
            exteriorDeviceID: exteriorID,
            interiorDeviceID: interiorID,
            targetFloorProfileID: floorID,
            usageCount: 0,
            sortOrder: nextSortOrder
        )
        presets.append(newPreset)
        sortPresets()
        savePresets()
    }

    /// Deletes a preset and persists the change.
    func deletePreset(_ preset: LocationPreset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }

    /// Edits the name of an existing preset and persists the change.
    func editPreset(_ preset: LocationPreset, name: String) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].name = name
        savePresets()
    }

    /// Updates an existing preset with new values and persists the change.
    func updatePreset(_ preset: LocationPreset, name: String, exteriorID: String?, interiorID: String?, floorID: UUID?) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].name = name
        presets[index].exteriorDeviceID = exteriorID
        presets[index].interiorDeviceID = interiorID
        presets[index].targetFloorProfileID = floorID
        savePresets()
    }

    // MARK: - Private Helpers

    /// Loads presets from persistence, merging with SeedData defaults.
    /// User data takes priority over defaults for matching IDs.
    private func loadPresets() {
        let persisted = persistenceService.loadPresets()

        if persisted.isEmpty {
            // No user data — use seed defaults
            presets = SeedData.defaultPresets
        } else {
            // Merge: user data takes priority over defaults (Requirement 13.4)
            let persistedIDs = Set(persisted.map(\.id))
            let nonOverlappingDefaults = SeedData.defaultPresets.filter { !persistedIDs.contains($0.id) }
            presets = persisted + nonOverlappingDefaults
        }

        sortPresets()
    }

    /// Sorts presets by usage count descending for display (most-used first).
    private func sortPresets() {
        presets.sort { $0.usageCount > $1.usageCount }
    }

    /// Persists the current presets array to JSON.
    private func savePresets() {
        do {
            try persistenceService.savePresets(presets)
        } catch {
            // Persistence error — non-fatal for prototype
        }
    }

    /// Increments the usage count for a preset after successful execution.
    private func incrementUsageCount(for preset: LocationPreset) {
        guard let index = presets.firstIndex(where: { $0.id == preset.id }) else { return }
        presets[index].usageCount += 1
        sortPresets()
        savePresets()
    }

    /// Maps a PresetPhase to a progress value (0.0 to 1.0).
    private func updateProgress(for phase: PresetPhase) {
        switch phase {
        case .connectingExterior:
            executionProgress = 0.2
        case .callingElevator:
            executionProgress = 0.4
        case .connectingInterior:
            executionProgress = 0.6
        case .selectingFloor:
            executionProgress = 0.8
        case .done:
            executionProgress = 1.0
        }
    }
}
