//
//  ReportService+Mutations.swift
//

import Foundation
import FirebaseFirestore

extension ReportService {

    /// Verwijdert report + eenvoudige cleanup van subcollecties (likes/comments).
    /// (Voor echte cascade: Cloud Function/Extension is mooier, maar dit werkt prima.)
    func deleteReport(reportId: String) async throws {
        let db = Firestore.firestore()
        let reportRef = db.collection("reports").document(reportId)

        // eigenaar voor notificatie:
        var authorId: String?
        if let snap = try? await reportRef.getDocument() {
            authorId = snap.data()?["authorId"] as? String
        }

        // Subcollecties opruimen (best-effort)
        let likesRef = reportRef.collection("likes")
        let commentsRef = reportRef.collection("comments")

        if let likeDocs = try? await likesRef.getDocuments() {
            for d in likeDocs.documents {
                try? await d.reference.delete()
            }
        }
        if let commentDocs = try? await commentsRef.getDocuments() {
            for d in commentDocs.documents {
                try? await d.reference.delete()
            }
        }

        // Hoofddoc weg
        try await reportRef.delete()

        // Notificatie naar eigenaar
        if let authorId {
            let noteRef = db.collection("users").document(authorId)
                .collection("notifications").document()
            try? await noteRef.setData([
                "id": noteRef.documentID,
                "title": "Melding verwijderd",
                "message": "Je melding is verwijderd door een moderator.",
                "reportId": reportId,
                "read": false,
                "createdAt": FieldValue.serverTimestamp()
            ])
        }
    }
}
