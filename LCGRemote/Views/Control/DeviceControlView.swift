import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Unified Control View displaying elevator buttons grouped by exterior (call) and interior (floor).
/// If multiple elevators are configured, shows a segmented picker to switch between them.
struct DeviceControlView: View {
    @ObservedObject var viewModel: DeviceControlViewModel<BLEService>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 16) {
            // Elevator picker (only if multiple elevators)
            if viewModel.hasMultipleElevators {
                elevatorPicker
            }

            statusArea

            Spacer()

            ScrollView {
                VStack(spacing: 20) {
                    // Exterior buttons section
                    if !viewModel.exteriorButtons.isEmpty {
                        exteriorSection
                    }

                    // Floor buttons section
                    if !viewModel.floorButtons.isEmpty {
                        floorSection
                    }
                }
                .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.vertical)
        .navigationTitle("Control")
        .onAppear {
            viewModel.startScan()
        }
        .onChange(of: viewModel.deviceStatus) { newStatus in
            announceStatusChange(newStatus)
        }
    }

    // MARK: - Elevator Picker

    private var elevatorPicker: some View {
        Picker("Elevator", selection: Binding(
            get: { viewModel.selectedElevatorID ?? UUID() },
            set: { viewModel.selectElevator($0) }
        )) {
            ForEach(viewModel.elevators) { elevator in
                Text(elevator.name).tag(elevator.id)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
        .accessibilityLabel("Select elevator")
    }

    // MARK: - Status Area

    @ViewBuilder
    private var statusArea: some View {
        switch viewModel.deviceStatus {
        case .idle:
            Text("Ready")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Device ready")

        case .busy:
            VStack(spacing: 8) {
                ProgressView()
                    .controlSize(.regular)
                    .accessibilityLabel("Loading")
                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel.statusMessage)
            .accessibilityAddTraits(.updatesFrequently)

        case .done:
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.green)
                    .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.5), value: viewModel.deviceStatus)
                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.green)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Success. \(viewModel.statusMessage)")

        case .error:
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.red)
                Text(viewModel.statusMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                Button("Retry") {
                    viewModel.retryLastCommand()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .accessibilityLabel("Retry")
                .accessibilityHint("Double-tap to retry the last command")
            }
            .accessibilityElement(children: .contain)
        }
    }

    // MARK: - Exterior Buttons Section

    private var exteriorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Call Elevator")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.exteriorButtons) { button in
                    Button {
                        viewModel.tapExteriorButton(button)
                    } label: {
                        Text(button.label)
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 70)
                            .foregroundStyle(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.orange)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.deviceStatus != .idle)
                    .accessibilityLabel(button.label)
                    .accessibilityHint("Double-tap to call elevator")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    // MARK: - Floor Buttons Section

    private var floorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Floors")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.floorButtons) { button in
                    Button {
                        viewModel.tapFloorButton(button)
                    } label: {
                        Text(button.label)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 60)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue.opacity(0.15))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.blue, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.deviceStatus != .idle)
                    .accessibilityLabel("Floor \(button.label)")
                    .accessibilityHint("Double-tap to select floor \(button.label)")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    // MARK: - Accessibility Announcements

    private func announceStatusChange(_ status: BLEDeviceStatus) {
        let message: String
        switch status {
        case .idle:
            message = "Ready"
        case .busy:
            message = viewModel.statusMessage.isEmpty ? "Processing" : viewModel.statusMessage
        case .done:
            message = viewModel.statusMessage.isEmpty ? "Command completed" : viewModel.statusMessage
        case .error:
            message = viewModel.statusMessage.isEmpty ? "Error occurred" : viewModel.statusMessage
        }
        #if canImport(UIKit)
        UIAccessibility.post(notification: .announcement, argument: message)
        #endif
    }
}
