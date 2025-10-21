//
//  BuurtKompasApp.swift
//  BuurtKompas
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *SwiftUI App Lifecycle Documentation* [Developer documentation].
//  Google. (2025). *Firebase iOS SDK documentation: Initialization & Setup* [Developer documentation].
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//  --
//  Startpunt van de app + Firebase + Push setup.
//

import SwiftUI
import Firebase
import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

@main
struct BuurtKompasApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var session = SessionViewModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        // Notificaties delegateren (zodat we foreground alerts kunnen tonen)
        UNUserNotificationCenter.current().delegate = self

        // Push configureren + registreren
        PushManager.shared.configure()
        PushManager.shared.ensurePermissionsAndRegister()

        #if canImport(FirebaseMessaging)
        // FCM delegate
        Messaging.messaging().delegate = PushManager.shared
        #endif

        return true
    }

    // APNs device token → (optioneel) doorzetten naar FCM
    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        #if canImport(FirebaseMessaging)
        Messaging.messaging().apnsToken = deviceToken
        #endif
        PushManager.shared.updateAPNsToken(deviceToken)
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("⚠️ APNs-registratie faalde: \(error.localizedDescription)")
    }

    // Notificaties in de voorgrond laten zien (banner/geluid/badge)
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // Optioneel: verwerken van tap op notificatie
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        // TODO: deep-linken naar een specifieke melding op basis van userInfo
        completionHandler()
    }
}
