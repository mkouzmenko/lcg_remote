import SwiftUI

@main
struct LCGRemoteApp: App {
    @StateObject private var mockBLEService = MockBLEService()
    @StateObject private var persistenceService = JSONPersistenceService()
    @StateObject private var hapticsService = HapticsService()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(mockBLEService)
                    .environmentObject(persistenceService)
                    .environmentObject(hapticsService)
            } else {
                OnboardingView(bleService: mockBLEService)
                    .environmentObject(mockBLEService)
                    .environmentObject(persistenceService)
                    .environmentObject(hapticsService)
            }
        }
    }
}
