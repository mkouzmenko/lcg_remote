import Foundation

/// Hardcoded default data for the LCG Remote Prototype.
/// Provides mock devices, button maps, presets, and diagnostics entries
/// used to populate the UI before any user modifications.
enum SeedData {
    // MARK: - Mock Devices (Requirement 2.2)

    static let devices: [MockDevice] = [
        MockDevice(id: "interior-lobby", name: "LiftGateIn-Lobby", unitType: .interior, rssi: -45),
        MockDevice(id: "interior-office", name: "LiftGateIn-Office", unitType: .interior, rssi: -62),
        MockDevice(id: "exterior-main", name: "LiftGateEx-MainEntry", unitType: .exterior, rssi: -38),
    ]

    // MARK: - Onboarding Device

    static let onboardingDevice = MockDevice(
        id: "interior-demo", name: "LiftGateIn-Demo", unitType: .interior, rssi: -40
    )

    // MARK: - Default Button Map (Requirement 4.1)

    static let defaultButtonMap = ButtonMap(
        id: UUID(),
        name: "Demo Elevator",
        deviceID: "interior-lobby",
        profiles: [
            FloorProfile(id: UUID(), label: "Lobby", x: 10, y: 20, z: 30, sortOrder: 0),
            FloorProfile(id: UUID(), label: "1", x: 10, y: 50, z: 30, sortOrder: 1),
            FloorProfile(id: UUID(), label: "2", x: 10, y: 80, z: 30, sortOrder: 2),
            FloorProfile(id: UUID(), label: "3", x: 10, y: 110, z: 30, sortOrder: 3),
            FloorProfile(id: UUID(), label: "4", x: 10, y: 140, z: 30, sortOrder: 4),
            FloorProfile(id: UUID(), label: "5", x: 10, y: 170, z: 30, sortOrder: 5),
        ],
        createdDate: Date(),
        modifiedDate: Date()
    )

    // MARK: - Default Presets (Requirement 6.1)

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

    // MARK: - Sample Diagnostics (Requirement 7.4)

    static let sampleDiagnostics: [DiagnosticsEntry] = [
        DiagnosticsEntry(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-6 * 24 * 3600),  // 6 days ago
            deviceName: "LiftGateIn-Lobby",
            commandType: "Floor Select",
            outcome: .success
        ),
        DiagnosticsEntry(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-4 * 24 * 3600 - 3600),  // ~4 days ago
            deviceName: "LiftGateEx-MainEntry",
            commandType: "Call Elevator",
            outcome: .success
        ),
        DiagnosticsEntry(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-3 * 24 * 3600),  // 3 days ago
            deviceName: "LiftGateIn-Office",
            commandType: "Floor Select",
            outcome: .error
        ),
        DiagnosticsEntry(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-1 * 24 * 3600 - 7200),  // ~1 day ago
            deviceName: "LiftGateIn-Lobby",
            commandType: "Call Elevator",
            outcome: .timeout
        ),
        DiagnosticsEntry(
            id: UUID(),
            timestamp: Date().addingTimeInterval(-2 * 3600),  // 2 hours ago
            deviceName: "LiftGateEx-MainEntry",
            commandType: "Call Elevator",
            outcome: .success
        ),
    ]
}
