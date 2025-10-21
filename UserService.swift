//
//  UserService.swift
//
//  Service voor user-profielen (Swift 6 friendly).
//

import Foundation
import FirebaseFirestore

final class UserService {
    static let shared = UserService()
    private init() {}

    // MARK: Firestore helper (MainActor om isolation-warnings te voorkomen)
    fileprivate func db() async -> Firestore {
        await MainActor.run { Firestore.firestore() }
    }

    // MARK: Load met zelfherstel van ontbrekende velden
    func load(uid: String) async throws -> UserProfile? {
        let db = await db()
        let ref = db.collection("users").document(uid)
        let snap = try await ref.getDocument()
        guard var data = snap.data() else { return nil }

        var needsPatch = false
        if data["points"] as? Int == nil { data["points"] = 0; needsPatch = true }
        if data["role"] as? String == nil { data["role"] = "citizen"; needsPatch = true }

        if needsPatch {
            Task.detached {
                do {
                    try await ref.updateData([
                        "points": data["points"] as! Int,
                        "role": data["role"] as! String,
                        "updatedAt": FieldValue.serverTimestamp()
                    ])
                } catch {
                    print("⚠️ [UserService] Patch ontbrekende velden faalde: \(error.localizedDescription)")
                }
            }
        }

        return UserProfile.from(uid: uid, data: data)
    }

    // MARK: Create if needed
    func createIfNeeded(uid: String, email: String) async throws -> UserProfile {
        if let existing = try await load(uid: uid) { return existing }

        let db = await db()
        let ref = db.collection("users").document(uid)

        let fields: [String: Any] = [
            "uid": uid,
            "email": email,
            "displayName": NSNull(),
            "role": "citizen",
            "municipalityId": NSNull(),
            "points": 0,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await ref.setData(fields, merge: true)

        return UserProfile.default(uid: uid, email: email)
    }

    // Handig bij profielupdates
    func touchUpdatedAt(uid: String) async throws {
        let db = await db()
        try await db.collection("users").document(uid)
            .updateData(["updatedAt": FieldValue.serverTimestamp()])
    }
}

// MARK: - Municipality updates
extension UserService {
    /// Slaat de gekozen gemeente (of geen) op in users/{uid}.municipalityId
    /// - Parameter municipalityId: gebruik `nil` of "" om te verwijderen.
    func updateMunicipality(uid: String, municipalityId: String?) async throws {
        let db = await db()
        var payload: [String: Any] = [
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if let muni = municipalityId, !muni.isEmpty {
            payload["municipalityId"] = muni
        } else {
            payload["municipalityId"] = FieldValue.delete()
        }
        try await db.collection("users").document(uid).updateData(payload)

        // Laat de app weten dat de gemeente is aangepast (voor live refresh van listeners)
        NotificationCenter.default.post(name: .userMunicipalityDidChange, object: nil)
    }
}

// MARK: - Notification helper
extension Notification.Name {
    static let userMunicipalityDidChange = Notification.Name("UserMunicipalityDidChange")
}
