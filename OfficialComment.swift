//  OfficialComment.swift
import Foundation
import FirebaseFirestore

struct OfficialComment: Identifiable {
    let id: String
    let reportId: String
    let authorId: String
    let text: String
    let pinned: Bool
    let createdAt: Date?
    let updatedAt: Date?

    static func from(reportId: String, id: String, data: [String: Any]) -> OfficialComment? {
        guard let authorId = data["authorId"] as? String,
              let text = data["text"] as? String else { return nil }
        return OfficialComment(
            id: id,
            reportId: reportId,
            authorId: authorId,
            text: text,
            pinned: data["pinned"] as? Bool ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }
}
