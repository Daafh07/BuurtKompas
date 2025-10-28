//
//  ReportsViewModel.swift
//

import Foundation
import Combine

@MainActor
final class ReportsViewModel: ObservableObject {
    @Published var items: [Report] = []
    @Published var loading = false
    @Published var error: String?

    private var detach: (() -> Void)?

    func start() {
        Task {
            self.detach = await ReportService.shared.listenMyReports(
                onChange: { [weak self] reports in
                    guard let self = self else { return }
                    self.items = reports
                },
                onError: { [weak self] (err: Error) in   // ✅ type-annotatie toegevoegd
                    guard let self = self else { return }
                    self.error = err.localizedDescription
                }
            )
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
