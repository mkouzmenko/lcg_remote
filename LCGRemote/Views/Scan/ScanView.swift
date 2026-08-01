import SwiftUI

/// Displays discovered BLE devices and manages scanning lifecycle.
/// Shows a scanning animation during the 1.5s delay, then lists devices
/// with name, unit type icon, and signal strength indicator.
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
        .alert(
            "Connection Error",
            isPresented: showConnectionError,
            actions: {
                Button("Retry") {
                    viewModel.startScan()
                }
                Button("OK", role: .cancel) {}
            },
            message: {
                Text(viewModel.connectionError ?? "An error occurred.")
            }
        )
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
            Text("Pull down to scan again")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Device List

    private var deviceList: some View {
        List(viewModel.devices) { device in
            Button {
                viewModel.connect(to: device)
            } label: {
                DeviceRow(device: device)
            }
            .frame(minHeight: 44)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: device))
            .accessibilityHint("Double-tap to connect to this device")
        }
        .refreshable {
            viewModel.refresh()
            // Allow time for the scan to complete
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
            Text(viewModel.isScanning ? "Stop Scan" : "Scan")
        }
        .accessibilityLabel(viewModel.isScanning ? "Stop Scan" : "Start Scan")
        .accessibilityHint(
            viewModel.isScanning
                ? "Double-tap to stop scanning for devices"
                : "Double-tap to start scanning for nearby devices"
        )
    }

    // MARK: - Helpers

    private var showConnectionError: Binding<Bool> {
        Binding(
            get: { viewModel.connectionError != nil },
            set: { if !$0 { viewModel.connectionError = nil } }
        )
    }

    private func accessibilityLabel(for device: BLEDevice) -> String {
        let typeLabel = device.unitType == .interior ? "Interior unit" : "Exterior unit"
        let signalLabel = signalDescription(for: device.rssi)
        return "\(device.name), \(typeLabel), \(signalLabel)"
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

/// A row displaying a single device with icon, name, and signal strength.
private struct DeviceRow: View {
    let device: BLEDevice

    var body: some View {
        HStack(spacing: 12) {
            unitTypeIcon
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            Text(device.name)
                .font(.body)
                .foregroundStyle(.primary)

            Spacer()

            SignalStrengthIndicator(rssi: device.rssi)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var unitTypeIcon: some View {
        Image(systemName: device.unitType == .interior ? "elevator.fill" : "arrow.up.arrow.down")
            .font(.title3)
            .foregroundStyle(.blue)
    }
}

// MARK: - Signal Strength Indicator

/// Displays a wifi-style signal icon based on RSSI value.
/// Uses wifi SF Symbols with bars to indicate signal strength.
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
