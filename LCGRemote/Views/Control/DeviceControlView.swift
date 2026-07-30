import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Device Control View displaying floor buttons for interior units
/// or a single call button for exterior units, with status indicators
/// and full VoiceOver accessibility support.
struct DeviceControlView: View {
    @ObservedObject var viewModel: DeviceControlViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(spacing: 16) {
            statusArea

            Spacer()

            if let device = viewModel.connectedDevice {
                if device.unitType == .exterior {
                    exteriorCallButton
                } else {
                    interiorFloorGrid
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Control")
        .toolbar {
            ToolbarItem(placement: .principal) {
                connectedDeviceIndicator
            }
        }
        .onChange(of: viewModel.deviceStatus) { newStatus in
            announceStatusChange(newStatus)
        }
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
                    .scaleEffect(reduceMotion ? 1.0 : 1.0)
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

    // MARK: - Interior Floor Grid

    private var interiorFloorGrid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(SeedData.defaultButtonMap.profiles.sorted(by: { $0.sortOrder < $1.sortOrder })) { profile in
                Button {
                    viewModel.selectFloor(profile)
                } label: {
                    Text(profile.label)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 60)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.accentColor.opacity(0.15))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accentColor, lineWidth: 2)
                        )
                }
                .buttonStyle(.plain)
                .disabled(viewModel.deviceStatus != .idle)
                .accessibilityLabel("Floor \(profile.label)")
                .accessibilityHint("Double-tap to select floor \(profile.label)")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Exterior Call Button

    private var exteriorCallButton: some View {
        Button {
            viewModel.callElevator()
        } label: {
            Text("Call Elevator")
                .font(.title)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 120)
                .foregroundStyle(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.accentColor)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.deviceStatus != .idle)
        .padding(.horizontal)
        .accessibilityLabel("Call Elevator")
        .accessibilityHint("Double-tap to call the elevator")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Connected Device Indicator

    @ViewBuilder
    private var connectedDeviceIndicator: some View {
        if let device = viewModel.connectedDevice {
            HStack(spacing: 6) {
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
                Text(device.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(device.name), connected")
        }
    }

    // MARK: - Accessibility Announcements

    private func announceStatusChange(_ status: MockBLEService.DeviceStatus) {
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
