//
//  ReportsViewModel.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *SwiftUI State Management* [Developer documentation].
//      Apple Developer. https://developer.apple.com/documentation/swiftui
//  Google. (2025). *Cloud Firestore – Listen for realtime updates* [Developer documentation].
//      Firebase. https://firebase.google.com/docs/firestore/query-data/listen
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Houdt de lijst met eigen meldingen bij (realtime + pull-to-refresh).

import Foundation
import Combine   // <-- noodzakelijk voor ObservableObject/@Published

@MainActor
final class ReportsViewModel: ObservableObject {
    @Published var items: [Report] = []
    @Published var loading = false
    @Published var error: String?

    private var detach: (() -> Void)?

    func start() {
        Task {
            detach = await ReportService.shared.listenMyReports(onChange: { [weak self] reports in
                Task { @MainActor in self?.items = reports }
            }, onError: { [weak self] err in
                Task { @MainActor in self?.error = err.localizedDescription }
            })
        }
    }

    func stop() {
        detach?()
        detach = nil
    }

    func refresh() async {
        loading = true; error = nil
        do {
            let r = try await ReportService.shared.fetchMyReports()
            items = r
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
