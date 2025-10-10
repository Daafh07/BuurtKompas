//
//  ReportService+Mutations.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Cloud Firestore – Update data & transactions* [Developer documentation]. Firebase. https://firebase.google.com/docs/firestore/manage-data/add-data
//  Apple Inc. (2025). *Swift Concurrency Guide* [Developer documentation]. Apple Developer. https://developer.apple.com/documentation/swift/concurrency
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Mutaties voor meldingen: like, status bijwerken, velden bijwerken en verwijderen.
//

import Foundation
import FirebaseFirestore

extension ReportService {

    /// Verhoog/ verlaag likes. `increment = 1` voor like, `-1` voor unlike.
    func like(reportId: String, increment: Int = 1) async throws {
        let store = await db()
        let ref = store.collection("reports").document(reportId)
        try await ref.updateData([
            "likes": FieldValue.increment(Int64(increment)),
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Werk de status bij (bijv. "open", "in_progress", "resolved", "need_info").
    func updateStatus(reportId: String, status: String) async throws {
        let store = await db()
        let ref = store.collection("reports").document(reportId)
        try await ref.updateData([
            "status": status,
            "updatedAt": FieldValue.serverTimestamp()
        ])
    }

    /// Selectief velden bijwerken. Laat je `nil`, dan blijft bestaand veld staan.
    func updateReport(
        reportId: String,
        title: String? = nil,
        description: String? = nil,
        category: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil
    ) async throws {
        var patch: [String: Any] = [:]
        if let title { patch["title"] = title }
        if let description { patch["description"] = description }
        if let category { patch["category"] = category }
        if let lat = latitude, let lon = longitude {
            patch["location"] = GeoPoint(latitude: lat, longitude: lon)
        }
        patch["updatedAt"] = FieldValue.serverTimestamp()

        let store = await db()
        let ref = store.collection("reports").document(reportId)
        try await ref.updateData(patch)
    }

    /// Verwijder een melding (en optioneel kun je elders ook de foto uit Storage verwijderen).
    func deleteReport(reportId: String) async throws {
        let store = await db()
        try await store.collection("reports").document(reportId).delete()
        // Optioneel: verwijder gekoppelde foto uit Storage als je de bestandsnaam kent (reports/<id>.jpg).
        // let _ = try? await PhotoStorage.shared.deleteReportImage(reportId: reportId)
    }
}
