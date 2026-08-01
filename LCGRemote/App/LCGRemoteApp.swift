import SwiftUI

@main
struct LCGRemoteApp: App {
    @StateObject private var bleService = BLEService()
    @StateObject private var persistenceService = JSONPersistenceService()
    @StateObject private var hapticsService = HapticsService()

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(bleService)
                    .environmentObject(persistenceService)
                    .environmentObject(hapticsService)
            } else {
                OnboardingView(bleService: bleService)
                    .environmentObject(bleService)
                    .environmentObject(persistenceService)
                    .environmentObject(hapticsService)
            }
        }
    }
}
