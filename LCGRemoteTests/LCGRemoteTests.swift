import Testing
import Foundation
@testable import LCGRemote

@Test func mockDeviceCreation() async throws {
    let device = MockDevice(
        id: "test-device",
        name: "TestDevice",
        unitType: .interior,
        rssi: -50
    )

    #expect(device.id == "test-device")
    #expect(device.name == "TestDevice")
    #expect(device.unitType == .interior)
    #expect(device.rssi == -50)
    #expect(device.isReachable == true)
}

@Test func floorProfileCreation() async throws {
    let profile = FloorProfile(
        id: UUID(),
        label: "Lobby",
        x: 10,
        y: 20,
        z: 30,
        sortOrder: 0
    )

    #expect(profile.label == "Lobby")
    #expect(profile.x == 10)
    #expect(profile.y == 20)
    #expect(profile.z == 30)
    #expect(profile.sortOrder == 0)
}
