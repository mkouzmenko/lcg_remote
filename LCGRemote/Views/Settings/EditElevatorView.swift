import SwiftUI

/// Edit screen for a single elevator: name, interior device, floor buttons, exterior buttons.
struct EditElevatorView: View {
    @State private var elevator: ElevatorConfig
    let persistenceService: JSONPersistenceService
    let bleService: BLEService
    let onSave: (ElevatorConfig) -> Void
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    // MARK: - Sheet State

    @State private var showAddFloorButton = false
    @State private var showAddExteriorButton = false
    @State private var floorButtonToEdit: FloorButtonConfig? = nil
    @State private var exteriorButtonToEdit: ExteriorButtonConfig? = nil
    @State private var showDeleteElevatorAlert = false
    @State private var showDevicePicker = false
    @State private var devicePickerTarget: DevicePickerTarget = .interior

    enum DevicePickerTarget {
        case interior
        case exterior(ExteriorButtonConfig)
    }

    init(elevator: ElevatorConfig, persistenceService: JSONPersistenceService, bleService: BLEService, onSave: @escaping (ElevatorConfig) -> Void, onDelete: @escaping () -> Void) {
        _elevator = State(initialValue: elevator)
        self.persistenceService = persistenceService
        self.bleService = bleService
        self.onSave = onSave
        self.onDelete = onDelete
    }

    var body: some View {
        Form {
            nameSection
            interiorDeviceSection
            floorButtonsSection
            exteriorButtonsSection
            deleteSection
        }
        .navigationTitle("Edit Elevator")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    onSave(elevator)
                    dismiss()
                }
                .accessibilityHint("Double-tap to save changes")
            }
        }
        .sheet(isPresented: $showAddFloorButton) {
            NavigationStack {
                FloorButtonFormView(mode: .add) { newButton in
                    var btn = newButton
                    btn.sortOrder = elevator.floorButtons.count
                    elevator.floorButtons.append(btn)
                }
            }
        }
        .sheet(item: $floorButtonToEdit) { button in
            NavigationStack {
                FloorButtonFormView(mode: .edit(button)) { updated in
                    if let index = elevator.floorButtons.firstIndex(where: { $0.id == updated.id }) {
                        elevator.floorButtons[index] = updated
                    }
                }
            }
        }
        .sheet(isPresented: $showAddExteriorButton) {
            NavigationStack {
                ExteriorButtonFormView(mode: .add, bleService: bleService) { newButton in
                    var btn = newButton
                    btn.sortOrder = elevator.exteriorButtons.count
                    elevator.exteriorButtons.append(btn)
                }
            }
        }
        .sheet(item: $exteriorButtonToEdit) { button in
            NavigationStack {
                ExteriorButtonFormView(mode: .edit(button), bleService: bleService) { updated in
                    if let index = elevator.exteriorButtons.firstIndex(where: { $0.id == updated.id }) {
                        elevator.exteriorButtons[index] = updated
                    }
                }
            }
        }
        .sheet(isPresented: $showDevicePicker) {
            NavigationStack {
                DevicePickerView(bleService: bleService) { device in
                    switch devicePickerTarget {
                    case .interior:
                        elevator.interiorDeviceID = device.id
                        elevator.interiorDeviceName = device.name
                    case .exterior(let extButton):
                        if let index = elevator.exteriorButtons.firstIndex(where: { $0.id == extButton.id }) {
                            elevator.exteriorButtons[index].deviceID = device.id
                            elevator.exteriorButtons[index].deviceName = device.name
                        }
                    }
                    showDevicePicker = false
                }
            }
        }
        .alert("Delete Elevator", isPresented: $showDeleteElevatorAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete()
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \"\(elevator.name)\"? This cannot be undone.")
        }
    }

    // MARK: - Name Section

    private var nameSection: some View {
        Section {
            TextField("Elevator Name", text: $elevator.name)
                .accessibilityLabel("Elevator name")
        } header: {
            Text("Name")
        }
    }

    // MARK: - Interior Device Section

    private var interiorDeviceSection: some View {
        Section {
            Button {
                devicePickerTarget = .interior
                showDevicePicker = true
            } label: {
                HStack {
                    Label("Interior Device", systemImage: "arrow.up.arrow.down")
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(elevator.interiorDeviceName ?? "Not Set")
                        .foregroundStyle(.secondary)
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Interior device: \(elevator.interiorDeviceName ?? "Not set")")
            .accessibilityHint("Double-tap to select a BLE device")

            if elevator.interiorDeviceID != nil {
                Button(role: .destructive) {
                    elevator.interiorDeviceID = nil
                    elevator.interiorDeviceName = nil
                } label: {
                    Label("Remove Interior Device", systemImage: "xmark.circle")
                }
            }
        } header: {
            Text("Interior Device")
        } footer: {
            Text("All floor buttons share this interior device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Floor Buttons Section

    private var floorButtonsSection: some View {
        Section {
            ForEach(elevator.floorButtons.sorted(by: { $0.sortOrder < $1.sortOrder })) { button in
                Button {
                    floorButtonToEdit = button
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(button.label)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text("X: \(button.x)  Y: \(button.y)  Z: \(button.z)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(button.label), X \(button.x), Y \(button.y), Z \(button.z)")
                .accessibilityHint("Double-tap to edit")
            }
            .onDelete { indexSet in
                let sorted = elevator.floorButtons.sorted(by: { $0.sortOrder < $1.sortOrder })
                for index in indexSet {
                    let button = sorted[index]
                    elevator.floorButtons.removeAll { $0.id == button.id }
                }
                reindexFloorButtons()
            }
            .onMove { source, destination in
                var sorted = elevator.floorButtons.sorted(by: { $0.sortOrder < $1.sortOrder })
                sorted.move(fromOffsets: source, toOffset: destination)
                for (i, btn) in sorted.enumerated() {
                    if let idx = elevator.floorButtons.firstIndex(where: { $0.id == btn.id }) {
                        elevator.floorButtons[idx].sortOrder = i
                    }
                }
            }

            Button {
                showAddFloorButton = true
            } label: {
                Label("Add Floor Button", systemImage: "plus")
            }
            .accessibilityHint("Double-tap to add a new floor button")
        } header: {
            HStack {
                Text("Floor Buttons")
                Spacer()
                EditButton()
                    .font(.caption)
            }
        }
    }

    // MARK: - Exterior Buttons Section

    private var exteriorButtonsSection: some View {
        Section {
            ForEach(elevator.exteriorButtons.sorted(by: { $0.sortOrder < $1.sortOrder })) { button in
                Button {
                    exteriorButtonToEdit = button
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(button.label)
                                .font(.body)
                                .foregroundStyle(.primary)
                            HStack(spacing: 8) {
                                Text("X: \(button.x)  Y: \(button.y)  Z: \(button.z)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let deviceName = button.deviceName {
                                    Text("• \(deviceName)")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(button.label), X \(button.x), Y \(button.y), Z \(button.z), device: \(button.deviceName ?? "not set")")
                .accessibilityHint("Double-tap to edit")
            }
            .onDelete { indexSet in
                let sorted = elevator.exteriorButtons.sorted(by: { $0.sortOrder < $1.sortOrder })
                for index in indexSet {
                    let button = sorted[index]
                    elevator.exteriorButtons.removeAll { $0.id == button.id }
                }
                reindexExteriorButtons()
            }

            Button {
                showAddExteriorButton = true
            } label: {
                Label("Add Exterior Button", systemImage: "plus")
            }
            .accessibilityHint("Double-tap to add a new exterior call button")
        } header: {
            Text("Exterior Buttons")
        }
    }

    // MARK: - Delete Section

    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteElevatorAlert = true
            } label: {
                Label("Delete Elevator", systemImage: "trash")
            }
            .accessibilityHint("Double-tap to delete this elevator")
        }
    }

    // MARK: - Helpers

    private func reindexFloorButtons() {
        let sorted = elevator.floorButtons.sorted(by: { $0.sortOrder < $1.sortOrder })
        for (i, btn) in sorted.enumerated() {
            if let idx = elevator.floorButtons.firstIndex(where: { $0.id == btn.id }) {
                elevator.floorButtons[idx].sortOrder = i
            }
        }
    }

    private func reindexExteriorButtons() {
        let sorted = elevator.exteriorButtons.sorted(by: { $0.sortOrder < $1.sortOrder })
        for (i, btn) in sorted.enumerated() {
            if let idx = elevator.exteriorButtons.firstIndex(where: { $0.id == btn.id }) {
                elevator.exteriorButtons[idx].sortOrder = i
            }
        }
    }
}

// MARK: - Floor Button Form

struct FloorButtonFormView: View {
    let mode: FormMode
    let onSave: (FloorButtonConfig) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var xValue: String = ""
    @State private var yValue: String = ""
    @State private var zValue: String = ""
    @State private var validationError: String? = nil

    enum FormMode: Identifiable {
        case add
        case edit(FloorButtonConfig)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let btn): return btn.id.uuidString
            }
        }
    }

    private var title: String {
        switch mode {
        case .add: return "Add Floor Button"
        case .edit: return "Edit Floor Button"
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Label (e.g., Lobby, 1, 2)", text: $label)
                    .accessibilityLabel("Button label")
            } header: {
                Text("Label")
            }

            Section {
                TextField("X (0–250)", text: $xValue)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .accessibilityLabel("X coordinate")
                TextField("Y (0–250)", text: $yValue)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .accessibilityLabel("Y coordinate")
                TextField("Z (0–250)", text: $zValue)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .accessibilityLabel("Z coordinate")
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
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .onAppear {
            if case .edit(let btn) = mode {
                label = btn.label
                xValue = String(btn.x)
                yValue = String(btn.y)
                zValue = String(btn.z)
            }
        }
    }

    private func save() {
        let x = Int(xValue) ?? -1
        let y = Int(yValue) ?? -1
        let z = Int(zValue) ?? -1

        guard x >= 0, x <= 250 else { validationError = "X must be 0–250"; return }
        guard y >= 0, y <= 250 else { validationError = "Y must be 0–250"; return }
        guard z >= 0, z <= 250 else { validationError = "Z must be 0–250"; return }

        switch mode {
        case .add:
            let btn = FloorButtonConfig(id: UUID(), label: label, x: x, y: y, z: z, sortOrder: 0)
            onSave(btn)
        case .edit(let existing):
            let btn = FloorButtonConfig(id: existing.id, label: label, x: x, y: y, z: z, sortOrder: existing.sortOrder)
            onSave(btn)
        }
        dismiss()
    }
}

// MARK: - Exterior Button Form

struct ExteriorButtonFormView: View {
    let mode: FormMode
    let bleService: BLEService
    let onSave: (ExteriorButtonConfig) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var xValue: String = ""
    @State private var yValue: String = ""
    @State private var zValue: String = ""
    @State private var selectedDeviceID: String? = nil
    @State private var selectedDeviceName: String? = nil
    @State private var showDevicePicker = false
    @State private var validationError: String? = nil

    enum FormMode: Identifiable {
        case add
        case edit(ExteriorButtonConfig)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let btn): return btn.id.uuidString
            }
        }
    }

    private var title: String {
        switch mode {
        case .add: return "Add Exterior Button"
        case .edit: return "Edit Exterior Button"
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Label (e.g., Call F1)", text: $label)
                    .accessibilityLabel("Button label")
            } header: {
                Text("Label")
            }

            Section {
                Button {
                    showDevicePicker = true
                } label: {
                    HStack {
                        Text("BLE Device")
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(selectedDeviceName ?? "Not Set")
                            .foregroundStyle(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(.plain)

                if selectedDeviceID != nil {
                    Button(role: .destructive) {
                        selectedDeviceID = nil
                        selectedDeviceName = nil
                    } label: {
                        Label("Remove Device", systemImage: "xmark.circle")
                    }
                }
            } header: {
                Text("Device")
            }

            Section {
                TextField("X (0–250)", text: $xValue)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .accessibilityLabel("X coordinate")
                TextField("Y (0–250)", text: $yValue)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .accessibilityLabel("Y coordinate")
                TextField("Z (0–250)", text: $zValue)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .accessibilityLabel("Z coordinate")
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
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $showDevicePicker) {
            NavigationStack {
                DevicePickerView(bleService: bleService) { device in
                    selectedDeviceID = device.id
                    selectedDeviceName = device.name
                    showDevicePicker = false
                }
            }
        }
        .onAppear {
            if case .edit(let btn) = mode {
                label = btn.label
                xValue = String(btn.x)
                yValue = String(btn.y)
                zValue = String(btn.z)
                selectedDeviceID = btn.deviceID
                selectedDeviceName = btn.deviceName
            }
        }
    }

    private func save() {
        let x = Int(xValue) ?? -1
        let y = Int(yValue) ?? -1
        let z = Int(zValue) ?? -1

        guard x >= 0, x <= 250 else { validationError = "X must be 0–250"; return }
        guard y >= 0, y <= 250 else { validationError = "Y must be 0–250"; return }
        guard z >= 0, z <= 250 else { validationError = "Z must be 0–250"; return }

        switch mode {
        case .add:
            let btn = ExteriorButtonConfig(id: UUID(), label: label, deviceID: selectedDeviceID, deviceName: selectedDeviceName, x: x, y: y, z: z, sortOrder: 0)
            onSave(btn)
        case .edit(let existing):
            let btn = ExteriorButtonConfig(id: existing.id, label: label, deviceID: selectedDeviceID, deviceName: selectedDeviceName, x: x, y: y, z: z, sortOrder: existing.sortOrder)
            onSave(btn)
        }
        dismiss()
    }
}

// MARK: - Device Picker View

struct DevicePickerView: View {
    @ObservedObject var bleService: BLEService
    let onSelect: (BLEDevice) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if bleService.isScanning {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("Scanning...")
                        .foregroundStyle(.secondary)
                }
            }

            if bleService.discoveredDevices.isEmpty && !bleService.isScanning {
                Text("No devices found. Tap Scan to search.")
                    .foregroundStyle(.secondary)
            }

            ForEach(bleService.discoveredDevices) { device in
                Button {
                    onSelect(device)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(device.name)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(device.unitType == .interior ? "Interior" : "Exterior")
                                .font(.caption)
                                .foregroundStyle(device.unitType == .interior ? .blue : .orange)
                        }
                        Spacer()
                        Text("RSSI: \(device.rssi)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(device.name), \(device.unitType == .interior ? "Interior" : "Exterior")")
                .accessibilityHint("Double-tap to select this device")
            }
        }
        .navigationTitle("Select Device")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    bleService.startScan()
                } label: {
                    Label("Scan", systemImage: "antenna.radiowaves.left.and.right")
                }
                .disabled(bleService.isScanning)
            }
        }
        .onAppear {
            bleService.startScan()
        }
    }
}
