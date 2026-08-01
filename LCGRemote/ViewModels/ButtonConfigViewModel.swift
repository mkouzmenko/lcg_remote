import Foundation
import SwiftUI

/// ViewModel managing button configuration: add, edit, delete, reorder, test.
/// Persists changes via JSONPersistenceService and triggers test commands via BLEService.
@MainActor
final class ButtonConfigViewModel<Service: BLEServiceProtocol>: ObservableObject {
    // MARK: - Published Properties

    @Published var configs: [ButtonConfig] = []

    // MARK: - Dependencies

    private let bleService: Service
    private let persistenceService: JSONPersistenceService

    // MARK: - Initialization

    init(bleService: Service, persistenceService: JSONPersistenceService) {
        self.bleService = bleService
        self.persistenceService = persistenceService
        loadConfigs()
    }

    // MARK: - Public API

    /// Adds a new button config.
    func addConfig(label: String, deviceType: UnitType, x: Int, y: Int, z: Int) {
        let newConfig = ButtonConfig(
            id: UUID(),
            label: label,
            deviceType: deviceType,
            x: x,
            y: y,
            z: z,
            sortOrder: configs.count
        )
        configs.append(newConfig)
        persist()
    }

    /// Updates an existing button config.
    func updateConfig(_ config: ButtonConfig, label: String, deviceType: UnitType, x: Int, y: Int, z: Int) {
        guard let index = configs.firstIndex(where: { $0.id == config.id }) else { return }
        configs[index].label = label
        configs[index].deviceType = deviceType
        configs[index].x = x
        configs[index].y = y
        configs[index].z = z
        persist()
    }

    /// Deletes a button config.
    func deleteConfig(_ config: ButtonConfig) {
        configs.removeAll { $0.id == config.id }
        reindexSortOrders()
        persist()
    }

    /// Reorders button configs.
    func reorderConfigs(from source: IndexSet, to destination: Int) {
        configs.move(fromOffsets: source, toOffset: destination)
        reindexSortOrders()
        persist()
    }

    /// Triggers a test command for the given config via the BLE service.
    func testConfig(_ config: ButtonConfig) {
        bleService.sendCommand(buttonConfig: config)
    }

    // MARK: - Private

    private func loadConfigs() {
        let persisted = persistenceService.loadButtonConfigs()
        if persisted.isEmpty {
            configs = SeedData.defaultButtonConfigs
        } else {
            configs = persisted.sorted { $0.sortOrder < $1.sortOrder }
        }
    }

    private func persist() {
        try? persistenceService.saveButtonConfigs(configs)
    }

    private func reindexSortOrders() {
        for index in configs.indices {
            configs[index].sortOrder = index
        }
    }
}
