import SwiftUI

/// Guided first-launch experience simulating Bluetooth permission and device pairing.
/// Presents a multi-step flow: welcome → permission → scanning → device found → connecting → paired.
/// Supports VoiceOver, Dynamic Type, and Reduce Motion accessibility settings.
///
/// Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 8.1, 8.3, 8.6, 9.1, 9.5
struct OnboardingView: View {
    @EnvironmentObject var bleService: BLEService
    @StateObject private var viewModel: OnboardingViewModel<BLEService>

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Creates the OnboardingView, injecting the shared BLEService into the ViewModel.
    init(bleService: BLEService) {
        _viewModel = StateObject(wrappedValue: OnboardingViewModel(bleService: bleService))
    }

    var body: some View {
        Group {
            switch viewModel.currentStep {
            case .welcome:
                welcomeScreen
            case .bluetoothPermission:
                bluetoothPermissionScreen
            case .scanning:
                scanningScreen
            case .deviceFound:
                deviceFoundScreen
            case .connecting:
                connectingScreen
            case .paired:
                pairedScreen
            case .permissionDenied:
                permissionDeniedScreen
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: viewModel.currentStep)
    }

    // MARK: - Welcome Screen (Requirement 1.1)

    private var welcomeScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "elevator.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Welcome to LCG Remote")
                .font(.title)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text("Control your elevator access with ease. This app connects to LiftGate devices via Bluetooth to select floors and call elevators.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: { viewModel.getStarted() }) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.horizontal, 40)
            .accessibilityLabel("Get Started")
            .accessibilityHint("Double-tap to begin setup")

            Spacer()
                .frame(height: 40)
        }
        .padding()
    }

    // MARK: - Bluetooth Permission Screen (Requirement 1.2)

    private var bluetoothPermissionScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 64))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)

            Text("Bluetooth Permission")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text("LCG Remote needs Bluetooth to discover and communicate with LiftGate devices. This is a simulated permission prompt.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            VStack(spacing: 12) {
                Button(action: { viewModel.allowBluetooth() }) {
                    Text("Allow")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .accessibilityLabel("Allow Bluetooth")
                .accessibilityHint("Double-tap to grant Bluetooth permission and start scanning")

                Button(action: { viewModel.denyBluetooth() }) {
                    Text("Don't Allow")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Don't Allow Bluetooth")
                .accessibilityHint("Double-tap to deny Bluetooth permission")
            }
            .padding(.horizontal, 40)

            Spacer()
                .frame(height: 40)
        }
        .padding()
    }

    // MARK: - Scanning Screen (Requirement 1.3)

    private var scanningScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            if reduceMotion {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
            } else {
                ProgressView()
                    .scaleEffect(2.0)
                    .progressViewStyle(.circular)
                    .accessibilityHidden(true)
            }

            Text("Scanning for Devices")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text("Looking for nearby LiftGate devices...")
                .font(.body)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Scanning for nearby LiftGate devices")

            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Scanning for devices. Please wait.")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Device Found Screen (Requirement 1.3)

    private var deviceFoundScreen: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("Device Found")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text("Select a device to pair with:")
                .font(.body)
                .foregroundStyle(.secondary)

            // Device list showing the onboarding demo device
            Button(action: { viewModel.selectDevice() }) {
                HStack(spacing: 16) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.title3)
                        .foregroundStyle(.blue)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(SeedData.onboardingDevice.name)
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Interior Unit • Strong Signal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .accessibilityLabel("\(SeedData.onboardingDevice.name), Interior Unit, Strong Signal")
            .accessibilityHint("Double-tap to pair with this device")
            .accessibilityAddTraits(.isButton)

            Spacer()
        }
        .padding()
    }

    // MARK: - Connecting Screen (Requirement 1.4)

    private var connectingScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            if reduceMotion {
                Image(systemName: "link")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                    .accessibilityHidden(true)
            } else {
                ProgressView()
                    .scaleEffect(2.0)
                    .progressViewStyle(.circular)
                    .accessibilityHidden(true)
            }

            Text("Connecting")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text("Pairing with \(SeedData.onboardingDevice.name)...")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting to \(SeedData.onboardingDevice.name). Please wait.")
        .accessibilityAddTraits(.updatesFrequently)
    }

    // MARK: - Paired Success Screen (Requirement 1.4, 1.5)

    private var pairedScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
                .accessibilityHidden(true)

            Text("Device Paired")
                .font(.title)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text("Successfully connected to \(SeedData.onboardingDevice.name). You're all set to control your elevator.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: { viewModel.finishOnboarding() }) {
                Text("Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.horizontal, 40)
            .accessibilityLabel("Continue")
            .accessibilityHint("Double-tap to finish setup and go to the control screen")

            Spacer()
                .frame(height: 40)
        }
        .padding()
    }

    // MARK: - Permission Denied Screen (Requirement 1.6)

    private var permissionDeniedScreen: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)
                .accessibilityHidden(true)

            Text("Bluetooth Required")
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityAddTraits(.isHeader)

            Text("LCG Remote requires Bluetooth to discover and connect to LiftGate devices. Without Bluetooth, the app cannot function. Please allow access to continue.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button(action: { viewModel.tryAgain() }) {
                Text("Try Again")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.horizontal, 40)
            .accessibilityLabel("Try Again")
            .accessibilityHint("Double-tap to return to the Bluetooth permission prompt")

            Spacer()
                .frame(height: 40)
        }
        .padding()
    }
}
