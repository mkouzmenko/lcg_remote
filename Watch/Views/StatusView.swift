import SwiftUI
import WatchKit

/// Displays real-time execution status with visual feedback and Watch haptics.
/// Shows the current phase: Connecting, Calling, Pressing, Done, or Error.
struct StatusView: View {
    let status: WatchStatus
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            statusIcon
                .font(.system(size: 36))
                .foregroundStyle(iconColor)

            Text(status.phase.displayLabel)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(status.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if status.phase == .done || status.phase == .error {
                Button("OK") {
                    onDismiss()
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .onAppear {
            playHaptic(for: status.phase)
        }
        .onChange(of: status.phase) { newPhase in
            playHaptic(for: newPhase)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(status.phase.displayLabel): \(status.message)")
    }

    // MARK: - Status Icon

    @ViewBuilder
    private var statusIcon: some View {
        switch status.phase {
        case .connecting:
            Image(systemName: "antenna.radiowaves.left.and.right")
        case .calling:
            Image(systemName: "phone.arrow.up.right.fill")
        case .pressing:
            Image(systemName: "hand.tap.fill")
        case .done:
            Image(systemName: "checkmark.circle.fill")
        case .error:
            Image(systemName: "exclamationmark.triangle.fill")
        }
    }

    // MARK: - Icon Color

    private var iconColor: Color {
        switch status.phase {
        case .connecting, .calling, .pressing:
            return .blue
        case .done:
            return .green
        case .error:
            return .red
        }
    }

    // MARK: - Haptics

    private func playHaptic(for phase: WatchStatus.WatchPhase) {
        switch phase {
        case .connecting:
            WKInterfaceDevice.current().play(.click)
        case .calling:
            WKInterfaceDevice.current().play(.start)
        case .pressing:
            WKInterfaceDevice.current().play(.directionUp)
        case .done:
            WKInterfaceDevice.current().play(.success)
        case .error:
            WKInterfaceDevice.current().play(.failure)
        }
    }
}

// MARK: - WatchPhase Display Label

extension WatchStatus.WatchPhase {
    var displayLabel: String {
        switch self {
        case .connecting: return "Connecting"
        case .calling: return "Calling Elevator"
        case .pressing: return "Pressing Button"
        case .done: return "Done"
        case .error: return "Error"
        }
    }
}

#Preview {
    StatusView(
        status: WatchStatus(phase: .calling, message: "Sending call command…", presetID: nil),
        onDismiss: {}
    )
}
