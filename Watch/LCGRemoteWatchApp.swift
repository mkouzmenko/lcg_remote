import SwiftUI
import WatchKit

@main
struct LCGRemoteWatchApp: App {
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            WatchContentView()
        }
    }
}

/// App delegate to activate WatchConnectivity early in the app lifecycle.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchSessionManager.shared.activate()
    }
}
