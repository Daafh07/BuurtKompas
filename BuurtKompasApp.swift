//
//  BuurtKompasApp.swift
//  BuurtKompas
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *SwiftUI App Lifecycle Documentation* [Developer documentation].
//      Apple Developer. https://developer.apple.com/documentation/swiftui/app
//  Google. (2025). *Firebase iOS SDK documentation: Initialization & Setup* [Developer documentation].
//      Firebase. https://firebase.google.com/docs
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Dit bestand is geschreven door Daaf Heijnekamp (2025)
//  met ondersteuning van OpenAI ChatGPT als leermiddel.
//  Doel: Startpunt van de app + Firebase configuratie.
//

import SwiftUI
import Firebase

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

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
