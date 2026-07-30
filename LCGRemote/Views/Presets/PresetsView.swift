import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Displays and manages Location Presets with one-tap execution.
/// Shows a step-by-step progress overlay during preset execution with
/// VoiceOver announcements for phase changes and haptic confirmation on completion.
///
/// Requirements: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6, 6.7, 8.1, 8.2, 8.5, 9.1
struct PresetsView: View {
    @StateObject private var viewModel: PresetsViewModel
    @State private var showingCreateSheet = false
    @State private var lastAnnouncedPhase: PresetPhase? = nil

    init(bleService: MockBLEService, persistenceService: JSONPersistenceService, hapticsService: HapticsService) {
        _viewModel = StateObject(wrappedValue: PresetsViewModel(
            bleService: bleService,
            persistenceService: persistenceService,
            hapticsService: hapticsService
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                presetList
                    .navigationTitle("Presets")
                    .toolbar {
                        ToolbarItem(placement: .automatic) {
                            Button {
                                showingCreateSheet = true
                            } label: {
                                Image(systemName: "plus")
                            }
                            .accessibilityLabel("Add Preset")
                            .accessibilityHint("Double-tap to create a new location preset")
                        }
                    }

                if viewModel.isExecuting {
                    executionOverlay
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                CreatePresetView(viewModel: viewModel)
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
            .onChange(of: viewModel.currentPhase) { newValue in
                announcePhaseChange(newValue)
            }
        }
    }

    // MARK: - Preset List

    private var presetList: some View {
        List {
            if viewModel.presets.isEmpty {
                Text("No presets configured.\nTap + to create one.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
                    .accessibilityLabel("No presets configured. Tap the plus button to create one.")
            } else {
                ForEach(viewModel.presets) { preset in
                    PresetRow(preset: preset) {
                        viewModel.executePreset(preset)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            viewModel.deletePreset(preset)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #endif
    }

    // MARK: - Execution Overlay (Requirements 6.2, 6.3, 6.4)

    private var executionOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: 24) {
                if viewModel.currentPhase == .done {
                    // Success animation (Requirement 6.4)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)

                    Text("Complete!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .accessibilityAddTraits(.updatesFrequently)
                } else {
                    // Progress indicator (Requirement 6.3)
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
                        .accessibilityHidden(true)

                    if let phase = viewModel.currentPhase {
                        Text(phase.rawValue)
                            .font(.headline)
                            .accessibilityAddTraits(.updatesFrequently)
                    }

                    ProgressView(value: viewModel.executionProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 200)
                        .accessibilityValue("\(Int(viewModel.executionProgress * 100)) percent complete")
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel(executionAccessibilityLabel)
        }
    }

    // MARK: - Accessibility

    private var executionAccessibilityLabel: String {
        if let phase = viewModel.currentPhase {
            if phase == .done {
                return "Preset execution complete"
            }
            return "Executing preset: \(phase.rawValue)"
        }
        return "Executing preset"
    }

    /// Posts a VoiceOver announcement when the execution phase changes.
    /// Validates: Requirements 8.2, 8.5
    private func announcePhaseChange(_ phase: PresetPhase?) {
        guard let phase = phase, phase != lastAnnouncedPhase else { return }
        lastAnnouncedPhase = phase

        let message: String
        switch phase {
        case .connectingExterior:
            message = "Step 1: Connecting to exterior unit"
        case .callingElevator:
            message = "Step 2: Calling elevator"
        case .connectingInterior:
            message = "Step 3: Connecting to interior unit"
        case .selectingFloor:
            message = "Step 4: Selecting floor"
        case .done:
            message = "Preset execution complete"
        }

        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
}

// MARK: - Preset Row

/// Displays a single preset with its name, associated devices, and a play button.
private struct PresetRow: View {
    let preset: LocationPreset
    let onExecute: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)

                Text(deviceSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                onExecute()
            } label: {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Execute \(preset.name)")
            .accessibilityHint("Double-tap to run this preset")
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Returns a human-readable summary of the associated devices.
    private var deviceSummary: String {
        var parts: [String] = []
        if let extID = preset.exteriorDeviceID,
           let device = SeedData.devices.first(where: { $0.id == extID }) {
            parts.append(device.name)
        }
        if let intID = preset.interiorDeviceID,
           let device = SeedData.devices.first(where: { $0.id == intID }) {
            parts.append(device.name)
        }
        return parts.isEmpty ? "No devices" : parts.joined(separator: " → ")
    }
}

// MARK: - Create Preset Sheet (Requirement 6.5)

/// A form sheet for creating a new Location Preset by selecting
/// an exterior device, an interior device, and a target floor.
private struct CreatePresetView: View {
    @ObservedObject var viewModel: PresetsViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var presetName = ""
    @State private var selectedExteriorID: String? = nil
    @State private var selectedInteriorID: String? = nil
    @State private var selectedFloorID: UUID? = nil

    private var exteriorDevices: [MockDevice] {
        SeedData.devices.filter { $0.unitType == .exterior }
    }

    private var interiorDevices: [MockDevice] {
        SeedData.devices.filter { $0.unitType == .interior }
    }

    private var availableFloors: [FloorProfile] {
        SeedData.defaultButtonMap.profiles
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Preset Name") {
                    TextField("e.g. Go to Office", text: $presetName)
                        .accessibilityLabel("Preset name")
                        .accessibilityHint("Enter a name for the new preset")
                }

                Section("Exterior Device") {
                    Picker("Exterior Unit", selection: $selectedExteriorID) {
                        Text("None").tag(String?.none)
                        ForEach(exteriorDevices) { device in
                            Text(device.name).tag(Optional(device.id))
                        }
                    }
                    .accessibilityLabel("Exterior device picker")
                    .accessibilityHint("Select the exterior unit for this preset")
                }

                Section("Interior Device") {
                    Picker("Interior Unit", selection: $selectedInteriorID) {
                        Text("None").tag(String?.none)
                        ForEach(interiorDevices) { device in
                            Text(device.name).tag(Optional(device.id))
                        }
                    }
                    .accessibilityLabel("Interior device picker")
                    .accessibilityHint("Select the interior unit for this preset")
                }

                Section("Target Floor") {
                    Picker("Floor", selection: $selectedFloorID) {
                        Text("None").tag(UUID?.none)
                        ForEach(availableFloors) { profile in
                            Text(profile.label).tag(Optional(profile.id))
                        }
                    }
                    .accessibilityLabel("Target floor picker")
                    .accessibilityHint("Select the destination floor for this preset")
                }
            }
            .navigationTitle("New Preset")
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
                        viewModel.createPreset(
                            name: presetName,
                            exteriorID: selectedExteriorID,
                            interiorID: selectedInteriorID,
                            floorID: selectedFloorID
                        )
                        dismiss()
                    }
                    .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityHint("Double-tap to save the new preset")
                }
            }
        }
    }
}
