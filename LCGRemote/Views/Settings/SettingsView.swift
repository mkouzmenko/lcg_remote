import SwiftUI

/// Settings View with elevator management, diagnostics, about info, and reset options.
struct SettingsView: View {
    @EnvironmentObject var persistenceService: JSONPersistenceService
    @EnvironmentObject var bleService: BLEService

    @StateObject private var viewModel: SettingsViewModel<BLEService>

    // MARK: - Alert State

    @State private var showResetOnboardingAlert = false
    @State private var showResetAllDataAlert = false

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
            elevatorsSection
            diagnosticsSection
            aboutSection
            resetSection
        }
        .navigationTitle("Settings")
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
            Text("This will erase all saved data including elevators and calibration. This cannot be undone.")
        }
    }

    // MARK: - Elevators Section

    private var elevatorsSection: some View {
        Section {
            ForEach(viewModel.elevators) { elevator in
                NavigationLink {
                    EditElevatorView(
                        elevator: elevator,
                        persistenceService: persistenceService,
                        bleService: bleService,
                        onSave: { updated in
                            viewModel.updateElevator(updated)
                        },
                        onDelete: {
                            viewModel.deleteElevator(elevator)
                        }
                    )
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(elevator.name)
                            .font(.headline)
                        HStack(spacing: 12) {
                            Label("\(elevator.floorButtons.count) floors", systemImage: "arrow.up.arrow.down")
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Label("\(elevator.exteriorButtons.count) call", systemImage: "bell.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .accessibilityLabel("\(elevator.name), \(elevator.floorButtons.count) floor buttons, \(elevator.exteriorButtons.count) call buttons")
                .accessibilityHint("Double-tap to edit this elevator")
            }
            .onDelete { indexSet in
                for index in indexSet {
                    viewModel.deleteElevator(viewModel.elevators[index])
                }
            }

            Button {
                viewModel.addElevator()
            } label: {
                Label("Add Elevator", systemImage: "plus")
            }
            .accessibilityHint("Double-tap to add a new elevator")
        } header: {
            Text("Elevators")
                .accessibilityAddTraits(.isHeader)
        } footer: {
            Text("Each elevator has an interior device (shared by floor buttons) and exterior call buttons with their own devices.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
}
