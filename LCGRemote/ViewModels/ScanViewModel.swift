import Combine
import Foundation

/// ViewModel driving the Scan View. Observes MockBLEService for discovered
/// devices and scanning state, and exposes connection error handling for
/// unreachable devices.
final class ScanViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var devices: [MockDevice] = []
    @Published var isScanning: Bool = false
    @Published var connectionError: String? = nil

    // MARK: - Dependencies

    private let bleService: MockBLEService
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer

    init(bleService: MockBLEService) {
        self.bleService = bleService

        // Observe discovered devices from the BLE service.
        bleService.$discoveredDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$devices)

        // Observe scanning state from the BLE service.
        bleService.$isScanning
            .receive(on: DispatchQueue.main)
            .assign(to: &$isScanning)

        // Monitor connection state to detect failures (unreachable devices).
        bleService.$connectionState
            .combineLatest(bleService.$statusMessage)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state, message in
                guard let self = self else { return }
                if state == .disconnected && message.contains("not reachable") {
                    self.connectionError = message
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    /// Starts the simulated BLE scan via MockBLEService.
    func startScan() {
        connectionError = nil
        bleService.startScan()
    }

    /// Stops the simulated BLE scan, retaining the current device list.
    func stopScan() {
        bleService.stopScan()
    }

    /// Attempts to connect to the given device. If the device is unreachable,
    /// `connectionError` will be populated after the 3-second timeout.
    func connect(to device: MockDevice) {
        connectionError = nil
        bleService.connect(to: device)
    }

    /// Convenience method to restart scanning (e.g., pull-to-refresh).
    func refresh() {
        connectionError = nil
        bleService.startScan()
    }
}
