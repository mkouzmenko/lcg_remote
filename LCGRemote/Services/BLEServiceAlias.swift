import Foundation

/// Conditional type alias that resolves to the appropriate BLEServiceProtocol
/// conformer based on the build target.
/// - Simulator: Uses `MockBLEService` with simulated device interactions.
/// - Device: Uses `BLEAdapter` wrapping real CoreBluetooth communication.
#if targetEnvironment(simulator)
typealias BLEService = MockBLEService
#else
typealias BLEService = BLEAdapter
#endif
