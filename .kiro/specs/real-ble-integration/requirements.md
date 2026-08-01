# Requirements Document

## Introduction

Replace the `MockBLEService` (simulated BLE service with fake scanning, connecting, and command execution) with the real `BLEManager` (CoreBluetooth-based implementation) throughout the LCGRemote iOS app. This enables the app to discover and communicate with real LCG hardware devices — Interior units ("LiftGateIn-*") and Exterior units ("LiftGateEx-*") — over Bluetooth Low Energy. The integration introduces a protocol-based abstraction layer so views and view models depend on an interface rather than a concrete type, enabling testability and clean separation.

## Glossary

- **BLE_Service_Protocol**: A Swift protocol defining the public interface for BLE operations (scanning, connecting, disconnecting, command execution, status observation) that both the real `BLEManager` adapter and any future mock can conform to.
- **BLE_Adapter**: A concrete class conforming to `BLE_Service_Protocol` that wraps the existing `BLEManager` and translates its CoreBluetooth-based API into the interface expected by view models.
- **BLEManager**: The existing CoreBluetooth-based manager handling low-level BLE scanning, connection, characteristic discovery, reads, writes, and notifications.
- **Interior_Unit**: An LCG hardware device advertising the service UUID `19B10001-E8F2-537E-4F6C-D104768A1217`, with names matching the pattern "LiftGateIn-*".
- **Exterior_Unit**: An LCG hardware device advertising the service UUID `19B10001-E8F2-537E-4F6C-D104768A1214`, with names matching the pattern "LiftGateEx-*".
- **DeviceState**: An enum representing BLE notification status bytes: idle (0x00), busy (0x01), done (0x02), error (0x03).
- **Command_Payload**: The byte sequence written to a BLE characteristic to trigger a floor selection or elevator call on the hardware.
- **App_Entry_Point**: The `LCGRemoteApp` struct that creates and injects shared service instances as `@EnvironmentObject`.

## Requirements

### Requirement 1: BLE Service Protocol Abstraction

**User Story:** As a developer, I want all views and view models to depend on a protocol rather than a concrete BLE class, so that the real BLE implementation can be swapped in without modifying consumer code.

#### Acceptance Criteria

1. THE BLE_Service_Protocol SHALL declare published properties for `discoveredDevices`, `isScanning`, `connectedDevice`, `connectionState`, `deviceStatus`, and `statusMessage` matching the types currently exposed by MockBLEService.
2. THE BLE_Service_Protocol SHALL declare methods for `startScan()`, `stopScan()`, `connect(to:)`, `disconnect()`, `executeFloorCommand(profile:)`, `executeCallCommand()`, and `executePresetSequence(preset:onPhaseChange:completion:)`.
3. WHEN a view model is initialized, THE view model SHALL accept a dependency typed as `BLE_Service_Protocol` instead of a concrete class.
4. THE App_Entry_Point SHALL inject the BLE_Adapter instance as the `BLE_Service_Protocol` environment object.

### Requirement 2: BLE Adapter Implementation

**User Story:** As a developer, I want a concrete adapter that conforms to the BLE service protocol and delegates to the real BLEManager, so that the existing CoreBluetooth logic is reused without modification.

#### Acceptance Criteria

1. THE BLE_Adapter SHALL conform to `BLE_Service_Protocol` and `ObservableObject`.
2. WHEN `startScan()` is called, THE BLE_Adapter SHALL delegate to `BLEManager.startScan()` and publish discovered devices by mapping `DiscoveredDevice` instances to the protocol's device representation.
3. WHEN `stopScan()` is called, THE BLE_Adapter SHALL delegate to `BLEManager.stopScan()` and update `isScanning` to false.
4. WHEN `connect(to:)` is called with a device, THE BLE_Adapter SHALL invoke `BLEManager.connect(to:)` asynchronously and update `connectionState` to `.connecting` immediately and `.connected` upon success.
5. IF the connection attempt fails or times out, THEN THE BLE_Adapter SHALL set `connectionState` to `.disconnected` and populate `statusMessage` with a descriptive error.
6. WHEN `disconnect()` is called, THE BLE_Adapter SHALL invoke `BLEManager.disconnect(from:)` for the currently connected device and reset `connectedDevice`, `connectionState`, and `deviceStatus` to their default values.
7. WHEN `executeFloorCommand(profile:)` is called, THE BLE_Adapter SHALL encode the floor profile's X, Y, Z coordinates into a Command_Payload, write the payload to the connected Interior_Unit, and update `deviceStatus` based on BLE notification responses.
8. WHEN `executeCallCommand()` is called, THE BLE_Adapter SHALL write a call command payload to the connected Exterior_Unit and update `deviceStatus` based on BLE notification responses.
9. THE BLE_Adapter SHALL subscribe to `BLEManager.statusNotificationSubject` and map received notification bytes to `DeviceState` values, updating the published `deviceStatus` property accordingly.

### Requirement 3: Device Discovery and Filtering

**User Story:** As a user, I want the app to discover real LCG hardware devices over BLE, so that I can see and connect to nearby Interior and Exterior units.

#### Acceptance Criteria

1. WHEN scanning is active, THE BLE_Adapter SHALL filter discovered peripherals to only those advertising the Interior_Unit or Exterior_Unit service UUIDs.
2. THE BLE_Adapter SHALL classify each discovered device as `interior` or `exterior` based on its advertised service UUID.
3. WHEN a peripheral advertises a name matching "LiftGateIn-*", THE BLE_Adapter SHALL display the advertised name as the device label.
4. WHEN a peripheral advertises a name matching "LiftGateEx-*", THE BLE_Adapter SHALL display the advertised name as the device label.
5. THE BLE_Adapter SHALL update device RSSI values as duplicate advertisements are received during scanning.
6. WHEN scanning times out after 10 seconds, THE BLE_Adapter SHALL set `isScanning` to false automatically.

### Requirement 4: Connection Lifecycle Management

**User Story:** As a user, I want reliable connection management with automatic reconnection, so that I maintain communication with my LCG device even after brief signal drops.

#### Acceptance Criteria

1. WHEN a connection is established, THE BLE_Adapter SHALL discover services and characteristics before reporting `connectionState` as `.connected`.
2. WHEN an unexpected disconnection occurs, THE BLE_Adapter SHALL attempt automatic reconnection up to 3 times before reporting the device as disconnected.
3. WHEN the user initiates a disconnect, THE BLE_Adapter SHALL skip automatic reconnection and immediately transition `connectionState` to `.disconnected`.
4. THE BLE_Adapter SHALL support simultaneous connections to one Interior_Unit and one Exterior_Unit for preset execution workflows.
5. IF Bluetooth is powered off or unavailable, THEN THE BLE_Adapter SHALL set `connectionState` to `.disconnected` and populate `statusMessage` with "Bluetooth is not available".

### Requirement 5: Command Execution with Status Feedback

**User Story:** As a user, I want real-time status feedback when I press floor buttons or call the elevator, so that I know whether my command succeeded or failed.

#### Acceptance Criteria

1. WHEN a floor command is executed, THE BLE_Adapter SHALL transition `deviceStatus` to `.busy` immediately and update `statusMessage` to "Pressing button...".
2. WHEN a BLE notification with value 0x02 (done) is received after a command, THE BLE_Adapter SHALL transition `deviceStatus` to `.done` and update `statusMessage` to "Floor selected".
3. WHEN a BLE notification with value 0x03 (error) is received after a command, THE BLE_Adapter SHALL transition `deviceStatus` to `.error` and update `statusMessage` to "Command failed. Please retry.".
4. IF no BLE notification is received within 5 seconds of a command write, THEN THE BLE_Adapter SHALL transition `deviceStatus` to `.error` and update `statusMessage` to "Command timed out".
5. WHEN `deviceStatus` transitions to `.done`, THE BLE_Adapter SHALL automatically reset `deviceStatus` to `.idle` after 1 second.
6. WHEN `deviceStatus` transitions to `.error`, THE BLE_Adapter SHALL automatically reset `deviceStatus` to `.idle` after 2 seconds.

### Requirement 6: Preset Sequence Execution with Real Devices

**User Story:** As a user, I want preset sequences to connect to real Exterior and Interior units and execute multi-step workflows, so that I can call the elevator and select a floor in a single action.

#### Acceptance Criteria

1. WHEN `executePresetSequence` is called, THE BLE_Adapter SHALL connect to the Exterior_Unit, send a call command, connect to the Interior_Unit, and send a floor command in sequence.
2. THE BLE_Adapter SHALL report phase transitions (connectingExterior, callingElevator, connectingInterior, selectingFloor, done) via the `onPhaseChange` callback.
3. IF any step in the preset sequence fails, THEN THE BLE_Adapter SHALL invoke the completion handler with `false` and stop executing subsequent steps.
4. WHEN the preset sequence completes all steps successfully, THE BLE_Adapter SHALL invoke the completion handler with `true`.

### Requirement 7: Onboarding Flow with Real BLE

**User Story:** As a new user, I want the onboarding flow to discover and pair with my actual LCG device, so that I am ready to use the app immediately after setup.

#### Acceptance Criteria

1. WHEN the user grants Bluetooth permission during onboarding, THE App_Entry_Point SHALL trigger a real BLE scan for LCG devices.
2. WHEN a real LCG device is discovered during onboarding, THE OnboardingView SHALL display the device name and unit type for selection.
3. WHEN the user selects a device during onboarding, THE BLE_Adapter SHALL establish a real BLE connection to the selected peripheral.
4. IF no devices are found within 10 seconds during onboarding, THEN THE OnboardingView SHALL display a "No devices found" message with an option to retry.

### Requirement 8: Compile-Time Environment Toggle

**User Story:** As a developer, I want a single codebase that uses the real BLEManager on physical devices and MockBLEService on the simulator, so that I can test UI flows without hardware while still running real BLE on device.

#### Acceptance Criteria

1. WHEN the app is compiled for the iOS Simulator (`#if targetEnvironment(simulator)`), THE App_Entry_Point SHALL inject a `MockBLEService` instance conforming to `BLE_Service_Protocol`.
2. WHEN the app is compiled for a physical device, THE App_Entry_Point SHALL inject a `BLE_Adapter` instance wrapping the real `BLEManager`.
3. THE MockBLEService SHALL conform to `BLE_Service_Protocol` so that views and view models work identically on simulator and device.
4. THE App SHALL compile and run on both simulator and device without conditional compilation in views or view models — only the App_Entry_Point uses `#if targetEnvironment(simulator)`.
5. THE App SHALL remove direct type references to `MockBLEService` and `MockDevice` from all views and view models, replacing them with protocol-typed dependencies.

### Requirement 9: Bluetooth Permission Handling

**User Story:** As a user, I want clear feedback about Bluetooth permission state, so that I understand why scanning might not work and how to fix it.

#### Acceptance Criteria

1. WHEN the app launches for the first time, THE App_Entry_Point SHALL trigger the iOS Bluetooth permission prompt via `CBCentralManager` initialization.
2. IF the user denies Bluetooth permission, THEN THE BLE_Adapter SHALL set `statusMessage` to "Bluetooth permission denied. Enable in Settings." and set `isScanning` to false.
3. WHILE Bluetooth is in the `.unauthorized` state, THE BLE_Adapter SHALL prevent scan attempts and report the restriction through `statusMessage`.
4. THE App SHALL include the `NSBluetoothAlwaysUsageDescription` key in its Info.plist with a user-facing explanation of why Bluetooth access is needed.
