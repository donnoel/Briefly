import UIKit
import CloudKit

final class BrieflyAppDelegate: NSObject, UIApplicationDelegate {
    private static var shouldSkipCloudSetup: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestDisableCloudSync")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        guard !Self.shouldSkipCloudSetup else {
            return true
        }

        application.registerForRemoteNotifications()
        Task {
            await CloudTopicSyncService.shared.ensureChangeSubscription()
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        guard let notification = CKNotification(fromRemoteNotificationDictionary: userInfo),
              notification.subscriptionID == CloudTopicSyncService.changeSubscriptionID else {
            completionHandler(.noData)
            return
        }

        Task { @MainActor in
            let syncTask = ContentRepository.shared.refreshFromCloud()
            await syncTask?.value
            completionHandler(.newData)
        }
    }
}
