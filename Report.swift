//
//  Report.swift
//

import Foundation
import FirebaseFirestore
import CoreLocation
import SwiftUI

struct Report: Identifiable {
    let id: String
    let authorId: String
    let title: String
    let description: String
    let category: String          // opgeslagen als rawValue (ReportCategory)
    let status: String
    let isAnonymous: Bool
    let likes: Int
    let commentsCount: Int
    let photoUrl: String?
    let createdAt: Date?
    let updatedAt: Date?
    let coordinate: CLLocationCoordinate2D?
    let municipalityId: String?   // ✅ NIEUW
}

extension Report {
    static func from(id: String, data: [String: Any]) -> Report? {
        let gp = data["location"] as? GeoPoint
        let coord = gp.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        return Report(
            id: id,
            authorId: data["authorId"] as? String ?? "",
            title: data["title"] as? String ?? "",
            description: data["description"] as? String ?? "",
            category: data["category"] as? String ?? ReportCategory.anders.rawValue,
            status: data["status"] as? String ?? "open",
            isAnonymous: data["isAnonymous"] as? Bool ?? true,
            likes: data["likes"] as? Int ?? 0,
            commentsCount: data["commentsCount"] as? Int ?? 0,
            photoUrl: data["photoUrl"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue(),
            coordinate: coord,
            municipalityId: data["municipalityId"] as? String // ✅ mapping
        )
    }
}

// Handige UI helpers
extension Report {
    var categoryEnum: ReportCategory { ReportCategory.from(category) }
    var categoryLabel: String { categoryEnum.label }
    var categorySymbol: String { categoryEnum.symbolName }
    var categoryColor: Color { categoryEnum.color }
    var categoryUIColor: UIColor { categoryEnum.uiColor }
}
