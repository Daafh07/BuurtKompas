//
//  ReportService+Likes.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Cloud Firestore – iOS SDK* [Developer documentation]. Firebase.
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//
//  Simpele per-user likes:
//  - Eén like per gebruiker via subdocument /reports/{reportId}/likes/{uid}
//  - Teller op het reportdocument wordt direct geüpdatet (zonder Cloud Functions)
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

extension ReportService {

    /// Geeft terug of de huidig ingelogde gebruiker dit report al geliked heeft.
    func hasUserLiked(reportId: String) async throws -> Bool {
        guard let user = Auth.auth().currentUser else { return false }
        let store = await db()
        let likeRef = store.collection("reports")
            .document(reportId)
            .collection("likes")
            .document(user.uid)

        let snap = try await likeRef.getDocument()
        return snap.exists
    }

    /// Wisselt de like-status en houdt de teller bij. Retourneert nieuwe status.
    func toggleLike(reportId: String, currentLiked: Bool) async throws -> Bool {
        guard let user = Auth.auth().currentUser else { return currentLiked }

        let store = await db()
        let reportRef = store.collection("reports").document(reportId)
        let likeRef   = reportRef.collection("likes").document(user.uid)

        if currentLiked {
            // UNLIKE
            try await likeRef.delete()
            try await reportRef.updateData([
                "likes": FieldValue.increment(Int64(-1)),
                "updatedAt": FieldValue.serverTimestamp()
            ])
            return false
        } else {
            // LIKE (alleen aanmaken als nog niet bestaat)
            let exists = try await likeRef.getDocument().exists
            if !exists {
                try await likeRef.setData([
                    "createdAt": FieldValue.serverTimestamp(),
                    "userId": user.uid
                ])
                try await reportRef.updateData([
                    "likes": FieldValue.increment(Int64(1)),
                    "updatedAt": FieldValue.serverTimestamp()
                ])

                // ✅ punten voor EERSTE like (unused-result fix)
                _ = try? await PointsService.shared.award(.likeReport)
            }
            return true
        }
    }
}
