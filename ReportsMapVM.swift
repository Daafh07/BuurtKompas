//
//  ReportsMapVM.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Cloud Firestore – Realtime listeners (iOS)* [Developer documentation]. Firebase.
//  Apple Inc. (2025). *Swift Concurrency & MainActor* [Developer documentation]. Apple Developer.
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//
//  Live ViewModel voor de kaart: luistert realtime naar Firestore en past filters toe.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore
import Combine

@MainActor
final class ReportsMapVM: ObservableObject {

    // Gehele dataset en gefilterde set voor de kaart
    @Published var allReports: [Report] = []
    @Published var filtered: [Report] = []

    // Filters
    @Published var selectedCategories: Set<String> = []
    @Published var selectedStatuses: Set<String> = []
    @Published var onlyMine: Bool = false

    @Published var loading: Bool = false

    private var listener: ListenerRegistration?

    // MARK: - Live luisteren
    func start() {
        stop()
        loading = true

        listener = ReportService.shared.listenToReports { [weak self] reports in
            Task { @MainActor in
                guard let self else { return }
                self.allReports = reports
                self.applyFilters(currentUserId: Auth.auth().currentUser?.uid)
                self.loading = false
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    // Backwards-compat (je riep eerder loadAll() aan)
    func loadAll() async {
        start()
    }

    // MARK: - Filters
    func applyFilters(currentUserId: String?) {
        var items = allReports

        if !selectedCategories.isEmpty {
            items = items.filter { selectedCategories.contains($0.category) }
        }
        if !selectedStatuses.isEmpty {
            items = items.filter { selectedStatuses.contains($0.status) }
        }
        if onlyMine, let uid = currentUserId {
            items = items.filter { $0.authorId == uid }
        }

        filtered = items
    }

    func toggleCategory(_ c: String) {
        if selectedCategories.contains(c) { selectedCategories.remove(c) }
        else { selectedCategories.insert(c) }
        applyFilters(currentUserId: Auth.auth().currentUser?.uid)
    }

    func toggleStatus(_ s: String) {
        if selectedStatuses.contains(s) { selectedStatuses.remove(s) }
        else { selectedStatuses.insert(s) }
        applyFilters(currentUserId: Auth.auth().currentUser?.uid)
    }

    func clearFilters() {
        selectedCategories.removeAll()
        selectedStatuses.removeAll()
        onlyMine = false
        applyFilters(currentUserId: Auth.auth().currentUser?.uid)
    }
}
