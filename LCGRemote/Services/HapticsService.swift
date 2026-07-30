import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/// Provides haptic feedback for key user interactions.
/// Respects the iOS Reduce Motion accessibility setting — when enabled, haptics are suppressed.
final class HapticsService: ObservableObject {

    // MARK: - Public API

    /// Medium impact haptic for successful device connection.
    /// Validates: Requirement 10.1
    func connectionEstablished() {
        guard shouldPlayHaptics else { return }
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    /// Success notification haptic for completed commands.
    /// Validates: Requirement 10.2
    func commandSuccess() {
        guard shouldPlayHaptics else { return }
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
        #endif
    }

    /// Error notification haptic for failed commands or connection errors.
    /// Validates: Requirement 10.3
    func commandError() {
        guard shouldPlayHaptics else { return }
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
        #endif
    }

    /// Light impact haptic for immediate button tap confirmation.
    /// Validates: Requirement 10.4
    func buttonTap() {
        guard shouldPlayHaptics else { return }
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    // MARK: - Private

    /// Checks whether haptics should be played.
    /// Suppresses haptics when Reduce Motion is enabled (used as proxy for Reduce Haptics).
    /// Validates: Requirement 10.5
    private var shouldPlayHaptics: Bool {
        #if canImport(UIKit)
        return !UIAccessibility.isReduceMotionEnabled
        #else
        return false
        #endif
    }
}
