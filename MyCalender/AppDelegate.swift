import FirebaseAppCheck
import FirebaseCore
import UIKit
import UserNotifications

extension AppDelegate {
    static func registerDefaultUserDefaults() {
        UserDefaults.standard.register(defaults: [
            Constants.appStorageDailyScheduleNotificationEnabled: true
        ])
    }
}

final class MyAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
            return AppCheckDebugProvider(app: app)
        #else
            if #available(iOS 14.0, *) {
                return AppAttestProvider(app: app)
            } else {
                return DeviceCheckProvider(app: app)
            }
        #endif
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Self.registerDefaultUserDefaults()
        UNUserNotificationCenter.current().delegate = self
        let providerFactory = MyAppCheckProviderFactory()
        AppCheck.setAppCheckProviderFactory(providerFactory)
        FirebaseApp.configure()
        return true
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    /// アプリがフォアグラウンドでもバナー・音で通知する
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge, .list])
    }
}
