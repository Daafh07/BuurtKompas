//
//  PushManager.swift
//
//  Verantwoordelijk voor:
//  - Toestemming vragen, APNs registreren
//  - (Optioneel) FCM-token bijwerken
//  - Token koppelen aan ingelogde user in Firestore (/users/{uid}/pushTokens/{token})
//

import Foundation
import UserNotifications
import FirebaseAuth
import FirebaseFirestore
import UIKit

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

final class PushManager: NSObject {

    static let shared = PushManager()
    private override init() {}

    private let center = UNUserNotificationCenter.current()
    private var currentAPNsToken: Data?
    private var currentFCMToken: String?

    // MARK: - Setup

    func configure() {
        // Eventueel: categorieën/acties registreren
    }

    @MainActor
    func ensurePermissionsAndRegister() {
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
            case .denied:
                break
            case .notDetermined:
                self.requestAuthorization()
            @unknown default:
                break
            }
        }
    }

    private func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .badge, .sound]) { granted, err in
            if let err = err { print("⚠️ Push toestemming error: \(err.localizedDescription)") }
            if granted {
                DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
            }
        }
    }

    // MARK: - Tokens

    func updateAPNsToken(_ token: Data) {
        currentAPNsToken = token
        // Als je alleen APNs gebruikt, kunnen we nu al koppelen via hex-string:
        attachTokenToUserIfNeeded()
    }

    #if canImport(FirebaseMessaging)
    fileprivate func updateFCMToken(_ token: String?) {
        currentFCMToken = token
        attachTokenToUserIfNeeded()
    }
    #endif

    // MARK: - Koppelen aan gebruiker

    func attachTokenToUserIfNeeded() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Kies voorkeur: FCM-token als die er is, anders APNs-hex
        let tokenString: String? = {
            #if canImport(FirebaseMessaging)
            if let f = currentFCMToken, !f.isEmpty { return f }
            #endif
            if let d = currentAPNsToken { return d.map { String(format: "%02x", $0) }.joined() }
            return nil
        }()

        guard let token = tokenString, !token.isEmpty else { return }

        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)
            .collection("pushTokens").document(token)

        // ❗️NIET inline #if in een literal—eerst data bouwen:
        var data: [String: Any] = [
            "token": token,
            "platform": "ios",
            "apns": currentAPNsToken != nil,
            "enabled": true,
            "createdAt": FieldValue.serverTimestamp(),
            "lastSeenAt": FieldValue.serverTimestamp()
        ]
        #if canImport(FirebaseMessaging)
        data["fcm"] = currentFCMToken ?? NSNull()
        #else
        data["fcm"] = NSNull()
        #endif

        ref.setData(data, merge: true) { err in
            if let err = err {
                print("⚠️ Token koppelen faalde: \(err.localizedDescription)")
            } else {
                print("✅ Push token gekoppeld aan user \(uid)")
            }
        }
    }

    /// Verwijder (logical disable) token onder de user bij uitloggen
    func detachTokenFromUser() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let tokenString: String? = {
            #if canImport(FirebaseMessaging)
            if let f = currentFCMToken, !f.isEmpty { return f }
            #endif
            if let d = currentAPNsToken { return d.map { String(format: "%02x", $0) }.joined() }
            return nil
        }()

        guard let token = tokenString, !token.isEmpty else { return }

        let db = Firestore.firestore()
        let ref = db.collection("users").document(uid)
            .collection("pushTokens").document(token)

        ref.setData([
            "enabled": false,
            "lastSeenAt": FieldValue.serverTimestamp()
        ], merge: true) { err in
            if let err = err {
                print("⚠️ Token loskoppelen faalde: \(err.localizedDescription)")
            } else {
                print("✅ Push token losgekoppeld van user \(uid)")
            }
        }
    }
}

#if canImport(FirebaseMessaging)
extension PushManager: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("ℹ️ FCM token: \(fcmToken ?? "-")")
        updateFCMToken(fcmToken)
    }
}
#endif
