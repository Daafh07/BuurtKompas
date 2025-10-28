//
//  ReportsMapVM.swift
//
//  Live ViewModel voor de kaart: luistert realtime naar Firestore en past filters toe.
//  - Filtert ALTIJD op de ingestelde gemeente van de ingelogde gebruiker
//  - Swift 6 proof (@MainActor, correcte Task/bridging)
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

    // Gemeente (afgeleid van user-instellingen)
    @Published var municipalityId: String?

    @Published var loading: Bool = false

    private var listener: ListenerRegistration?

    // MARK: - Lifecycle

    func start() {
        stop()
        loading = true

        // Profiel (met gemeente) ophalen op achtergrond, daarna listener aan op de MainActor
        Task { [weak self] in
            let (uid, muni): (String?, String?)
            if let u = Auth.auth().currentUser?.uid,
               let profile = try? await UserService.shared.load(uid: u) {
                uid = u
                muni = profile.municipalityId
            } else {
                uid = nil
                muni = nil
            }

            await MainActor.run {
                self?.attachListener(for: muni)
                self?.applyFilters(currentUserId: uid)
                self?.loading = false
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    /// Wordt aangeroepen wanneer de gebruiker de gemeente-instelling wijzigt.
    func restartForMunicipalityChange() {
        stop()
        loading = true

        Task { [weak self] in
            let (uid, muni): (String?, String?)
            if let u = Auth.auth().currentUser?.uid,
               let profile = try? await UserService.shared.load(uid: u) {
                uid = u
                muni = profile.municipalityId
            } else {
                uid = nil
                muni = nil
            }

            await MainActor.run {
                self?.attachListener(for: muni)
                self?.applyFilters(currentUserId: uid)
                self?.loading = false
            }
        }
    }

    // MARK: - Listener opbouwen

    private func attachListener(for muni: String?) {
        // Bewaar huidige gemeente-id
        self.municipalityId = muni

        // Eventuele oude listener verwijderen
        listener?.remove()
        listener = nil

        // ✅ Gebruik de service-listener (inclusief metadata changes + fallback sortering)
        listener = ReportService.shared.listenToReports(in: muni) { [weak self] items in
            Task { @MainActor in
                guard let self = self else { return }
                self.allReports = items
                self.applyFilters(currentUserId: Auth.auth().currentUser?.uid)
            }
        }
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
            // ALTJD binnen dezelfde gemeente blijven filteren (items is al gemeente-gefilterd door de query)
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

    // Backwards-compat (oude code riep vm.loadAll() aan)
    func loadAll() async { start() }
}
