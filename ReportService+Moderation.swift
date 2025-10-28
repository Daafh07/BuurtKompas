//
//  ReportService+Moderation.swift
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

extension ReportService {

    static let allowedStatuses: Set<String> = ["open", "in_progress", "resolved", "need_info"]

    func updateStatus(reportId: String, newStatus: String) async throws {
        guard Self.allowedStatuses.contains(newStatus) else { return }
        let db = Firestore.firestore()
        let ref = db.collection("reports").document(reportId)

        try await ref.updateData([
            "status": newStatus,
            "updatedAt": FieldValue.serverTimestamp()
        ])

        // notificatie sturen naar eigenaar (als niet jezelf)
        if let snap = try? await ref.getDocument(),
           let authorId = snap.data()?["authorId"] as? String,
           let me = Auth.auth().currentUser?.uid,
           authorId != me {
            let noteRef = db.collection("users").document(authorId)
                .collection("notifications").document()
            try? await noteRef.setData([
                "id": noteRef.documentID,
                "title": "Status gewijzigd",
                "message": "De status van je melding is aangepast naar '\(newStatus)'.",
                "reportId": reportId,
                "read": false,
                "createdAt": FieldValue.serverTimestamp()
            ])
        }
    }
}
