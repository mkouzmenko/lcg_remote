import SwiftUI

/// Displays and manages floor profile calibration: list, add, edit, delete, reorder, and test.
struct CalibrationView: View {
    @StateObject private var viewModel: CalibrationViewModel
    @State private var showingAddForm = false
    @State private var profileToEdit: FloorProfile? = nil
    @State private var profileToDelete: FloorProfile? = nil
    @State private var showDeleteConfirmation = false

    init(bleService: MockBLEService, persistenceService: JSONPersistenceService) {
        _viewModel = StateObject(wrappedValue: CalibrationViewModel(
            bleService: bleService,
            persistenceService: persistenceService
        ))
    }

    var body: some View {
        List {
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
            }
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
    @ObservedObject var viewModel: CalibrationViewModel
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
