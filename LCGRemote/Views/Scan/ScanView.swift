import SwiftUI

/// Displays discovered BLE devices for identification purposes.
/// Shows device name, type, signal strength, and full device ID
/// so users can configure them in Settings/Calibration.
struct ScanView: View {
    @StateObject private var viewModel: ScanViewModel<BLEService>
    @EnvironmentObject var bleService: BLEService

    init(bleService: BLEService) {
        _viewModel = StateObject(wrappedValue: ScanViewModel(bleService: bleService))
    }

    var body: some View {
        VStack {
            if viewModel.isScanning && viewModel.devices.isEmpty {
                scanningIndicator
            } else if viewModel.devices.isEmpty {
                emptyState
            } else {
                deviceList
            }
        }
        .navigationTitle("Scan")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                scanToolbarButton
            }
        }
        .onAppear {
            viewModel.startScan()
        }
    }

    // MARK: - Scanning Indicator

    private var scanningIndicator: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
                .accessibilityLabel("Scanning in progress")
            Text("Scanning for devices...")
                .font(.headline)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.updatesFrequently)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("No devices found")
                .font(.headline)
            Text("Make sure your LCG devices are powered on and nearby.\nPull down or tap Scan to try again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Device List

    private var deviceList: some View {
        List(viewModel.devices) { device in
            DeviceRow(device: device)
                .frame(minHeight: 44)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(accessibilityLabel(for: device))
        }
        .refreshable {
            viewModel.refresh()
            try? await Task.sleep(nanoseconds: 1_600_000_000)
        }
    }

    // MARK: - Toolbar Button

    private var scanToolbarButton: some View {
        Button {
            if viewModel.isScanning {
                viewModel.stopScan()
            } else {
                viewModel.startScan()
            }
        } label: {
            Text(viewModel.isScanning ? "Stop" : "Scan")
        }
        .accessibilityLabel(viewModel.isScanning ? "Stop Scan" : "Start Scan")
        .accessibilityHint(
            viewModel.isScanning
                ? "Double-tap to stop scanning for devices"
                : "Double-tap to start scanning for nearby devices"
        )
    }

    // MARK: - Helpers

    private func accessibilityLabel(for device: BLEDevice) -> String {
        let typeLabel = device.unitType == .interior ? "Interior unit" : "Exterior unit"
        let signalLabel = signalDescription(for: device.rssi)
        return "\(device.name), \(typeLabel), \(signalLabel), ID: \(device.id)"
    }

    private func signalDescription(for rssi: Int) -> String {
        switch rssi {
        case (-50)...0:
            return "Strong signal"
        case (-70)...(-51):
            return "Medium signal"
        default:
            return "Weak signal"
        }
    }
}

// MARK: - Device Row

/// A row displaying a discovered device with icon, name, signal, and device ID.
private struct DeviceRow: View {
    let device: BLEDevice

    var body: some View {
        HStack(spacing: 12) {
            unitTypeIcon
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(device.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Spacer()
                    SignalStrengthIndicator(rssi: device.rssi)
                        .accessibilityHidden(true)
                }

                Text(device.id)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textSelection(.enabled)

                HStack(spacing: 4) {
                    Text(device.unitType == .interior ? "Interior" : "Exterior")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(device.unitType == .interior ? .blue : .orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(device.unitType == .interior
                                    ? Color.blue.opacity(0.1)
                                    : Color.orange.opacity(0.1))
                        )
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var unitTypeIcon: some View {
        Image(systemName: device.unitType == .interior ? "elevator.fill" : "arrow.up.arrow.down")
            .font(.title3)
            .foregroundStyle(device.unitType == .interior ? .blue : .orange)
    }
}

// MARK: - Signal Strength Indicator

private struct SignalStrengthIndicator: View {
    let rssi: Int

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(index < barCount ? barColor : Color.gray.opacity(0.3))
                    .frame(width: 4, height: CGFloat(6 + index * 4))
            }
        }
        .frame(width: 20, height: 14)
    }

    private var barCount: Int {
        switch rssi {
        case (-50)...0:
            return 3
        case (-70)...(-51):
            return 2
        default:
            return 1
        }
    }

    private var barColor: Color {
        switch rssi {
        case (-50)...0:
            return .green
        case (-70)...(-51):
            return .orange
        default:
            return .red
        }
    }
}
