//
//  ReportService+Likes.swift
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

extension ReportService {

    /// Check of current user al geliked heeft.
    func hasUserLiked(reportId: String) async throws -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }
        let likeRef = Firestore.firestore()
            .collection("reports").document(reportId)
            .collection("likes").document(uid)
        let snap = try await likeRef.getDocument()
        return snap.exists
    }

    /// Toggle like zonder Firestore-transactie (simpel en compile-proof).
    /// Security rules voorkomen dubbele likes.
    @discardableResult
    func toggleLike(reportId: String, currentLiked: Bool) async throws -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return currentLiked }
        let db = Firestore.firestore()
        let reportRef = db.collection("reports").document(reportId)
        let likeRef = reportRef.collection("likes").document(uid)

        if currentLiked {
            // un-like
            try await likeRef.delete()
            try await reportRef.updateData([
                "likes": FieldValue.increment(Int64(-1)),
                "updatedAt": FieldValue.serverTimestamp()
            ])
            return false
        } else {
            // like
            try await likeRef.setData([
                "id": uid,
                "createdAt": FieldValue.serverTimestamp()
            ], merge: false)
            try await reportRef.updateData([
                "likes": FieldValue.increment(Int64(1)),
                "updatedAt": FieldValue.serverTimestamp()
            ])
            return true
        }
    }
}
