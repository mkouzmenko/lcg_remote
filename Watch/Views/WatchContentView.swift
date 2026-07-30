import SwiftUI

/// Main content view for the Apple Watch companion app.
/// Displays presets relayed from the paired iPhone via WatchConnectivity.
/// Shows status feedback during preset execution.
struct WatchContentView: View {
    @StateObject private var sessionManager = WatchSessionManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if !sessionManager.isPhoneReachable {
                    phoneUnreachableView
                } else if let status = sessionManager.currentStatus,
                          status.phase != .done && status.phase != .error {
                    StatusView(status: status) {
                        sessionManager.currentStatus = nil
                    }
                } else if sessionManager.presets.isEmpty {
                    emptyStateView
                } else {
                    PresetListView(sessionManager: sessionManager)
                }
            }
            .navigationTitle("LCG")
        }
        .onAppear {
            sessionManager.activate()
        }
        .sheet(isPresented: showCompletionStatus) {
            if let status = sessionManager.currentStatus {
                StatusView(status: status) {
                    sessionManager.currentStatus = nil
                }
            }
        }
    }

    // MARK: - Phone Unreachable

    private var phoneUnreachableView: some View {
        VStack(spacing: 12) {
            Image(systemName: "iphone.slash")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("iPhone Not Reachable")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Make sure your iPhone is nearby with LCG Remote open.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("iPhone not reachable. Make sure your iPhone is nearby with LCG Remote open.")
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "elevator.fill")
                .font(.largeTitle)
                .foregroundStyle(.blue)
            Text("LCG Remote")
                .font(.headline)
            Text("No presets synced")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Create presets on your iPhone to see them here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Completion Status Binding

    private var showCompletionStatus: Binding<Bool> {
        Binding(
            get: {
                guard let status = sessionManager.currentStatus else { return false }
                return status.phase == .done || status.phase == .error
            },
            set: { newValue in
                if !newValue {
                    sessionManager.currentStatus = nil
                }
            }
        )
    }
}

#Preview {
    WatchContentView()
}
