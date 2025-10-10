//
//  ReportService+QueryAll.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Cloud Firestore for iOS – Query data* [Developer documentation].
//      Firebase. https://firebase.google.com/docs/firestore/query-data/queries
//  Apple Inc. (2025). *Swift Concurrency Guide* [Developer documentation].
//      Apple Developer. https://developer.apple.com/documentation/swift/concurrency
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Haalt recente meldingen van iedereen op. Filters doen we client-side (MVP).
//

import Foundation
import FirebaseFirestore

extension ReportService {

    /// Haal de meest recente meldingen op (van alle gebruikers).
    /// Voor MVP filteren we client-side om gedoe met indices te vermijden.
    func fetchRecentReportsAll(limit: Int = 200) async throws -> [Report] {
        let store = await self.db()
        // Server-side sort op createdAt (DESC). Mogelijk vraagt Firestore om index; klik de "Create index" link als dat gebeurt.
        let q = store.collection("reports")
            .order(by: "createdAt", descending: true)
            .limit(to: limit)

        let snap = try await q.getDocuments()
        return snap.documents.compactMap { Report.from(id: $0.documentID, data: $0.data()) }
    }
}
