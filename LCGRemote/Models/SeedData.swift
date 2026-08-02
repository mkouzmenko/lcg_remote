import Foundation

/// Hardcoded default data for the LCG Remote Prototype.
/// Provides mock devices, elevator configs, and diagnostics entries
/// used to populate the UI before any user modifications.
enum SeedData {
    // MARK: - Mock Devices

    static let devices: [BLEDevice] = [
        BLEDevice(id: "interior-lobby", name: "LiftGateIn-Lobby", unitType: .interior, rssi: -45, isReachable: true),
        BLEDevice(id: "interior-office", name: "LiftGateIn-Office", unitType: .interior, rssi: -62, isReachable: true),
        BLEDevice(id: "exterior-main", name: "LiftGateEx-MainEntry", unitType: .exterior, rssi: -38, isReachable: true),
    ]

    // MARK: - Default Elevator Config

    static let defaultElevators: [ElevatorConfig] = [
        ElevatorConfig(
            id: UUID(),
            name: "Elevator A",
            interiorDeviceID: nil,
            interiorDeviceName: nil,
            floorButtons: [
                FloorButtonConfig(id: UUID(), label: "Lobby", x: 10, y: 20, z: 30, sortOrder: 0),
                FloorButtonConfig(id: UUID(), label: "1", x: 10, y: 50, z: 30, sortOrder: 1),
                FloorButtonConfig(id: UUID(), label: "2", x: 10, y: 80, z: 30, sortOrder: 2),
                FloorButtonConfig(id: UUID(), label: "3", x: 10, y: 110, z: 30, sortOrder: 3),
            ],
            exteriorButtons: [
                ExteriorButtonConfig(id: UUID(), label: "Call Elevator", deviceID: nil, deviceName: nil, x: 50, y: 100, z: 30, sortOrder: 0),
            ]
        )
    ]

    // MARK: - Onboarding Device

    static let onboardingDevice = BLEDevice(
        id: "interior-demo", name: "LiftGateIn-Demo", unitType: .interior, rssi: -40, isReachable: true
    )

    // MARK: - Default Presets (Legacy)

    static let defaultPresets: [LocationPreset] = [
        LocationPreset(
            id: UUID(),
            name: "Go to Office",
            exteriorDeviceID: "exterior-main",
            interiorDeviceID: "interior-lobby",
            targetFloorProfileID: nil,
            usageCount: 5,
            sortOrder: 0
        ),
        LocationPreset(
            id: UUID(),
            name: "Go to Lobby",
            exteriorDeviceID: "exterior-main",
            interiorDeviceID: "interior-office",
            targetFloorProfileID: nil,
            usageCount: 3,
            sortOrder: 1
        ),
    ]

    // MARK: - Default Floor Profiles (Legacy compatibility for PresetsView)

    static let defaultButtonMap = LegacyButtonMap(
        profiles: [
            FloorProfile(id: UUID(), label: "Lobby", x: 10, y: 20, z: 30, sortOrder: 0),
            FloorProfile(id: UUID(), label: "1", x: 10, y: 50, z: 30, sortOrder: 1),
            FloorProfile(id: UUID(), label: "2", x: 10, y: 80, z: 30, sortOrder: 2),
            FloorProfile(id: UUID(), label: "3", x: 10, y: 110, z: 30, sortOrder: 3),
        ]
    )

    /// Minimal legacy structure to satisfy PresetsView's use of `SeedData.defaultButtonMap.profiles`.
    struct LegacyButtonMap {
        let profiles: [FloorProfile]
    }

    // MARK: - Sample Diagnostics

    static let sampleDiagnostics: [DiagnosticsEntry] = [
        DiagnosticsEntry(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-6 * 24 * 3600),
            deviceName: "LiftGateIn-Lobby",
            commandType: "Floor Select",
            outcome: .success
        ),
        DiagnosticsEntry(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-4 * 24 * 3600 - 3600),
            deviceName: "LiftGateEx-MainEntry",
            commandType: "Call Elevator",
            outcome: .success
        ),
        DiagnosticsEntry(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-3 * 24 * 3600),
            deviceName: "LiftGateIn-Office",
            commandType: "Floor Select",
            outcome: .error
        ),
        DiagnosticsEntry(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-1 * 24 * 3600 - 7200),
            deviceName: "LiftGateIn-Lobby",
            commandType: "Call Elevator",
            outcome: .timeout
        ),
        DiagnosticsEntry(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-2 * 3600),
            deviceName: "LiftGateEx-MainEntry",
            commandType: "Call Elevator",
            outcome: .success
        ),
    ]
}
