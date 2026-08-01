import Foundation
import SwiftUI

/// Handles reading and writing JSON files for all persisted data.
/// Stores data in the app's Documents directory for easy inspection.
final class JSONPersistenceService: ObservableObject {
    // File names in Documents directory
    private let buttonMapsFile = "button_maps.json"
    private let buttonConfigsFile = "button_configs.json"
    private let presetsFile = "presets.json"
    private let deviceNamesFile = "device_names.json"
    private let deviceGroupsFile = "device_groups.json"

    /// The Documents directory URL for this app.
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: - Private Helpers

    private func fileURL(for fileName: String) -> URL {
        documentsDirectory.appendingPathComponent(fileName)
    }

    private func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    // MARK: - Button Configs

    /// Saves an array of ButtonConfigs to button_configs.json.
    func saveButtonConfigs(_ configs: [ButtonConfig]) throws {
        let data = try encoder().encode(configs)
        try data.write(to: fileURL(for: buttonConfigsFile), options: .atomic)
    }

    /// Loads ButtonConfigs from button_configs.json.
    /// Returns an empty array if the file does not exist or cannot be decoded.
    func loadButtonConfigs() -> [ButtonConfig] {
        let url = fileURL(for: buttonConfigsFile)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder().decode([ButtonConfig].self, from: data)
        } catch {
            return []
        }
    }

    // MARK: - Button Maps

    /// Saves an array of ButtonMaps to button_maps.json.
    func saveButtonMaps(_ maps: [ButtonMap]) throws {
        let data = try encoder().encode(maps)
        try data.write(to: fileURL(for: buttonMapsFile), options: .atomic)
    }

    /// Loads ButtonMaps from button_maps.json.
    /// Returns an empty array if the file does not exist or cannot be decoded.
    func loadButtonMaps() -> [ButtonMap] {
        let url = fileURL(for: buttonMapsFile)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder().decode([ButtonMap].self, from: data)
        } catch {
            return []
        }
    }

    // MARK: - Presets

    /// Saves an array of LocationPresets to presets.json.
    func savePresets(_ presets: [LocationPreset]) throws {
        let data = try encoder().encode(presets)
        try data.write(to: fileURL(for: presetsFile), options: .atomic)
    }

    /// Loads LocationPresets from presets.json.
    /// Returns an empty array if the file does not exist or cannot be decoded.
    func loadPresets() -> [LocationPreset] {
        let url = fileURL(for: presetsFile)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder().decode([LocationPreset].self, from: data)
        } catch {
            return []
        }
    }

    // MARK: - Device Names

    /// Saves a deviceID→customName mapping to device_names.json.
    func saveDeviceNames(_ names: [String: String]) throws {
        let data = try encoder().encode(names)
        try data.write(to: fileURL(for: deviceNamesFile), options: .atomic)
    }

    /// Loads the deviceID→customName mapping from device_names.json.
    /// Returns an empty dictionary if the file does not exist or cannot be decoded.
    func loadDeviceNames() -> [String: String] {
        let url = fileURL(for: deviceNamesFile)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder().decode([String: String].self, from: data)
        } catch {
            return [:]
        }
    }

    // MARK: - Device Groups

    /// Saves a DeviceGroupConfig to device_groups.json.
    func saveDeviceGroups(_ config: DeviceGroupConfig) throws {
        let data = try encoder().encode(config)
        try data.write(to: fileURL(for: deviceGroupsFile), options: .atomic)
    }

    /// Loads DeviceGroupConfig from device_groups.json.
    /// Returns a default empty config if the file does not exist or cannot be decoded.
    func loadDeviceGroups() -> DeviceGroupConfig {
        let url = fileURL(for: deviceGroupsFile)
        guard FileManager.default.fileExists(atPath: url.path) else {
            return DeviceGroupConfig()
        }
        do {
            let data = try Data(contentsOf: url)
            return try decoder().decode(DeviceGroupConfig.self, from: data)
        } catch {
            return DeviceGroupConfig()
        }
    }

    // MARK: - Reset

    /// Deletes all persisted JSON files, restoring the app to a clean state.
    func resetAllData() throws {
        let fileManager = FileManager.default
        let files = [buttonMapsFile, buttonConfigsFile, presetsFile, deviceNamesFile, deviceGroupsFile]
        for fileName in files {
            let url = fileURL(for: fileName)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }
}
