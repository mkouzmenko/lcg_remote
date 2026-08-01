import SwiftUI

/// Root navigation view with three tabs: Control, Presets, Settings.
/// Maintains connection state across tab switches via shared BLEService.
///
/// Requirements: 11.1, 11.2, 11.3, 11.4, 11.5, 11.6, 1.5, 1.7, 9.3, 9.6, 13.4
struct ContentView: View {
    @EnvironmentObject var bleService: BLEService
    @EnvironmentObject var persistenceService: JSONPersistenceService
    @EnvironmentObject var hapticsService: HapticsService

    var body: some View {
        TabView {
            controlTab
                .tabItem {
                    Label("Control", systemImage: "elevator")
                }

            presetsTab
                .tabItem {
                    Label("Presets", systemImage: "star.fill")
                }

            settingsTab
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }

    // MARK: - Control Tab (Requirements 11.2, 11.3, 11.5)

    /// Shows ScanView when disconnected, DeviceControlView when connected.
    /// Toolbar gear button links to CalibrationView when connected.
    private var controlTab: some View {
        NavigationStack {
            Group {
                if bleService.connectedDevice != nil {
                    DeviceControlView(viewModel: DeviceControlViewModel(
                        bleService: bleService,
                        hapticsService: hapticsService
                    ))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            NavigationLink {
                                CalibrationView(
                                    bleService: bleService,
                                    persistenceService: persistenceService
                                )
                            } label: {
                                Image(systemName: "gearshape")
                                    .accessibilityLabel("Calibration")
                                    .accessibilityHint("Double-tap to open floor calibration settings")
                            }
                        }
                    }
                } else {
                    ScanView(bleService: bleService)
                }
            }
        }
    }

    // MARK: - Presets Tab

    private var presetsTab: some View {
        PresetsView(
            bleService: bleService,
            persistenceService: persistenceService,
            hapticsService: hapticsService
        )
    }

    // MARK: - Settings Tab (Requirement 11.6)

    private var settingsTab: some View {
        SettingsView(
            persistenceService: persistenceService,
            bleService: bleService
        )
    }
}
