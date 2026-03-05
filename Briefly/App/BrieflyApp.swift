import SwiftUI

@main
struct BrieflyApp: App {
    @UIApplicationDelegateAdaptor(BrieflyAppDelegate.self) private var appDelegate
    @StateObject private var coordinator = AppCoordinator()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(coordinator)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    guard phase == .active else { return }
                    Task { @MainActor in
                        ContentRepository.shared.refreshFromCloud()
                    }
                }
        }
    }
}
