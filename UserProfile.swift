//
//  UserProfile.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). Cloud Firestore Data Model Documentation [Developer documentation]. Firebase.
//  Apple Inc. (2025). Swift Structs and Codable [Developer documentation]. Apple Developer.
//  OpenAI. (2025). ChatGPT (GPT-5) [Large language model]. OpenAI.
//
//  Model voor gebruikersprofielen (zonder FirebaseFirestoreSwift).
//

import Foundation
import FirebaseFirestore // voor Timestamp

struct UserProfile: Codable, Identifiable {
    var id: String { uid }

    let uid: String
    let email: String
    var displayName: String?
    /// Rollen: "citizen" | "municipality" | "moderator" | "admin"
    var role: String
    var municipalityId: String?
    var points: Int
    var createdAt: Date?
    var updatedAt: Date?

    static func `default`(uid: String, email: String) -> UserProfile {
        .init(
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
}

// Handmatige mapping (zonder @DocumentID / @ServerTimestamp)
extension UserProfile {
    static func from(uid: String, data: [String: Any]) -> UserProfile? {
        let email = data["email"] as? String ?? ""
        let displayName = data["displayName"] as? String
        let role = data["role"] as? String ?? "citizen"
        let municipalityId = data["municipalityId"] as? String
        let points = data["points"] as? Int ?? 0

        let createdAt: Date? = (data["createdAt"] as? Timestamp)?.dateValue()
        let updatedAt: Date? = (data["updatedAt"] as? Timestamp)?.dateValue()

        return UserProfile(
            uid: uid,
            email: email,
            displayName: displayName,
            role: role,
            municipalityId: municipalityId,
            points: points,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}
