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
