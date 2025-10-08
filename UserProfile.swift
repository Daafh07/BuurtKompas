//
//  UserProfile.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Cloud Firestore Data Model Documentation* [Developer documentation].
//      Firebase. https://firebase.google.com/docs/firestore
//  Apple Inc. (2025). *Swift Structs and Codable* [Developer documentation].
//      Apple Developer. https://developer.apple.com/documentation/swift/codable
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Model voor gebruikersprofielen, geschreven door Daaf Heijnekamp (2025)
//  met ondersteuning van ChatGPT.
//  Deze code volgt het Firestore-datamodel zonder gebruik van FirebaseFirestoreSwift.
//

import Foundation
import FirebaseFirestore   // nodig voor 'Timestamp' in de mapping

// Het model (bestaat echt als type)
struct UserProfile: Codable, Identifiable {
    var id: String { uid }

    let uid: String
    let email: String
    var displayName: String?
    var role: String            // "citizen" | "municipality" | "admin"
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

// Handmatige mapping zonder FirebaseFirestoreSwift
extension UserProfile {
    static func from(uid: String, data: [String: Any]) -> UserProfile? {
        let email = data["email"] as? String ?? ""
        let displayName = data["displayName"] as? String
        let role = data["role"] as? String ?? "citizen"
        let municipalityId = data["municipalityId"] as? String
        let points = data["points"] as? Int ?? 0

        // createdAt
        let createdAt: Date?
        if let ts = data["createdAt"] as? Timestamp {
            createdAt = ts.dateValue()
        } else if let dt = data["createdAt"] as? Date {
            createdAt = dt
        } else {
            createdAt = nil
        }

        // updatedAt
        let updatedAt: Date?
        if let ts = data["updatedAt"] as? Timestamp {
            updatedAt = ts.dateValue()
        } else if let dt = data["updatedAt"] as? Date {
            updatedAt = dt
        } else {
            updatedAt = nil
        }

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
