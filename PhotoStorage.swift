//
//  PhotoStorage.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Firebase Storage for iOS – Upload files* [Developer documentation]. Firebase.
//  Apple Inc. (2025). *UIImage JPEG Encoding* [Developer documentation]. Apple Developer.
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//

import UIKit
import FirebaseStorage

final class PhotoStorage {
    static let shared = PhotoStorage()
    private let root = Storage.storage().reference()
    private init() {}

    /// Upload een JPEG (80%) en retourneert de *downloadbare* HTTPS URL (niet het storage-pad).
    func uploadReportImage(_ image: UIImage, reportId: String) async throws -> String {
        // 1) Encodeer naar JPEG (zorgt dat we .jpg ook echt hebben)
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "PhotoStorage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kon afbeelding niet naar JPEG coderen"])
        }

        // 2) Gebruik consistent pad: reports/<id>.jpg  (LET OP: dit moet gelijk zijn aan je lezende code)
        let ref = root.child("reports/\(reportId).jpg")

        // 3) Metadata (contentType) helpt clients en sommige CDN’s bij correcte behandeling
        let meta = StorageMetadata()
        meta.contentType = "image/jpeg"

        // 4) Upload
        do {
            _ = try await ref.putDataAsync(data, metadata: meta)
        } catch {
            print("⚠️ [PhotoStorage] Upload faalde: \(error.localizedDescription)")
            throw error
        }

        // 5) Download URL (HTTPS) – hiermee kan AsyncImage laden
        do {
            let url = try await ref.downloadURL()
            return url.absoluteString
        } catch {
            print("⚠️ [PhotoStorage] downloadURL faalde: \(error.localizedDescription). Bestond het object wel?")
            // Probeer 1x kort te wachten (zeldzame propagatie-lag)
            try? await Task.sleep(nanoseconds: 200_000_000)
            let url = try await ref.downloadURL()
            return url.absoluteString
        }
    }
}
