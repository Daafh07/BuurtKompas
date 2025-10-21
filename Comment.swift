// Comment.swift
import Foundation
import FirebaseFirestore

struct Comment: Identifiable, Equatable {
    let id: String
    let authorId: String
    let authorName: String?
    let text: String
    let createdAt: Date?

    static func from(id: String, data: [String: Any]) -> Comment? {
        Comment(
            id: id,
            authorId: data["authorId"] as? String ?? "",
            authorName: data["authorName"] as? String,
            text: data["text"] as? String ?? "",
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }
}
