//
//  ReportService.swift
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import UIKit

final class ReportService {
    static let shared = ReportService()
    private init() {}

    /// Firestore instance vanaf de MainActor (voorkomt Swift 6 isolation errors).
    func db() async -> Firestore {
        await MainActor.run { Firestore.firestore() }
    }

    // MARK: - Create

    /// Maakt een nieuw report aan. Uploadt optionele foto, schrijft Firestore document.
    /// - Parameters:
    ///   - draft: ReportDraft met titel/omschrijving/categorie/locatie/anon.
    ///   - image: Optionele UIImage.
    ///   - overrideMunicipalityId: (Optioneel) gemeente-id die dit report MOET krijgen.
    ///     Als nil, dan pakken we de `municipalityId` van de ingelogde gebruiker (indien aanwezig).
    func createReport(
        draft: ReportDraft,
        image: UIImage?,
        overrideMunicipalityId: String? = nil
    ) async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "ReportService", code: -10,
                          userInfo: [NSLocalizedDescriptionKey: "Geen ingelogde gebruiker"])
        }

        let id = UUID().uuidString
        var photoUrl: String? = nil

        // 0) Bepaal municipalityId
        var municipalityId: String? = overrideMunicipalityId
        if municipalityId == nil {
            municipalityId = try await UserService.shared.load(uid: user.uid)?.municipalityId
        }

        // 1) Optionele foto uploaden
        if let image {
            do {
                photoUrl = try await PhotoStorage.shared.uploadReportImage(image, reportId: id)
            } catch {
                print("⚠️ [ReportService] Foto upload faalde: \(error.localizedDescription)")
            }
        }

        // 2) Firestore velden (incl. client timestamp)
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
            "createdAtClient": Timestamp(date: Date()),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let lat = draft.latitude, let lon = draft.longitude {
            fields["location"] = GeoPoint(latitude: lat, longitude: lon)
        }
        if let photoUrl { fields["photoUrl"] = photoUrl }

        // Altijd municipalityId zetten als we er één hebben (voor filtering!)
        if let municipalityId, MunicipalitiesNB.isValid(municipalityId) {
            fields["municipalityId"] = municipalityId
        }

        // 3) Schrijven
        let store = await db()
        try await store.collection("reports").document(id).setData(fields, merge: false)

        // punten toekennen (fire & forget)
        _ = try? await PointsService.shared.award(.createReport)
    }

    // MARK: - Fetch (één document)

    func fetchReportById(_ id: String) async throws -> Report? {
        let store = await db()
        let snap = try await store.collection("reports").document(id).getDocument()
        guard let data = snap.data() else { return nil }
        return Report.from(id: snap.documentID, data: data)
    }
}
