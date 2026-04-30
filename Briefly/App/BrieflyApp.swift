import SwiftUI

@main
struct BrieflyApp: App {
    init() {
        Self.resetStateForUITestsIfNeeded()
        Self.persistSettingsVersionDisplay()
    }

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

    private static func persistSettingsVersionDisplay() {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
        let build = info?["CFBundleVersion"] as? String

        let displayValue: String
        if let version, !version.isEmpty {
            if let build, !build.isEmpty {
                displayValue = "\(version) (\(build))"
            } else {
                displayValue = version
            }
        } else {
            displayValue = "--"
        }

        UserDefaults.standard.set(displayValue, forKey: "app_version_display")
    }

    private static func resetStateForUITestsIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestResetState") else { return }

        let defaults = UserDefaults.standard
        [
            "Briefly.completedTopicIDs",
            "Briefly.deletedTopicIDs",
            "Briefly.learnedCardIDs",
            "Briefly.completedSectionIDs",
            "Briefly.topicOrder",
            "Briefly.recentTopicIDs"
        ].forEach(defaults.removeObject(forKey:))

        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }

        let userContentURL = documents.appendingPathComponent("user_content.json")
        try? FileManager.default.removeItem(at: userContentURL)
    }
}
