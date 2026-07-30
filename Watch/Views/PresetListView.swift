import SwiftUI

/// Displays the user's Location Presets as a scrollable list on Apple Watch.
/// Tapping a preset sends an activation message to the iPhone via WCSession.
struct PresetListView: View {
    @ObservedObject var sessionManager: WatchSessionManager

    var body: some View {
        List {
            ForEach(sessionManager.presets) { preset in
                Button {
                    sessionManager.activatePreset(preset.id)
                } label: {
                    HStack {
                        Image(systemName: "elevator.fill")
                            .foregroundStyle(.blue)
                        Text(preset.name)
                            .font(.body)
                            .lineLimit(2)
                    }
                }
                .accessibilityLabel("Activate \(preset.name)")
                .accessibilityHint("Double-tap to call elevator for \(preset.name)")
            }
        }
        .navigationTitle("Presets")
    }
}

#Preview {
    NavigationStack {
        PresetListView(sessionManager: WatchSessionManager.shared)
    }
}
