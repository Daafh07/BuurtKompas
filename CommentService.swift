// CommentService.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth

final class CommentService {
    static let shared = CommentService()
    private init() {}

    private func db() -> Firestore { Firestore.firestore() }

    // Live luisteren naar comments op één report
    func listenComments(reportId: String,
                        onChange: @escaping ([Comment]) -> Void) -> ListenerRegistration {
        db().collection("reports").document(reportId)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snap, err in
                guard let docs = snap?.documents else { return }
                let items = docs.compactMap { Comment.from(id: $0.documentID, data: $0.data()) }
                onChange(items)
            }
    }

    // Reactie plaatsen + teller verhogen
    func addComment(reportId: String, text: String, authorName: String?) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "CommentService", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Niet ingelogd"])
        }
        let id = UUID().uuidString
        let reportRef = db().collection("reports").document(reportId)
        let commentRef = reportRef.collection("comments").document(id)

        // 1) reactie schrijven
        try await commentRef.setData([
            "id": id,
            "authorId": uid,
            "authorName": authorName as Any,
            "text": text,
            "createdAt": FieldValue.serverTimestamp()
        ])

        // 2) teller +1 (mag door de aangepaste regels)
        try await reportRef.updateData([
            "commentsCount": FieldValue.increment(Int64(1)),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    // (optioneel) reactie verwijderen + teller -1
    func deleteComment(reportId: String, commentId: String, ownerId: String) async throws {
        guard let uid = Auth.auth().currentUser?.uid, uid == ownerId else {
            throw NSError(domain: "CommentService", code: -2,
                          userInfo: [NSLocalizedDescriptionKey: "Geen rechten"])
        }
        let reportRef = db().collection("reports").document(reportId)
        let commentRef = reportRef.collection("comments").document(commentId)

        try await commentRef.delete()
        try await reportRef.updateData([
            "commentsCount": FieldValue.increment(Int64(-1)),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }
}
