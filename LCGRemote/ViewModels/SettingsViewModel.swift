import Combine
import Foundation

/// ViewModel driving the Settings View. Manages the device list with custom names,
/// diagnostics log display, and reset operations.
/// Requirements: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7
final class SettingsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var devices: [MockDevice] = []
    @Published var diagnosticsLog: [DiagnosticsEntry] = []

    // MARK: - Dependencies

    private let persistenceService: JSONPersistenceService
    private let bleService: MockBLEService
    private var cancellables = Set<AnyCancellable>()

    /// UserDefaults key used by OnboardingViewModel to track onboarding completion.
    private static let onboardingCompletedKey = "hasCompletedOnboarding"

    // MARK: - Initializer

    init(persistenceService: JSONPersistenceService, bleService: MockBLEService) {
        self.persistenceService = persistenceService
        self.bleService = bleService

        loadDevices()
        loadDiagnostics()
        observeConnectionState()
    }

    // MARK: - Device Management (Requirements 7.1, 7.2, 7.7)

    /// Renames a device by persisting a custom name mapping.
    /// The custom name is stored in device_names.json via JSONPersistenceService.
    func renameDevice(_ device: MockDevice, to name: String) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index].name = name

        // Persist device name mapping
        var names = persistenceService.loadDeviceNames()
        names[device.id] = name
        do {
            try persistenceService.saveDeviceNames(names)
        } catch {
            // Persistence error — non-fatal for prototype
        }
    }

    /// Removes a device from the saved device list.
    func forgetDevice(_ device: MockDevice) {
        devices.removeAll { $0.id == device.id }

        // Remove custom name if present
        var names = persistenceService.loadDeviceNames()
        names.removeValue(forKey: device.id)
        do {
            try persistenceService.saveDeviceNames(names)
        } catch {
            // Persistence error — non-fatal for prototype
        }
    }

    // MARK: - Reset Operations (Requirements 7.6, 13.5)

    /// Clears the onboarding completion flag so the onboarding flow is shown on next launch.
    func resetOnboarding() {
        UserDefaults.standard.removeObject(forKey: Self.onboardingCompletedKey)
    }

    /// Clears all persisted JSON data, restoring hardcoded defaults.
    func resetAllData() {
        do {
            try persistenceService.resetAllData()
        } catch {
            // Reset error — non-fatal for prototype
        }

        // Reload devices from seed data (custom names cleared)
        loadDevices()
    }

    // MARK: - Private Helpers

    /// Loads the device list from SeedData, merging any persisted custom names.
    /// Connection status is derived from MockBLEService state.
    private func loadDevices() {
        let customNames = persistenceService.loadDeviceNames()
        devices = SeedData.devices.map { seedDevice in
            var device = seedDevice
            if let customName = customNames[device.id] {
                device.name = customName
            }
            return device
        }
    }

    /// Loads hardcoded sample diagnostics entries.
    private func loadDiagnostics() {
        diagnosticsLog = SeedData.sampleDiagnostics
    }

    /// Observes MockBLEService connection state to reflect device status in the list.
    private func observeConnectionState() {
        bleService.$connectedDevice
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    // MARK: - Computed Helpers

    /// Returns the connection status label for a given device based on MockBLEService state.
    func connectionStatus(for device: MockDevice) -> String {
        if bleService.connectedDevice?.id == device.id {
            return "Connected"
        } else if device.isReachable {
            return "Available"
        } else {
            return "Not in Range"
        }
    }

    /// Returns whether a device is currently connected.
    func isConnected(_ device: MockDevice) -> Bool {
        bleService.connectedDevice?.id == device.id
    }
}
