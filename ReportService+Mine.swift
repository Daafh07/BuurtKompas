//
//  ReportService+Mine.swift
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

extension ReportService {

    /// Realtime luisteren naar alleen mijn meldingen (alle gemeenten).
    /// Retourneert een detach-closure die je kunt aanroepen in `stop()`.
    func listenMyReports(
        onChange: @escaping ([Report]) -> Void,
        onError: @escaping (Error) -> Void
    ) async -> (() -> Void) {

        guard let uid = Auth.auth().currentUser?.uid else {
            // Geen user → leeg resultaat en no-op detach
            onChange([])
            return { }
        }

        var query: Query = Firestore.firestore()
            .collection("reports")
            .whereField("authorId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)

        // Realtime listener met metadata (zodat local writes meteen zichtbaar zijn).
        let listener = query.addSnapshotListener(includeMetadataChanges: true) { snapshot, error in
            if let error { onError(error); return }
            guard let docs = snapshot?.documents else { onChange([]); return }

            var items = docs.compactMap { Report.from(id: $0.documentID, data: $0.data()) }

            // Fallback sort op clienttimestamp zolang server 'createdAt' nog nil kan zijn
            items.sort { a, b in
                let da = a.createdAt ?? a.createdAtClient ?? .distantPast
                let db = b.createdAt ?? b.createdAtClient ?? .distantPast
                return da > db
            }
            onChange(items)
        }

        // Detach closure teruggeven
        return { listener.remove() }
    }

    /// Eénmalig fetchen van mijn meldingen.
    func fetchMyReports() async throws -> [Report] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }

        let snap = try await Firestore.firestore()
            .collection("reports")
            .whereField("authorId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        var items = snap.documents.compactMap { Report.from(id: $0.documentID, data: $0.data()) }

        // Zelfde fallback sort als realtime
        items.sort { a, b in
            let da = a.createdAt ?? a.createdAtClient ?? .distantPast
            let db = b.createdAt ?? b.createdAtClient ?? .distantPast
            return da > db
        }
        return items
    }
}
