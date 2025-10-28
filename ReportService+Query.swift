//
//  ReportService+Query.swift
//

import Foundation
import FirebaseFirestore

extension ReportService {
    /// Luister naar meldingen binnen een gemeente. Als `municipalityId == nil` → alle meldingen.
    /// Gebruikt includeMetadataChanges + fallback sort op createdAtClient voor snelle lokale weergave.
    func listenToReports(
        in municipalityId: String?,
        onChange: @escaping ([Report]) -> Void
    ) -> ListenerRegistration {
        var query: Query = Firestore.firestore().collection("reports")
        if let municipalityId, !municipalityId.isEmpty {
            query = query.whereField("municipalityId", isEqualTo: municipalityId)
        }
        query = query.order(by: "createdAt", descending: true)

        return query.addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
            guard let docs = snapshot?.documents else {
                print("⚠️ [ReportService] Live-listener fout:", error?.localizedDescription ?? "onbekend")
                onChange([])
                return
            }

            var items: [Report] = docs.compactMap { Report.from(id: $0.documentID, data: $0.data()) }

            // Fallback sortering terwijl server 'createdAt' nog nil kan zijn
            items.sort { a, b in
                let da = a.createdAt ?? a.createdAtClient ?? .distantPast
                let db = b.createdAt ?? b.createdAtClient ?? .distantPast
                return da > db
            }

            onChange(items)
        }
    }
}
