import SwiftUI

/// Settings View with device pairing, calibration, diagnostics, about info, and reset options.
struct SettingsView: View {
    @EnvironmentObject var persistenceService: JSONPersistenceService
    @EnvironmentObject var bleService: BLEService

    @StateObject private var viewModel: SettingsViewModel<BLEService>

    // MARK: - Alert State

    @State private var showResetOnboardingAlert = false
    @State private var showResetAllDataAlert = false
    @State private var deviceToForget: BLEDevice?
    @State private var editingDeviceID: String?
    @State private var editedName: String = ""

    // MARK: - Device Groups State

    @State private var deviceGroupConfig = DeviceGroupConfig()
    @State private var selectedInteriorDeviceID: String? = nil
    @State private var selectedExteriorDeviceID: String? = nil

    // MARK: - Init

    init(persistenceService: JSONPersistenceService, bleService: BLEService) {
        _viewModel = StateObject(wrappedValue: SettingsViewModel(
            persistenceService: persistenceService,
            bleService: bleService
        ))
    }

    // MARK: - Body

    var body: some View {
        Form {
            deviceGroupsSection
            calibrationSection
            devicesSection
            diagnosticsSection
            aboutSection
            resetSection
        }
        .navigationTitle("Settings")
        .onAppear {
            bleService.startScan()
        }
        .alert("Forget Device", isPresented: Binding<Bool>(
            get: { deviceToForget != nil },
            set: { if !$0 { deviceToForget = nil } }
        )) {
            Button("Cancel", role: .cancel) {
                deviceToForget = nil
            }
            Button("Forget", role: .destructive) {
                if let device = deviceToForget {
                    viewModel.forgetDevice(device)
                }
                deviceToForget = nil
            }
        } message: {
            if let device = deviceToForget {
                Text("Are you sure you want to forget \"\(device.name)\"? This device will need to be re-paired.")
            }
        }
        .alert("Reset Onboarding", isPresented: $showResetOnboardingAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                viewModel.resetOnboarding()
            }
        } message: {
            Text("This will show the onboarding flow on next launch.")
        }
        .alert("Reset All Data", isPresented: $showResetAllDataAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Reset All", role: .destructive) {
                viewModel.resetAllData()
            }
        } message: {
            Text("This will erase all saved data including device names, presets, and calibration. This cannot be undone.")
        }
    }

    // MARK: - Device Groups Section

    private var deviceGroupsSection: some View {
        Section {
            // Interior Device Row
            HStack {
                Label("Interior", systemImage: "arrow.up.arrow.down")
                    .foregroundStyle(.blue)
                Spacer()
                Picker("", selection: $selectedInteriorDeviceID) {
                    Text("Not Set").tag(String?.none)
                    ForEach(interiorDevices) { device in
                        Text(device.name).tag(Optional(device.id))
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedInteriorDeviceID) { newValue in
                    saveDeviceGroupSelection(interiorID: newValue, exteriorID: selectedExteriorDeviceID)
                }
            }
            .accessibilityLabel("Interior device group")

            // Exterior Device Row
            HStack {
                Label("Exterior", systemImage: "bell.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Picker("", selection: $selectedExteriorDeviceID) {
                    Text("Not Set").tag(String?.none)
                    ForEach(exteriorDevices) { device in
                        Text(device.name).tag(Optional(device.id))
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedExteriorDeviceID) { newValue in
                    saveDeviceGroupSelection(interiorID: selectedInteriorDeviceID, exteriorID: newValue)
                }
            }
            .accessibilityLabel("Exterior device group")

            // Scan button
            Button {
                bleService.startScan()
            } label: {
                HStack {
                    Label("Scan for Devices", systemImage: "antenna.radiowaves.left.and.right")
                    Spacer()
                    if bleService.isScanning {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(bleService.isScanning)
        } header: {
            Text("Device Groups")
        } footer: {
            Text("Tap Interior/Exterior to associate with a BLE device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onAppear {
            loadDeviceGroupConfig()
            bleService.startScan()
        }
    }

    /// Interior devices from the discovered list (names containing "LiftGateIn" or unitType .interior).
    private var interiorDevices: [BLEDevice] {
        bleService.discoveredDevices.filter { $0.unitType == .interior }
    }

    /// Exterior devices from the discovered list (names containing "LiftGateEx" or unitType .exterior).
    private var exteriorDevices: [BLEDevice] {
        bleService.discoveredDevices.filter { $0.unitType == .exterior }
    }

    private func loadDeviceGroupConfig() {
        let config = persistenceService.loadDeviceGroups()
        deviceGroupConfig = config
        selectedInteriorDeviceID = config.interiorDeviceID
        selectedExteriorDeviceID = config.exteriorDeviceID
    }

    private func saveDeviceGroupSelection(interiorID: String?, exteriorID: String?) {
        let interiorName = bleService.discoveredDevices.first(where: { $0.id == interiorID })?.name
        let exteriorName = bleService.discoveredDevices.first(where: { $0.id == exteriorID })?.name

        let config = DeviceGroupConfig(
            interiorDeviceID: interiorID,
            interiorDeviceName: interiorName ?? deviceGroupConfig.interiorDeviceName,
            exteriorDeviceID: exteriorID,
            exteriorDeviceName: exteriorName ?? deviceGroupConfig.exteriorDeviceName
        )
        deviceGroupConfig = config
        try? persistenceService.saveDeviceGroups(config)
    }

    // MARK: - Calibration Section

    private var calibrationSection: some View {
        Section {
            NavigationLink {
                ButtonConfigurationView(
                    bleService: bleService,
                    persistenceService: persistenceService
                )
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundColor(.accentColor)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Button Configuration")
                            .font(.body)
                        Text("Edit buttons, device targets, and X/Y/Z positions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityLabel("Button Configuration")
            .accessibilityHint("Double-tap to configure button positions and device assignments")
        } header: {
            Text("Configuration")
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Devices Section

    private var devicesSection: some View {
        Section {
            if viewModel.devices.isEmpty {
                Text("No devices found")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("No devices found")
            } else {
                ForEach(viewModel.devices) { device in
                    deviceRow(for: device)
                }
            }
        } header: {
            Text("Devices")
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func deviceRow(for device: BLEDevice) -> some View {
        HStack(spacing: 12) {
            Image(systemName: device.unitType == .interior
                  ? "arrow.up.arrow.down" : "bell.fill")
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                if editingDeviceID == device.id {
                    TextField("Device name", text: $editedName, onCommit: {
                        commitRename(device: device)
                    })
                    .textFieldStyle(.plain)
                    .font(.body)
                    .accessibilityLabel("Edit device name")
                    .accessibilityHint("Enter a new name for this device, then press return to save")
                } else {
                    Text(device.name)
                        .font(.body)
                }

                Text(viewModel.connectionStatus(for: device))
                    .font(.caption)
                    .foregroundColor(statusColor(for: device))
            }

            Spacer()

            Circle()
                .fill(statusColor(for: device))
                .frame(width: 10, height: 10)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(deviceAccessibilityLabel(for: device))
        .accessibilityHint("Swipe actions available: Rename, Forget device")
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deviceToForget = device
            } label: {
                Label("Forget", systemImage: "trash")
            }
            .accessibilityLabel("Forget device \(device.name)")

            Button {
                editingDeviceID = device.id
                editedName = device.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }
            .tint(.blue)
            .accessibilityLabel("Rename device \(device.name)")
        }
        .contextMenu {
            Button {
                editingDeviceID = device.id
                editedName = device.name
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button(role: .destructive) {
                deviceToForget = device
            } label: {
                Label("Forget Device", systemImage: "trash")
            }
        }
    }

    // MARK: - Diagnostics Section

    private var diagnosticsSection: some View {
        Section {
            if viewModel.diagnosticsLog.isEmpty {
                Text("No diagnostics entries")
                    .foregroundColor(.secondary)
                    .accessibilityLabel("No diagnostics entries")
            } else {
                ForEach(viewModel.diagnosticsLog) { entry in
                    diagnosticsRow(for: entry)
                }
            }
        } header: {
            Text("Diagnostics")
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func diagnosticsRow(for entry: DiagnosticsEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.deviceName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("•")
                        .foregroundColor(.secondary)
                        .accessibilityHidden(true)
                    Text(entry.commandType)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Text(formattedTimestamp(entry.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            outcomeIcon(for: entry.outcome)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.deviceName), \(entry.commandType), \(outcomeLabel(entry.outcome)), \(formattedTimestamp(entry.timestamp))")
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Version 1.0.0")

            HStack {
                Text("Build")
                Spacer()
                Text("1")
                    .foregroundColor(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Build 1")
        } header: {
            Text("About")
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Reset Section

    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                showResetOnboardingAlert = true
            } label: {
                Label("Reset Onboarding", systemImage: "arrow.counterclockwise")
            }
            .accessibilityLabel("Reset Onboarding")
            .accessibilityHint("Double-tap to show the onboarding flow on next launch")

            Button(role: .destructive) {
                showResetAllDataAlert = true
            } label: {
                Label("Reset All Data", systemImage: "trash.circle")
            }
            .accessibilityLabel("Reset All Data")
            .accessibilityHint("Double-tap to erase all saved data and restore defaults")
        } header: {
            Text("Reset")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Resetting data cannot be undone.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func statusColor(for device: BLEDevice) -> Color {
        if viewModel.isConnected(device) {
            return .green
        } else if device.isReachable {
            return .orange
        } else {
            return .gray
        }
    }

    @ViewBuilder
    private func outcomeIcon(for outcome: Outcome) -> some View {
        switch outcome {
        case .success:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .accessibilityLabel("Success")
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .accessibilityLabel("Error")
        case .timeout:
            Image(systemName: "clock.badge.exclamationmark")
                .foregroundColor(.orange)
                .accessibilityLabel("Timeout")
        }
    }

    private func outcomeLabel(_ outcome: Outcome) -> String {
        switch outcome {
        case .success: return "Success"
        case .error: return "Error"
        case .timeout: return "Timeout"
        }
    }

    private func formattedTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func deviceAccessibilityLabel(for device: BLEDevice) -> String {
        let unitTypeLabel = device.unitType == .interior ? "Interior unit" : "Exterior unit"
        return "\(device.name), \(unitTypeLabel), \(viewModel.connectionStatus(for: device))"
    }

    private func commitRename(device: BLEDevice) {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            viewModel.renameDevice(device, to: trimmed)
        }
        editingDeviceID = nil
        editedName = ""
    }
}
