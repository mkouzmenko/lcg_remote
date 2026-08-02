import SwiftUI

/// Root view — single screen with the unified elevator button grid.
/// Gear icon in toolbar leads to Settings/Configuration.
struct ContentView: View {
    @EnvironmentObject var bleService: BLEService
    @EnvironmentObject var persistenceService: JSONPersistenceService
    @EnvironmentObject var hapticsService: HapticsService

    var body: some View {
        NavigationStack {
            DeviceControlView(viewModel: DeviceControlViewModel(
                bleService: bleService,
                hapticsService: hapticsService,
                persistenceService: persistenceService
            ))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView(
                            persistenceService: persistenceService,
                            bleService: bleService
                        )
                    } label: {
                        Image(systemName: "gearshape")
                            .accessibilityLabel("Settings")
                            .accessibilityHint("Double-tap to open settings and elevator configuration")
                    }
                }
            }
        }
    }
}
