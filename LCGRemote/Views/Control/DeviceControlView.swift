import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Unified Control View displaying all buttons (call elevator + floor buttons) on one screen.
/// Each button auto-connects to its configured BLE device and sends X/Y/Z coordinates.
struct DeviceControlView: View {
    @ObservedObject var viewModel: DeviceControlViewModel<BLEService>
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 16) {
            statusArea

            Spacer()

            buttonGrid

            Spacer()
        }
        .padding()
        .navigationTitle("Control")
        .onAppear {
            viewModel.startScan()
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

    // MARK: - Button Grid

    private var buttonGrid: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(viewModel.buttonConfigs.sorted(by: { $0.sortOrder < $1.sortOrder })) { config in
                controlButton(for: config)
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func controlButton(for config: ButtonConfig) -> some View {
        if config.deviceType == .exterior {
            // Call Elevator button — prominent styling
            Button {
                viewModel.tapButton(config)
            } label: {
                Text(config.label)
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
            .accessibilityLabel(config.label)
            .accessibilityHint("Double-tap to \(config.label.lowercased())")
            .accessibilityAddTraits(.isButton)
        } else {
            // Floor button — standard styling
            Button {
                viewModel.tapButton(config)
            } label: {
                Text(config.label)
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
            .accessibilityLabel("Floor \(config.label)")
            .accessibilityHint("Double-tap to select floor \(config.label)")
            .accessibilityAddTraits(.isButton)
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
