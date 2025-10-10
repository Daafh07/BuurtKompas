//
//  ReportService.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Cloud Firestore for iOS – Add & update data* [Developer documentation]. Firebase.
//  Apple Inc. (2025). *Swift Concurrency Guide* [Developer documentation]. Apple Developer.
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//  --
//  Centrale service voor meldingen (FireStore + helper utilities).
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import UIKit

final class ReportService {
    static let shared = ReportService()
    private init() {}

    /// Geeft de Firestore instance terug vanaf de MainActor (veilig voor Swift 6).
    func db() async -> Firestore {
        await MainActor.run { Firestore.firestore() }
    }

    /// Maakt een nieuw report aan. Uploadt optionele foto, schrijft Firestore document.
    /// LET OP: `PhotoStorage` moet bestaan met uploadReportImage(_:reportId:).
    func createReport(draft: ReportDraft, image: UIImage?) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "ReportService", code: -10,
                          userInfo: [NSLocalizedDescriptionKey: "Geen ingelogde gebruiker"])
        }

        // Genereer ID vooraf zodat Storage-pad en document overeenkomen
        let id = UUID().uuidString
        var photoUrl: String? = nil

        // 1) Foto (optioneel) uploaden
        if let image {
            do {
                photoUrl = try await PhotoStorage.shared.uploadReportImage(image, reportId: id)
                print("✅ [ReportService] Foto geüpload: \(photoUrl ?? "-")")
            } catch {
                print("⚠️ [ReportService] Foto upload faalde: \(error.localizedDescription)")
                // throw error  // eventueel afbreken i.p.v. doorgaan zonder foto
            }
        }

        // 2) Velden opbouwen
        var fields: [String: Any] = [
            "id": id,
            "authorId": user.uid,
            "title": draft.title,
            "description": draft.description,
            "category": draft.category,
            "status": "open",
            "isAnonymous": draft.isAnonymous,
            "likes": 0,
            "commentsCount": 0,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let lat = draft.latitude, let lon = draft.longitude {
            fields["location"] = GeoPoint(latitude: lat, longitude: lon)
        }
        if let photoUrl { fields["photoUrl"] = photoUrl }

        // 3) Schrijven
        let store = await db()
        let ref = store.collection("reports").document(id)
        try await ref.setData(fields, merge: false)

        // ✅ punten voor melding plaatsen (unused-result fix)
        _ = try? await PointsService.shared.award(.createReport)

        print("✅ [ReportService] Report aangemaakt \(id) (foto: \(photoUrl != nil ? "JA" : "NEE"))")
    }
}

// MARK: - Realtime listener op alle meldingen
extension ReportService {
    /// Luistert live naar alle meldingen (gesorteerd op createdAt desc).
    /// Roept `onChange` aan met de nieuwste lijst `Report`.
    /// Let op: verwijder de listener met `.remove()` wanneer je View verdwijnt.
    func listenToReports(onChange: @escaping ([Report]) -> Void) -> ListenerRegistration {
        let store = Firestore.firestore()

        return store.collection("reports")
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let docs = snapshot?.documents else {
                    print("⚠️ [ReportService] Live-listener fout:",
                          error?.localizedDescription ?? "onbekend")
                    return
                }

                // Gebruik jouw eigen mapper i.p.v. `$0.data(as:)`
                let items: [Report] = docs.compactMap {
                    Report.from(id: $0.documentID, data: $0.data())
                }

                onChange(items)
            }
    }
}
