# Implementation Plan: Real BLE Integration

## Overview

Replace `MockBLEService` and `MockDevice` with a protocol-based abstraction (`BLEServiceProtocol`) throughout the LCGRemote app. Introduce a `BLEDevice` unified model, a `BLEAdapter` wrapping the existing `BLEManager`, refactor `MockBLEService` to conform to the protocol, and update all views/view models to depend on the protocol. The app entry point uses `#if targetEnvironment(simulator)` to select the implementation.

## Tasks

- [x] 1. Define shared types and the BLE service protocol
  - [x] 1.1 Create BLEDevice model, BLEConnectionState, and BLEDeviceStatus enums
    - Create `LCGRemote/Models/BLEDevice.swift` with the `BLEDevice` struct (id: String, name: String, unitType: UnitType, rssi: Int, isReachable: Bool) conforming to Identifiable and Hashable
    - Add `BLEConnectionState` enum (disconnected, connecting, connected) in `LCGRemote/Models/BLEDevice.swift`
    - Add `BLEDeviceStatus` enum (idle, busy, done, error) with CaseIterable in the same file
    - Add `BLEDevice.init(from: DiscoveredDevice)` mapping extension (guarded with `#if canImport(CoreBluetooth)`)
    - _Requirements: 1.1, 2.2, 2.9, 8.5_

  - [x] 1.2 Define BLEServiceProtocol
    - Create `LCGRemote/Protocols/BLEServiceProtocol.swift`
    - Declare `@MainActor protocol BLEServiceProtocol: ObservableObject` with published properties: `discoveredDevices: [BLEDevice]`, `isScanning: Bool`, `connectedDevice: BLEDevice?`, `connectionState: BLEConnectionState`, `deviceStatus: BLEDeviceStatus`, `statusMessage: String`
    - Declare methods: `startScan()`, `stopScan()`, `connect(to: BLEDevice)`, `disconnect()`, `executeFloorCommand(profile: FloorProfile)`, `executeCallCommand()`, `executePresetSequence(preset:onPhaseChange:completion:)`
    - _Requirements: 1.1, 1.2, 1.3_

- [x] 2. Implement the BLEAdapter wrapping BLEManager
  - [x] 2.1 Create BLEAdapter class with scanning and discovery
    - Create `LCGRemote/Services/BLEAdapter.swift` (guarded with `#if canImport(CoreBluetooth)`)
    - Implement `@MainActor final class BLEAdapter: ObservableObject, BLEServiceProtocol`
    - Hold a `BLEManager` instance and an internal `[String: DiscoveredDevice]` lookup dictionary
    - Implement `startScan()` delegating to `BLEManager.startScan()`, subscribing to `bleManager.$discoveredDevices` and mapping to `[BLEDevice]`
    - Implement `stopScan()` delegating to `BLEManager.stopScan()`
    - Forward `bleManager.$isScanning` to the published `isScanning`
    - Handle Bluetooth state: set `statusMessage` to "Bluetooth is not available" when `bluetoothState != .poweredOn`, and "Bluetooth permission denied. Enable in Settings." when `.unauthorized`
    - _Requirements: 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 9.1, 9.2, 9.3_

  - [x] 2.2 Implement BLEAdapter connection lifecycle
    - Implement `connect(to: BLEDevice)`: look up `DiscoveredDevice` from internal dictionary, call `bleManager.connect(to:)` async, update `connectionState` (.connecting → .connected on success, .disconnected on failure with descriptive statusMessage)
    - Implement `disconnect()`: call `bleManager.disconnect(from:)` for connected device, reset `connectedDevice`, `connectionState`, `deviceStatus` to defaults, set `isUserDisconnect` flag
    - Subscribe to `bleManager.$connectedInterior` and `bleManager.$connectedExterior` to update `connectedDevice` as `BLEDevice`
    - Implement auto-reconnect logic: on unexpected disconnect (when `isUserDisconnect == false`), retry up to 3 times
    - _Requirements: 2.4, 2.5, 2.6, 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x] 2.3 Implement BLEAdapter command execution and status feedback
    - Implement `executeFloorCommand(profile:)`: encode via `CommandEncoder.encodeFloorCommand(x:y:z:)`, write each Data chunk via `bleManager.write(data:to:)`, set `deviceStatus = .busy` and `statusMessage = "Pressing button..."`
    - Implement `executeCallCommand()`: encode via `CommandEncoder.encodeCallCommand()`, write to exterior peripheral
    - Subscribe to `bleManager.statusNotificationSubject`: map notification bytes via `DeviceState(fromByte:)` to `BLEDeviceStatus`, update `deviceStatus` and `statusMessage`
    - Implement 5-second command timeout: if no notification received, set `deviceStatus = .error` and `statusMessage = "Command timed out"`
    - Implement auto-reset: `.done` → `.idle` after 1 second, `.error` → `.idle` after 2 seconds
    - _Requirements: 2.7, 2.8, 2.9, 5.1, 5.2, 5.3, 5.4, 5.5, 5.6_

  - [x] 2.4 Implement BLEAdapter preset sequence execution
    - Implement `executePresetSequence(preset:onPhaseChange:completion:)`: connect to exterior device, send call command, connect to interior device, send floor command — in sequence
    - Report phase transitions via `onPhaseChange` callback (connectingExterior, callingElevator, connectingInterior, selectingFloor, done)
    - On any step failure, invoke `completion(false)` and stop subsequent steps
    - On full success, invoke `completion(true)`
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

  - [ ]* 2.5 Write property test for device mapping (Property 1)
    - **Property 1: Device mapping preserves identity and metadata**
    - Generate random DiscoveredDevice-like values (UUID, name string, UnitType, RSSI Int), construct BLEDevice via the mapping initializer, assert id == uuid.uuidString, name preserved, unitType preserved, rssi preserved
    - **Validates: Requirements 2.2**

  - [ ]* 2.6 Write property test for floor command encoding (Property 2)
    - **Property 2: Floor command encoding correctness**
    - Generate random valid triples (x: 0–144, y: 0–208, z: 0–100), encode via `CommandEncoder.encodeFloorCommand`, assert exactly 3 Data values, each first byte == 0x01 + coordinate, decode back by subtracting 0x01 and assert round-trip equality
    - **Validates: Requirements 2.7**

  - [ ]* 2.7 Write property test for notification byte mapping (Property 3)
    - **Property 3: Notification byte to DeviceStatus mapping**
    - Generate random UInt8 values (0–255), map through `DeviceState(fromByte:)`, assert: 0→idle, 1→busy, 2→done, 3→error, >3→error. Then map DeviceState to BLEDeviceStatus and assert semantic preservation
    - **Validates: Requirements 2.9, 5.2, 5.3**

  - [ ]* 2.8 Write property test for device filtering (Property 4)
    - **Property 4: Device filtering and classification**
    - Generate random sets of peripherals with mixed service UUIDs (interior UUID, exterior UUID, unrelated UUIDs), apply `BLEManager.classifyDevice` filtering logic, assert only interior/exterior UUIDs are included with correct `.interior`/`.exterior` classification
    - **Validates: Requirements 3.1, 3.2**

  - [ ]* 2.9 Write property test for RSSI updates (Property 5)
    - **Property 5: RSSI reflects most recent advertisement**
    - Generate random non-empty sequences of RSSI Int values for a device, apply updates in order, assert final published rssi equals last value in sequence
    - **Validates: Requirements 3.5**

- [x] 3. Checkpoint - Ensure BLEAdapter compiles
  - Ensure all tests pass, ask the user if questions arise.

- [x] 4. Refactor MockBLEService to conform to BLEServiceProtocol
  - [x] 4.1 Update MockBLEService to use shared types and conform to protocol
    - Remove internal `ConnectionState` and `DeviceStatus` enums from MockBLEService
    - Change `@Published var discoveredDevices: [MockDevice]` to `@Published var discoveredDevices: [BLEDevice]`
    - Change `@Published var connectedDevice: MockDevice?` to `@Published var connectedDevice: BLEDevice?`
    - Change `@Published var connectionState: ConnectionState` to `@Published var connectionState: BLEConnectionState`
    - Change `@Published var deviceStatus: DeviceStatus` to `@Published var deviceStatus: BLEDeviceStatus`
    - Update `connect(to:)` to accept `BLEDevice` instead of `MockDevice`
    - Add `@MainActor` and `: BLEServiceProtocol` conformance
    - Update SeedData.devices to return `[BLEDevice]` (convert `MockDevice` references to `BLEDevice`)
    - Keep all timer-based simulation logic unchanged
    - _Requirements: 8.1, 8.3_

  - [ ]* 4.2 Write unit tests for MockBLEService protocol conformance
    - Test that MockBLEService conforms to BLEServiceProtocol
    - Test scanning produces BLEDevice instances
    - Test connect/disconnect state transitions use BLEConnectionState/BLEDeviceStatus
    - _Requirements: 8.3_

- [x] 5. Update all view models to use BLEServiceProtocol
  - [x] 5.1 Refactor ScanViewModel to generic protocol dependency
    - Change `private let bleService: MockBLEService` to generic `<Service: BLEServiceProtocol>`
    - Update `@Published var devices: [MockDevice]` to `@Published var devices: [BLEDevice]`
    - Update `connect(to:)` to accept `BLEDevice`
    - _Requirements: 1.3, 8.5_

  - [x] 5.2 Refactor DeviceControlViewModel to generic protocol dependency
    - Change `private let bleService: MockBLEService` to generic `<Service: BLEServiceProtocol>`
    - Update `@Published var connectedDevice: MockDevice?` to `@Published var connectedDevice: BLEDevice?`
    - Replace `MockBLEService.DeviceStatus` references with `BLEDeviceStatus`
    - _Requirements: 1.3, 8.5_

  - [x] 5.3 Refactor PresetsViewModel to generic protocol dependency
    - Change `private let bleService: MockBLEService` to generic `<Service: BLEServiceProtocol>`
    - Update device availability checks to use `BLEDevice` (replace `SeedData.devices` lookup with protocol-compatible logic)
    - _Requirements: 1.3, 8.5_

  - [x] 5.4 Refactor OnboardingViewModel to generic protocol dependency
    - Change `private let bleService: MockBLEService` to generic `<Service: BLEServiceProtocol>`
    - Update `selectDevice()` to create a `BLEDevice` from `SeedData.onboardingDevice` and call `connect(to:)` with it
    - _Requirements: 1.3, 7.1, 7.2, 7.3, 8.5_

  - [x] 5.5 Refactor SettingsViewModel to generic protocol dependency
    - Change `private let bleService: MockBLEService` to generic `<Service: BLEServiceProtocol>`
    - Update `@Published var devices: [MockDevice]` to `@Published var devices: [BLEDevice]`
    - Update `renameDevice`, `forgetDevice`, `connectionStatus`, `isConnected` to use `BLEDevice`
    - _Requirements: 1.3, 8.5_

  - [x] 5.6 Refactor CalibrationViewModel to generic protocol dependency
    - Change `private let bleService: MockBLEService` to generic `<Service: BLEServiceProtocol>`
    - `testProfile` already calls `executeFloorCommand(profile:)` which exists on the protocol
    - _Requirements: 1.3, 8.5_

- [x] 6. Checkpoint - Ensure view models compile with protocol
  - Ensure all tests pass, ask the user if questions arise.

- [x] 7. Update all views to use protocol-typed dependencies
  - [x] 7.1 Refactor ContentView to use protocol type
    - Replace `@EnvironmentObject var mockBLEService: MockBLEService` with a generic approach or type-erased environment object matching the conditional compilation pattern
    - Update all child view instantiations to pass the protocol-typed service
    - Remove all `MockBLEService` and `MockDevice` type references
    - _Requirements: 1.4, 8.4, 8.5_

  - [x] 7.2 Refactor ScanView to use BLEDevice and protocol type
    - Replace `@EnvironmentObject var mockBLEService: MockBLEService` with protocol-typed dependency
    - Update `DeviceRow` to accept `BLEDevice` instead of `MockDevice`
    - Update accessibility label helpers to use `BLEDevice`
    - _Requirements: 8.4, 8.5_

  - [x] 7.3 Refactor DeviceControlView to use BLEDeviceStatus
    - Replace `MockBLEService.DeviceStatus` references with `BLEDeviceStatus`
    - Update `announceStatusChange` helper to use `BLEDeviceStatus`
    - _Requirements: 8.4, 8.5_

  - [x] 7.4 Refactor PresetsView to use BLEDevice
    - Replace `MockDevice` references in device pickers with `BLEDevice`
    - Update `exteriorDevices` and `interiorDevices` computed properties to use `[BLEDevice]`
    - _Requirements: 8.4, 8.5_

  - [x] 7.5 Refactor SettingsView to use BLEDevice
    - Replace `@EnvironmentObject var bleService: MockBLEService` with protocol-typed dependency
    - Replace `MockDevice` references with `BLEDevice` (deviceRow, statusColor, accessibilityLabel, commitRename, deviceToForget)
    - _Requirements: 8.4, 8.5_

  - [x] 7.6 Refactor OnboardingView to use protocol type
    - Replace `@EnvironmentObject var mockBLEService: MockBLEService` with protocol-typed dependency
    - Update `init(bleService:)` parameter type
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 8.4, 8.5_

  - [x] 7.7 Refactor CalibrationView to use protocol type
    - Update `init(bleService:persistenceService:)` parameter type from `MockBLEService` to protocol-typed
    - _Requirements: 8.4, 8.5_

- [x] 8. Checkpoint - Ensure all views compile without MockBLEService/MockDevice references
  - Ensure all tests pass, ask the user if questions arise.

- [x] 9. Update app entry point and SeedData
  - [x] 9.1 Update LCGRemoteApp with conditional compilation toggle
    - Add `#if targetEnvironment(simulator)` block that creates `MockBLEService` instance
    - Add `#else` block that creates `BLEAdapter` instance
    - Inject the selected implementation as `@EnvironmentObject` into the view hierarchy
    - Ensure both code paths use the same environment object key/type mechanism
    - _Requirements: 1.4, 8.1, 8.2, 8.4_

  - [x] 9.2 Update SeedData to use BLEDevice
    - Convert `SeedData.devices` from `[MockDevice]` to `[BLEDevice]`
    - Convert `SeedData.onboardingDevice` from `MockDevice` to `BLEDevice`
    - Update any `MockDevice` references in default presets or button maps
    - _Requirements: 8.5_

  - [x] 9.3 Add NSBluetoothAlwaysUsageDescription to Info.plist
    - Add the `NSBluetoothAlwaysUsageDescription` key with a user-facing explanation (e.g., "LCGRemote uses Bluetooth to communicate with LCG elevator hardware for floor selection and elevator calling.")
    - _Requirements: 9.4_

- [x] 10. Checkpoint - Ensure full app compiles on simulator and device targets
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Final cleanup and integration tests
  - [x] 11.1 Remove MockDevice struct and verify no remaining references
    - Remove `MockDevice` struct from `Models.swift`
    - Grep for any remaining `MockDevice` references across the project and fix them
    - Grep for any remaining direct `MockBLEService` references outside of the service file itself and `LCGRemoteApp.swift`
    - _Requirements: 8.5_

  - [ ]* 11.2 Write unit tests for BLEAdapter connection state machine
    - Test `.disconnected` → `.connecting` → `.connected` transitions
    - Test disconnect resets all published properties to defaults
    - Test auto-reconnect policy: 3 attempts on unexpected disconnect, 0 on user disconnect
    - Test command timeout triggers `.error` status after 5 seconds
    - Test auto-reset: `.done` → `.idle` after 1s, `.error` → `.idle` after 2s
    - _Requirements: 2.4, 2.5, 4.2, 4.3, 5.4, 5.5, 5.6_

  - [ ]* 11.3 Write unit tests for preset sequence execution
    - Test phases execute in correct order (connectingExterior → callingElevator → connectingInterior → selectingFloor → done)
    - Test failure at any step halts execution and calls `completion(false)`
    - Test successful completion calls `completion(true)`
    - _Requirements: 6.1, 6.2, 6.3, 6.4_

- [x] 12. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- Property tests validate universal correctness properties from the design document
- Unit tests validate specific examples and edge cases
- The `#if canImport(CoreBluetooth)` guard is used in BLEAdapter.swift so it only compiles on platforms with CoreBluetooth
- View models use Swift generics (`<Service: BLEServiceProtocol>`) to avoid tight coupling while maintaining type safety
- The `MockDevice` struct is removed last (task 11.1) after all consumers have been migrated to `BLEDevice`

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2"] },
    { "id": 1, "tasks": ["2.1", "4.1"] },
    { "id": 2, "tasks": ["2.2", "2.3", "2.5", "2.6", "2.7", "2.8", "4.2"] },
    { "id": 3, "tasks": ["2.4", "2.9"] },
    { "id": 4, "tasks": ["5.1", "5.2", "5.3", "5.4", "5.5", "5.6"] },
    { "id": 5, "tasks": ["7.1", "7.2", "7.3", "7.4", "7.5", "7.6", "7.7"] },
    { "id": 6, "tasks": ["9.1", "9.2", "9.3"] },
    { "id": 7, "tasks": ["11.1"] },
    { "id": 8, "tasks": ["11.2", "11.3"] }
  ]
}
```
