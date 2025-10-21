//  ReportService+Moderation.swift
import Foundation
import FirebaseAuth
import FirebaseFirestore

extension ReportService {

    // MARK: Status wijzigen (alleen moderators via rules)
    func moderatorUpdateStatus(reportId: String, newStatus: String) async throws {
        let store = await db()
        try await store.collection("reports")
            .document(reportId)
            .updateData([
                "status": newStatus,
                "updatedAt": FieldValue.serverTimestamp()
            ])
    }

    // MARK: Official comments CRUD (alleen moderators via rules)

    func addOfficialComment(reportId: String, text: String, pinned: Bool) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw NSError(domain: "Auth", code: -1) }
        let store = await db()
        let col = store.collection("reports").document(reportId).collection("officialComments")
        let ref = col.document()
        try await ref.setData([
            "id": ref.documentID,
            "authorId": uid,
            "text": text,
            "pinned": pinned,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ])
        // (optioneel) tik het report aan
        try? await store.collection("reports").document(reportId).updateData([
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    func deleteOfficialComment(reportId: String, commentId: String) async throws {
        let store = await db()
        try await store.collection("reports").document(reportId)
            .collection("officialComments").document(commentId).delete()
    }

    // Realtime listener (pinned eerst, daarna oudste eerst)
    func listenOfficialComments(
        reportId: String,
        onChange: @escaping ([OfficialComment]) -> Void
    ) -> ListenerRegistration {
        let store = Firestore.firestore()
        // we halen *alle* binnen en sorteren lokaal zodat pinned bovenaan staan
        return store.collection("reports").document(reportId)
            .collection("officialComments")
            .addSnapshotListener { snap, err in
                guard let docs = snap?.documents else { onChange([]); return }
                var items = docs.compactMap { OfficialComment.from(reportId: reportId, id: $0.documentID, data: $0.data()) }
                // pinned eerst, dan op createdAt oplopend
                items.sort { a, b in
                    if a.pinned != b.pinned { return a.pinned && !b.pinned }
                    let ta = a.createdAt ?? .distantPast
                    let tb = b.createdAt ?? .distantPast
                    return ta < tb
                }
                onChange(items)
            }
    }
}
