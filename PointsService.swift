//
//  PointsService.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Cloud Firestore – Update data* [Developer documentation]. Firebase.
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum RewardAction: String {
    case createReport   // melding geplaatst
    case likeReport     // eerste like op een report
}

final class PointsService {
    static let shared = PointsService()
    private init() {}

    /// Punten per actie
    private let pointsTable: [RewardAction: Int] = [
        .createReport: 10,
        .likeReport:   1
    ]

    /// Verhoog de punten van de huidige gebruiker.
    @discardableResult
    func award(_ action: RewardAction) async throws -> Int {
        guard let uid = Auth.auth().currentUser?.uid else { return 0 }
        let value = pointsTable[action] ?? 0
        guard value != 0 else { return 0 }

        let db = Firestore.firestore()
        let userRef = db.collection("users").document(uid)

        // Als het users-doc nog niet bestaat, maak het dan aan met points=0
        let snap = try await userRef.getDocument()
        if !snap.exists {
            try await userRef.setData([
                "id": uid,
                "email": Auth.auth().currentUser?.email ?? "",
                "role": "citizen",
                "points": 0,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: false)
        }

        try await userRef.updateData([
            "points": FieldValue.increment(Int64(value)),
            "updatedAt": FieldValue.serverTimestamp()
        ])

        return value
    }
}
