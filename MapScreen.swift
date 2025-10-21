//
//  MapScreen.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). MapKit (SwiftUI interop) [Developer documentation]. Apple Developer.
//  Apple Inc. (2025). SwiftUI Views and Controls [Developer documentation]. Apple Developer.
//  Google. (2025). Cloud Firestore – Query data [Developer documentation]. Firebase.
//  OpenAI. (2025). ChatGPT (GPT-5) [Large language model]. OpenAI.
//
//  Kaart toont altijd pins; heatmap/density is een visuele filter erboven.
//  Kaart filtert ALTIJD op de gekozen gemeente-instelling van de gebruiker.
//

import SwiftUI
import MapKit
import FirebaseAuth
import Combine

struct MapScreen: View {
    @StateObject private var vm = ReportsMapVM()
    @State private var selectedReport: Report? = nil

    // Heatmap aan/uit + legenda
    @State private var showHeatmap: Bool = false
    @State private var showLegend: Bool = true

    private let categories = ReportCategory.allCases
    private let statuses   = ["open", "in_progress", "resolved", "need_info"]

    var body: some View {
        ZStack(alignment: .top) {
            AppBackground()

            // ÉÉN kaart: pins + (optioneel) density overlay
            MapWithHeatView(
                items: vm.filtered.compactMap { r in
                    guard let c = r.coordinate else { return nil }
                    return MapWithHeatView.Item(
                        reportId: r.id,
                        coordinate: c,
                        weight: max(1, r.likes + 1),   // altijd zichtbaar
                        category: r.category
                    )
                },
                showHeat: showHeatmap,
                baseRadiusMeters: 260,
                neighborhoodMeters: 320,
                initialRegion: defaultRegion()
            ) { tappedId in
                // Klik op pin → open detail
                if let found = vm.filtered.first(where: { $0.id == tappedId }) {
                    selectedReport = found
                }
            }
            .ignoresSafeArea(edges: .bottom)

            // Legenda rechtsonder
            if showHeatmap && showLegend {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        HeatmapLegend()
                            .padding(.trailing, 8)
                            .padding(.bottom, 8)
                    }
                }
                .allowsHitTesting(false)
            }

            // Filterbalk
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Heatmap").font(.headline)
                        Spacer()
                        Toggle("Heatmap", isOn: $showHeatmap)
                            .toggleStyle(.switch)
                            .labelsHidden()

                        if vm.loading { ProgressView().controlSize(.small) }

                        Button {
                            vm.restartForMunicipalityChange()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .foregroundStyle(AppColors.primaryBlue)
                    }

                    // Categorie-chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(categories, id: \.self) { cat in
                                FilterChip(
                                    title: cat.label,
                                    systemImage: cat.symbolName,
                                    tint: cat.color,
                                    active: vm.selectedCategories.contains(cat.rawValue)
                                ) { vm.toggleCategory(cat.rawValue) }
                            }
                        }
                    }

                    // Status-chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(statuses, id: \.self) { st in
                                FilterChip(
                                    title: statusLabel(st),
                                    systemImage: iconForStatus(st),
                                    tint: tintForStatus(st),
                                    active: vm.selectedStatuses.contains(st)
                                ) { vm.toggleStatus(st) }
                            }
                        }
                    }

                    // Extra filters
                    HStack {
                        Toggle("Alleen mijn meldingen", isOn: Binding(
                            get: { vm.onlyMine },
                            set: { newVal in
                                vm.onlyMine = newVal
                                vm.applyFilters(currentUserId: Auth.auth().currentUser?.uid)
                            })
                        )
                        .toggleStyle(.switch)

                        Spacer()

                        if showHeatmap {
                            Button("Legenda \(showLegend ? "verbergen" : "tonen")") {
                                withAnimation(.easeInOut) { showLegend.toggle() }
                            }
                        }

                        Button("Wis filters") { vm.clearFilters() }
                            .foregroundStyle(.secondary)
                    }

                    Text("Toont \(vm.filtered.count) meldingen in je gemeente")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
        // Start/stop de listener zodra de view zichtbaar is
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        // Kaart opnieuw laden bij gemeentewijziging
        .onReceive(NotificationCenter.default.publisher(for: .municipalityDidChange)) { _ in
            vm.restartForMunicipalityChange()
        }
        .sheet(item: $selectedReport) { report in
            ReportDetailSheet(report: report)
        }
    }

    // MARK: - Helpers

    private func defaultRegion() -> MKCoordinateRegion? {
        if let first = vm.filtered.first, let coord = first.coordinate {
            return MKCoordinateRegion(center: coord,
                                      span: .init(latitudeDelta: 0.15, longitudeDelta: 0.15))
        }
        return nil
    }

    private func statusLabel(_ s: String) -> String {
        switch s {
        case "open": return "Open"
        case "in_progress": return "In behandeling"
        case "resolved": return "Opgelost"
        case "need_info": return "Meer info"
        default: return s
        }
    }

    private func iconForStatus(_ s: String) -> String {
        switch s {
        case "resolved": return "checkmark.seal.fill"
        case "in_progress": return "clock.fill"
        case "need_info": return "questionmark.circle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }

    private func tintForStatus(_ s: String) -> Color {
        switch s {
        case "resolved": return .green
        case "in_progress": return .orange
        case "need_info": return .pink
        default: return AppColors.primaryBlue
        }
    }
}

// MARK: - FilterChip component
private struct FilterChip: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color? = nil
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage { Image(systemName: systemImage) }
                Text(title)
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background((tint ?? AppColors.primaryBlue).opacity(active ? 0.9 : 0.18))
            .foregroundStyle(active ? .white : AppColors.darkText)
            .cornerRadius(999)
        }
        .buttonStyle(.plain)
        .shadow(color: .black.opacity(active ? 0.15 : 0.05),
                radius: active ? 6 : 2, x: 0, y: 2)
    }
}
