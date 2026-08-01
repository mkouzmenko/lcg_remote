import Combine
import Foundation

/// ViewModel driving the Scan View. Observes the BLE service for discovered
/// devices and scanning state, and exposes connection error handling for
/// unreachable devices.
@MainActor
final class ScanViewModel<Service: BLEServiceProtocol>: ObservableObject {
    // MARK: - Published Properties

    @Published var devices: [BLEDevice] = []
    @Published var isScanning: Bool = false
    @Published var connectionError: String? = nil

    // MARK: - Dependencies

    private let bleService: Service
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer

    init(bleService: Service) {
        self.bleService = bleService

        setupBindings()
    }

    // MARK: - Actions

    /// Starts the BLE scan via the BLE service.
    func startScan() {
        connectionError = nil
        bleService.startScan()
    }

    /// Stops the BLE scan, retaining the current device list.
    func stopScan() {
        bleService.stopScan()
    }

    /// Attempts to connect to the given device. If the device is unreachable,
    /// `connectionError` will be populated after the 3-second timeout.
    func connect(to device: BLEDevice) {
        connectionError = nil
        bleService.connect(to: device)
    }

    /// Convenience method to restart scanning (e.g., pull-to-refresh).
    func refresh() {
        connectionError = nil
        bleService.startScan()
    }

    // MARK: - Private

    private func setupBindings() {
        // Observe all changes from the BLE service and sync relevant state
        bleService.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Schedule the read for the next run loop tick (after the change)
                DispatchQueue.main.async {
                    self.devices = self.bleService.discoveredDevices
                    self.isScanning = self.bleService.isScanning

                    // Detect connection failures
                    if self.bleService.connectionState == .disconnected
                        && self.bleService.statusMessage.contains("not reachable") {
                        self.connectionError = self.bleService.statusMessage
                    }
                }
            }
            .store(in: &cancellables)
    }
}
