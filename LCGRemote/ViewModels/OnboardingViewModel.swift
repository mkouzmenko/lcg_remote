import Foundation
import SwiftUI

/// ViewModel managing the onboarding flow state machine.
/// Guides new users through a simulated Bluetooth permission and device pairing sequence.
///
/// Step flow:
///   welcome → bluetoothPermission → (allow → scanning 2s → deviceFound → connecting 1s → paired)
///                                   or (deny → permissionDenied → try again → bluetoothPermission)
final class OnboardingViewModel: ObservableObject {
    // MARK: - Step Enum

    enum OnboardingStep {
        case welcome
        case bluetoothPermission
        case scanning
        case deviceFound
        case connecting
        case paired
        case permissionDenied
    }

    // MARK: - Published Properties

    @Published var currentStep: OnboardingStep = .welcome
    @Published var isComplete: Bool = false

    // MARK: - Dependencies

    private let bleService: MockBLEService

    // MARK: - UserDefaults Key

    private static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    // MARK: - Static Property (Requirement 1.7)

    /// Indicates whether the user has previously completed onboarding.
    /// Backed by UserDefaults so onboarding is skipped on subsequent launches.
    static var hasCompletedOnboarding: Bool {
        get { UserDefaults.standard.bool(forKey: hasCompletedOnboardingKey) }
        set { UserDefaults.standard.set(newValue, forKey: hasCompletedOnboardingKey) }
    }

    // MARK: - Init

    init(bleService: MockBLEService) {
        self.bleService = bleService
    }

    // MARK: - Actions

    /// Advances from the welcome screen to the simulated Bluetooth permission prompt.
    /// (Requirement 1.1 → 1.2)
    func getStarted() {
        currentStep = .bluetoothPermission
    }

    /// Simulates granting Bluetooth permission, triggering a 2-second scan
    /// that discovers the onboarding demo device.
    /// (Requirement 1.2 → 1.3)
    func allowBluetooth() {
        currentStep = .scanning

        // Simulate a 2-second scanning delay before showing the device
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self, self.currentStep == .scanning else { return }
            self.currentStep = .deviceFound
        }
    }

    /// Simulates denying Bluetooth permission, showing a message that BLE is required.
    /// (Requirement 1.6)
    func denyBluetooth() {
        currentStep = .permissionDenied
    }

    /// Called when "Try Again" is tapped from the permission denied screen.
    /// Returns user to the permission prompt.
    /// (Requirement 1.6)
    func tryAgain() {
        currentStep = .bluetoothPermission
    }

    /// Simulates selecting the discovered demo device and connecting with a 1-second delay.
    /// On success, transitions to the paired state and connects via MockBLEService.
    /// (Requirement 1.4)
    func selectDevice() {
        currentStep = .connecting

        // Connect to the onboarding demo device via MockBLEService
        let device = SeedData.onboardingDevice
        bleService.connect(to: device)

        // Simulate a 1-second connection delay for onboarding
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self, self.currentStep == .connecting else { return }
            self.currentStep = .paired
        }
    }

    /// Completes onboarding: persists the completion flag and marks the flow as done.
    /// (Requirement 1.5, 1.7)
    func finishOnboarding() {
        Self.hasCompletedOnboarding = true
        isComplete = true
    }
}
