//
//  ReportService+Query.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Cloud Firestore for iOS – Query data* [Developer documentation].
//      Firebase. https://firebase.google.com/docs/firestore/query-data/queries
//  Apple Inc. (2025). *Swift Concurrency Guide* [Developer documentation].
//      Apple Developer. https://developer.apple.com/documentation/swift/concurrency
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Query-hulpen: eigen meldingen + realtime listener.

import Foundation
import FirebaseFirestore
import FirebaseAuth

extension ReportService {

    // Eénmalig ophalen (handig voor refresh)
    func fetchMyReports(limit: Int = 50) async throws -> [Report] {
        guard let uid = Auth.auth().currentUser?.uid else { return [] }
        let store = await self.db()   // <-- andere naam, en expliciet self.
        let q = store.collection("reports")
            .whereField("authorId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        let snap = try await q.getDocuments()
        return snap.documents.compactMap { Report.from(id: $0.documentID, data: $0.data()) }
    }

    // Realtime luisteren; levert een detach-closure op om te stoppen
    func listenMyReports(
        onChange: @escaping ([Report]) -> Void,
        onError: @escaping (Error) -> Void
    ) async -> () -> Void {
        guard let uid = Auth.auth().currentUser?.uid else { return {} }
        let store = await self.db()   // <-- idem
        let q = store.collection("reports")
            .whereField("authorId", isEqualTo: uid)
            .order(by: "createdAt", descending: true)

        let listener = q.addSnapshotListener { snap, err in
            if let err { onError(err); return }
            guard let snap else { onChange([]); return }
            let items = snap.documents.compactMap { Report.from(id: $0.documentID, data: $0.data()) }
            onChange(items)
        }
        return { listener.remove() }
    }
}
