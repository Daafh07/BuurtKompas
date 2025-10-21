//
//  NotificationsService.swift
//  BuurtKompas
//
//  Lees/luister op users/{uid}/notifications + helperacties.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

struct AppNotification: Identifiable, Equatable {
    let id: String
    let type: String           // "status_changed" | "official_comment" | ...
    let title: String
    let body: String
    let reportId: String?
    let createdAt: Date?
    var read: Bool

    static func from(id: String, data: [String: Any]) -> AppNotification {
        AppNotification(
            id: id,
            type: data["type"] as? String ?? "generic",
            title: data["title"] as? String ?? "",
            body: data["body"] as? String ?? "",
            reportId: data["reportId"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            read: data["read"] as? Bool ?? false
        )
    }
}

final class NotificationsService {
    static let shared = NotificationsService()
    private init() {}

    private func db() -> Firestore { Firestore.firestore() }

    /// Live luisteren naar inbox. Sorteer op meest recent bovenaan.
    func listenInbox(for uid: String, onChange: @escaping ([AppNotification]) -> Void) -> ListenerRegistration {
        return db().collection("users").document(uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snap, err in
                guard let docs = snap?.documents else {
                    print("⚠️ Inbox listen error:", err?.localizedDescription ?? "onbekend")
                    onChange([])
                    return
                }
                let items = docs.map { AppNotification.from(id: $0.documentID, data: $0.data()) }
                onChange(items)
            }
    }

    /// Markeer 1 item als gelezen.
    func markRead(noteId: String, for uid: String) async throws {
        try await db().collection("users").document(uid)
            .collection("notifications").document(noteId)
            .updateData([
                "read": true
            ])
    }

    /// Verwijder 1 item.
    func delete(noteId: String, for uid: String) async throws {
        try await db().collection("users").document(uid)
            .collection("notifications").document(noteId)
            .delete()
    }

    /// Markeer alles als gelezen (batch).
    func markAllRead(for uid: String) async throws {
        let snap = try await db().collection("users").document(uid)
            .collection("notifications").getDocuments()

        let batch = db().batch()
        for d in snap.documents {
            batch.updateData(["read": true], forDocument: d.reference)
        }
        try await batch.commit()
    }

    /// Verwijder alles (optioneel).
    func clearAll(for uid: String) async throws {
        let snap = try await db().collection("users").document(uid)
            .collection("notifications").getDocuments()

        let batch = db().batch()
        for d in snap.documents { batch.deleteDocument(d.reference) }
        try await batch.commit()
    }
}
