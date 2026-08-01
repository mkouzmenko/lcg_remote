import SwiftUI

/// Displays and manages calibration settings:
/// - Exterior device ID and call button position
/// - Interior device ID and floor profiles (add, edit, delete, reorder, test)
struct CalibrationView: View {
    @StateObject private var viewModel: CalibrationViewModel<BLEService>
    @EnvironmentObject var bleService: BLEService
    @State private var showingAddForm = false
    @State private var showingCallButtonForm = false
    @State private var profileToEdit: FloorProfile? = nil
    @State private var profileToDelete: FloorProfile? = nil
    @State private var showDeleteConfirmation = false

    // Device ID state
    @State private var exteriorDeviceID: String = ""
    @State private var interiorDeviceID: String = ""

    private static var exteriorDeviceKey: String { "pairedExteriorDeviceID" }
    private static var interiorDeviceKey: String { "pairedInteriorDeviceID" }

    init(bleService: BLEService, persistenceService: JSONPersistenceService) {
        _viewModel = StateObject(wrappedValue: CalibrationViewModel(
            bleService: bleService,
            persistenceService: persistenceService
        ))
    }

    var body: some View {
        List {
            exteriorDeviceSection
            callButtonSection
            interiorDeviceSection
            floorProfilesSection
        }
        .navigationTitle("Calibration")
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
                    Label("Add Floor", systemImage: "plus")
                }
                .accessibilityHint("Double-tap to add a new floor profile")
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button {
                    showingAddForm = true
                } label: {
                    Label("Add Floor", systemImage: "plus")
                }
                .accessibilityHint("Double-tap to add a new floor profile")
            }
            #endif
        }
        .sheet(isPresented: $showingAddForm) {
            NavigationStack {
                CalibrationFormView(viewModel: viewModel, mode: .add)
            }
        }
        .sheet(item: $profileToEdit) { profile in
            NavigationStack {
                CalibrationFormView(viewModel: viewModel, mode: .edit(profile))
            }
        }
        .alert("Delete Floor Profile", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    viewModel.deleteProfile(profile)
                }
                profileToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                profileToDelete = nil
            }
        } message: {
            if let profile = profileToDelete {
                Text("Are you sure you want to delete \"\(profile.label)\"? This action cannot be undone.")
            }
        }
        .sheet(isPresented: $showingCallButtonForm) {
            NavigationStack {
                CallButtonCalibrationForm(bleService: bleService)
            }
        }
        .onAppear {
            exteriorDeviceID = UserDefaults.standard.string(forKey: Self.exteriorDeviceKey) ?? ""
            interiorDeviceID = UserDefaults.standard.string(forKey: Self.interiorDeviceKey) ?? ""
        }
    }

    // MARK: - Exterior Device Section

    private var exteriorDeviceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Exterior Device ID", text: $exteriorDeviceID)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .accessibilityLabel("Exterior device identifier")
                    .accessibilityHint("Enter the UUID of the exterior BLE device")
                    .onChange(of: exteriorDeviceID) { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            UserDefaults.standard.removeObject(forKey: Self.exteriorDeviceKey)
                        } else {
                            UserDefaults.standard.set(trimmed, forKey: Self.exteriorDeviceKey)
                        }
                    }

                // Show discovered exterior devices as quick-pick options
                let exteriorDevices = bleService.discoveredDevices.filter { $0.unitType == .exterior }
                if !exteriorDevices.isEmpty {
                    Text("Discovered devices:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(exteriorDevices) { device in
                        Button {
                            exteriorDeviceID = device.id
                            UserDefaults.standard.set(device.id, forKey: Self.exteriorDeviceKey)
                        } label: {
                            HStack {
                                Text(device.name)
                                    .font(.caption)
                                Spacer()
                                Text(device.id.prefix(8) + "...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Select \(device.name)")
                    }
                }
            }
        } header: {
            Text("Exterior Device")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("The BLE device used for calling the elevator. Find the ID in the Scan tab.")
        }
    }

    // MARK: - Call Button Section

    private var callButtonSection: some View {
        Section {
            Button {
                showingCallButtonForm = true
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Call Elevator")
                            .font(.headline)
                        if let profile = bleService.callButtonProfile {
                            Text("X: \(profile.x)  Y: \(profile.y)  Z: \(profile.z)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Not calibrated")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Call Elevator calibration")
            .accessibilityHint("Double-tap to set position coordinates")
        } header: {
            Text("Call Button Position")
                .accessibilityAddTraits(.isHeader)
        }
    }

    // MARK: - Interior Device Section

    private var interiorDeviceSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Interior Device ID", text: $interiorDeviceID)
                    .font(.system(.body, design: .monospaced))
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .accessibilityLabel("Interior device identifier")
                    .accessibilityHint("Enter the UUID of the interior BLE device")
                    .onChange(of: interiorDeviceID) { newValue in
                        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        if trimmed.isEmpty {
                            UserDefaults.standard.removeObject(forKey: Self.interiorDeviceKey)
                        } else {
                            UserDefaults.standard.set(trimmed, forKey: Self.interiorDeviceKey)
                        }
                    }

                // Show discovered interior devices as quick-pick options
                let interiorDevices = bleService.discoveredDevices.filter { $0.unitType == .interior }
                if !interiorDevices.isEmpty {
                    Text("Discovered devices:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(interiorDevices) { device in
                        Button {
                            interiorDeviceID = device.id
                            UserDefaults.standard.set(device.id, forKey: Self.interiorDeviceKey)
                        } label: {
                            HStack {
                                Text(device.name)
                                    .font(.caption)
                                Spacer()
                                Text(device.id.prefix(8) + "...")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityLabel("Select \(device.name)")
                    }
                }
            }
        } header: {
            Text("Interior Device")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("The BLE device inside the elevator for selecting floors. Find the ID in the Scan tab.")
        }
    }

    // MARK: - Floor Profiles Section

    private var floorProfilesSection: some View {
        Section {
            ForEach(viewModel.profiles) { profile in
                CalibrationRowView(
                    profile: profile,
                    onTest: { viewModel.testProfile(profile) },
                    onTap: { profileToEdit = profile }
                )
            }
            .onDelete { indexSet in
                if let index = indexSet.first {
                    profileToDelete = viewModel.profiles[index]
                    showDeleteConfirmation = true
                }
            }
            .onMove { source, destination in
                viewModel.reorderProfiles(from: source, to: destination)
            }
        } header: {
            Text("Floor Profiles")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Each floor button sends its X, Y, Z coordinates to the interior device.")
        }
    }
}

// MARK: - CalibrationRowView

/// A single row in the floor profile list showing label, X/Y/Z values, and a test button.
private struct CalibrationRowView: View {
    let profile: FloorProfile
    let onTest: () -> Void
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profile.label)
                        .font(.headline)
                    Text("X: \(profile.x)  Y: \(profile.y)  Z: \(profile.z)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(profile.label), X \(profile.x), Y \(profile.y), Z \(profile.z)")

                Spacer()

                Button {
                    onTest()
                } label: {
                    Text("Test")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Test \(profile.label)")
                .accessibilityHint("Double-tap to send a test command for this floor")
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Double-tap to edit this floor profile")
    }
}

// MARK: - CalibrationFormView

/// Form for adding or editing a floor profile with label and X/Y/Z coordinate inputs.
private struct CalibrationFormView: View {
    @ObservedObject var viewModel: CalibrationViewModel<BLEService>
    let mode: FormMode
    @Environment(\.dismiss) private var dismiss

    @State private var label: String = ""
    @State private var xValue: String = ""
    @State private var yValue: String = ""
    @State private var zValue: String = ""

    enum FormMode: Identifiable {
        case add
        case edit(FloorProfile)

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let profile): return profile.id.uuidString
            }
        }
    }

    private var title: String {
        switch mode {
        case .add: return "Add Floor"
        case .edit: return "Edit Floor"
        }
    }

    var body: some View {
        Form {
            Section {
                TextField("Floor Label", text: $label)
                    .accessibilityLabel("Floor label")
                    .accessibilityHint("Enter a name for this floor, such as Lobby or 1")
            } header: {
                Text("Label")
            }

            Section {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("X (0–144)", text: $xValue)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityLabel("X coordinate")
                        .accessibilityHint("Enter a value between 0 and 144")
                    if let error = viewModel.validationErrors["x"] {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .accessibilityLabel("Validation error: \(error)")
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Y (0–208)", text: $yValue)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityLabel("Y coordinate")
                        .accessibilityHint("Enter a value between 0 and 208")
                    if let error = viewModel.validationErrors["y"] {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .accessibilityLabel("Validation error: \(error)")
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    TextField("Z (0–100)", text: $zValue)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityLabel("Z coordinate")
                        .accessibilityHint("Enter a value between 0 and 100")
                    if let error = viewModel.validationErrors["z"] {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .accessibilityLabel("Validation error: \(error)")
                    }
                }
            } header: {
                Text("Coordinates")
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    viewModel.validationErrors = [:]
                    dismiss()
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    saveProfile()
                }
                .disabled(label.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityHint("Double-tap to save this floor profile")
            }
        }
        .onAppear {
            if case .edit(let profile) = mode {
                label = profile.label
                xValue = String(profile.x)
                yValue = String(profile.y)
                zValue = String(profile.z)
            }
        }
    }

    private func saveProfile() {
        let x = Int(xValue) ?? -1
        let y = Int(yValue) ?? -1
        let z = Int(zValue) ?? -1

        switch mode {
        case .add:
            let success = viewModel.addProfile(label: label, x: x, y: y, z: z)
            if success {
                dismiss()
            }
        case .edit(let profile):
            let success = viewModel.updateProfile(profile, label: label, x: x, y: y, z: z)
            if success {
                dismiss()
            }
        }
    }
}


// MARK: - Call Button Calibration Form

/// Form for setting X, Y, Z coordinates of the exterior call button.
private struct CallButtonCalibrationForm: View {
    @ObservedObject var bleService: BLEService
    @Environment(\.dismiss) private var dismiss

    @State private var xValue: String = ""
    @State private var yValue: String = ""
    @State private var zValue: String = ""
    @State private var validationError: String? = nil

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("X (0–144)", text: $xValue)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityLabel("X coordinate")
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Y (0–208)", text: $yValue)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityLabel("Y coordinate")
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Z (0–100)", text: $zValue)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                        .accessibilityLabel("Z coordinate")
                }
            } header: {
                Text("Call Button Coordinates")
            }

            if let error = validationError {
                Section {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationTitle("Call Button Position")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
            }
        }
        .onAppear {
            if let profile = bleService.callButtonProfile {
                xValue = String(profile.x)
                yValue = String(profile.y)
                zValue = String(profile.z)
            }
        }
    }

    private func save() {
        let x = Int(xValue) ?? -1
        let y = Int(yValue) ?? -1
        let z = Int(zValue) ?? -1

        guard x >= 0, x <= 144 else { validationError = "X must be 0–144"; return }
        guard y >= 0, y <= 208 else { validationError = "Y must be 0–208"; return }
        guard z >= 0, z <= 100 else { validationError = "Z must be 0–100"; return }

        bleService.callButtonProfile = FloorProfile(
            id: UUID(),
            label: "Call Elevator",
            x: x,
            y: y,
            z: z,
            sortOrder: 0
        )
        dismiss()
    }
}
