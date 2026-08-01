import SwiftUI

/// Displays and manages button configurations: list, add, edit, delete, reorder, and test.
/// Accessible from Settings or the gear icon on the Control tab.
struct ButtonConfigurationView: View {
    @StateObject private var viewModel: ButtonConfigViewModel<BLEService>
    @State private var showingAddForm = false
    @State private var configToEdit: ButtonConfig? = nil
    @State private var configToDelete: ButtonConfig? = nil
    @State private var showDeleteConfirmation = false

    init(bleService: BLEService, persistenceService: JSONPersistenceService) {
        _viewModel = StateObject(wrappedValue: ButtonConfigViewModel(
            bleService: bleService,
            persistenceService: persistenceService
        ))
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.configs) { config in
                    ButtonConfigRow(
                        config: config,
                        onTest: { viewModel.testConfig(config) },
                        onTap: { configToEdit = config }
                    )
                }
                .onDelete { indexSet in
                    if let index = indexSet.first {
                        configToDelete = viewModel.configs[index]
                        showDeleteConfirmation = true
                    }
                }
                .onMove { source, destination in
                    viewModel.reorderConfigs(from: source, to: destination)
                }
            } header: {
                Text("Buttons")
                    .accessibilityAddTraits(.isHeader)
            } footer: {
                Text("Each button connects to its configured device and sends X/Y/Z coordinates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Button Configuration")
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
                    .accessibilityHint("Double-tap to enable reorder and delete mode")
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddForm = true
                } label: {
                    Label("Add Button", systemImage: "plus")
                }
                .accessibilityHint("Double-tap to add a new button")
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button {
                    showingAddForm = true
                } label: {
                    Label("Add Button", systemImage: "plus")
                }
                .accessibilityHint("Double-tap to add a new button")
            }
            #endif
        }
        .sheet(isPresented: $showingAddForm) {
            NavigationStack {
                ButtonConfigFormView(viewModel: viewModel, mode: .add)
            }
        }
        .sheet(item: $configToEdit) { config in
            NavigationStack {
                ButtonConfigFormView(viewModel: viewModel, mode: .edit(config))
            }
        }
        .alert("Delete Button", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let config = configToDelete {
                    viewModel.deleteConfig(config)
                }
                configToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                configToDelete = nil
            }
        } message: {
            if let config = configToDelete {
                Text("Are you sure you want to delete \"\(config.label)\"? This action cannot be undone.")
            }
        }
    }
}

// MARK: - Button Config Row

private struct ButtonConfigRow: View {
    let config: ButtonConfig
    let onTest: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(config.label)
                            .font(.headline)
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(config.deviceType == .exterior ? "Exterior" : "Interior")
                            .font(.caption)
                            .foregroundColor(config.deviceType == .exterior ? .orange : .blue)
                    }
                    Text("X: \(config.x)  Y: \(config.y)  Z: \(config.z)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(config.label), \(config.deviceType == .exterior ? "Exterior" : "Interior"), X \(config.x), Y \(config.y), Z \(config.z)")

                Spacer()

                Button {
                    onTest()
                } label: {
                    Text("Test")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Test \(config.label)")
                .accessibilityHint("Double-tap to send a test command")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Double-tap to edit this button")
    }
}

// MARK: - Button Config Form View

private struct ButtonConfigFormView: View {
    @ObservedObject var viewModel: ButtonConfigViewModel<BLEService>
    let mode: FormMode
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var deviceType: UnitType = .interior
    @State private var xValue: String = ""
    @State private var yValue: String = ""
    @State private var zValue: String = ""
    @State private var validationError: String? = nil

    enum FormMode: Identifiable {
        case add
        case edit(ButtonConfig)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let config): return config.id.uuidString
            }
        }
    }

    private var title: String {
        switch mode {
        case .add: return "Add Button"
        case .edit: return "Edit Button"
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Button Label", text: $label)
                    .accessibilityLabel("Button label")
                    .accessibilityHint("Enter a name like Call Elevator, Lobby, or 1")
            } header: {
                Text("Label")
            }

            Section {
                Picker("Device Type", selection: $deviceType) {
                    Text("Interior").tag(UnitType.interior)
                    Text("Exterior").tag(UnitType.exterior)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Device type")
            } header: {
                Text("Device Type")
            } footer: {
                Text("Determines which device group this button uses. Configure devices in Settings → Device Groups.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("X (0–250)", text: $xValue)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityLabel("X coordinate")
                        .accessibilityHint("Enter a value between 0 and 250")
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Y (0–250)", text: $yValue)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityLabel("Y coordinate")
                        .accessibilityHint("Enter a value between 0 and 250")
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Z (0–250)", text: $zValue)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityLabel("Z coordinate")
                        .accessibilityHint("Enter a value between 0 and 250")
                }
            } header: {
                Text("Coordinates")
            }

            if let error = validationError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveConfig()
                }
                .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityHint("Double-tap to save this button configuration")
            }
        }
        .onAppear {
            if case .edit(let config) = mode {
                label = config.label
                deviceType = config.deviceType
                xValue = String(config.x)
                yValue = String(config.y)
                zValue = String(config.z)
            }
        }
    }

    private func saveConfig() {
        let x = Int(xValue) ?? -1
        let y = Int(yValue) ?? -1
        let z = Int(zValue) ?? -1

        guard x >= 0, x <= 250 else { validationError = "X must be 0–250"; return }
        guard y >= 0, y <= 250 else { validationError = "Y must be 0–250"; return }
        guard z >= 0, z <= 250 else { validationError = "Z must be 0–250"; return }

        switch mode {
        case .add:
            viewModel.addConfig(label: label, deviceType: deviceType, x: x, y: y, z: z)
        case .edit(let config):
            viewModel.updateConfig(config, label: label, deviceType: deviceType, x: x, y: y, z: z)
        }
        dismiss()
    }
}
