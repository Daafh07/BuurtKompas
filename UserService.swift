//
//  UserService.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Cloud Firestore for iOS – Asynchronous Calls* [Developer documentation].
//      Firebase. https://firebase.google.com/docs/firestore
//  Apple Inc. (2025). *Swift Concurrency Guide* [Developer documentation].
//      Apple Developer. https://developer.apple.com/documentation/swift/concurrency
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Code ontwikkeld door Daaf Heijnekamp (2025) voor de BuurtKompas-app,
//  gebaseerd op Firebase Firestore documentatie en Swift concurrency voorbeelden.
//

import Foundation
import FirebaseFirestore

/// Swift 6-vriendelijk: geen 'actor', maar een gewone class.
/// We halen Firestore altijd via de MainActor op (zie db()).
final class UserService {
    static let shared = UserService()
    private init() {}

    // MARK: - Firestore helper (MainActor)
    private func db() async -> Firestore {
        await MainActor.run { FirebaseFirestore.Firestore.firestore() }
    }

    // MARK: - Load (met zelfherstel van ontbrekende velden)
    /// Laadt het userprofiel. Als `points` ontbreekt, wordt dit veld automatisch gezet op 0.
    func load(uid: String) async throws -> UserProfile? {
        let db = await db()
        let ref = db.collection("users").document(uid)
        let snap = try await ref.getDocument()
        guard var data = snap.data() else { return nil }

        // Zelfherstel: points moet bestaan en een Int zijn
        var needsPatch = false
        if data["points"] as? Int == nil {
            data["points"] = 0
            needsPatch = true
        }

        // Optionele velden consistent houden (kan handig zijn voor UI)
        if data["role"] as? String == nil {
            data["role"] = "citizen"
            needsPatch = true
        }

        if needsPatch {
            // Patch het document non-blocking (UI hoeft hier niet op te wachten)
            Task.detached {
                do {
                    try await ref.updateData([
                        "points": data["points"] as! Int,
                        "role": data["role"] as! String,
                        "updatedAt": FieldValue.serverTimestamp()
                    ])
                } catch {
                    print("⚠️ [UserService] Kon ontbrekende velden niet patchen: \(error.localizedDescription)")
                }
            }
        }

        return UserProfile.from(uid: uid, data: data)
    }

    // MARK: - Create if needed
    /// Maakt een userdocument aan als het nog niet bestaat, met `points: 0`.
    func createIfNeeded(uid: String, email: String) async throws -> UserProfile {
        if let existing = try await load(uid: uid) { return existing }

        let db = await db()
        let ref = db.collection("users").document(uid)

        let fields: [String: Any] = [
            "uid": uid,
            "email": email,
            "displayName": NSNull(),     // optioneel veld
            "role": "citizen",
            "municipalityId": NSNull(),  // optioneel veld
            "points": 0,                 // ✅ startwaarde punten
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await ref.setData(fields, merge: true)

        // Lokale representatie (server timestamps komen pas bij volgende read binnen)
        return UserProfile(
            uid: uid,
            email: email,
            displayName: nil,
            role: "citizen",
            municipalityId: nil,
            points: 0,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    // MARK: - Touch updatedAt (handig bij profielwijzigingen)
    func touchUpdatedAt(uid: String) async throws {
        let db = await db()
        try await db.collection("users").document(uid)
            .updateData(["updatedAt": FieldValue.serverTimestamp()])
    }
}
