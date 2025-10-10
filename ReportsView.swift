//
//  ReportsView.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *SwiftUI Lists & AsyncImage* [Developer documentation]. Apple Developer.
//  Google. (2025). *Cloud Firestore – Query data* [Developer documentation]. Firebase.
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//
//  Toont eigen meldingen in GlassCards + knop om nieuwe melding te plaatsen.
//

import SwiftUI

struct ReportsView: View {
    @StateObject private var vm = ReportsViewModel()
    @State private var showNew = false

    var body: some View {
        VStack(spacing: 16) {
            header

            if let err = vm.error {
                Text(err).foregroundColor(.red).font(.footnote)
            }

            if vm.items.isEmpty && !vm.loading {
                GlassCard { Text("Je hebt nog geen meldingen. Druk op • om er één te maken.") }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(vm.items) { report in
                            ReportRow(report: report)
                        }
                    }
                    .padding(.bottom, 12)
                }
            }

            Spacer(minLength: 0)
        }
        .sheet(isPresented: $showNew) { NewReportView() }
        .task { vm.start(); await vm.refresh() }
        .onDisappear { vm.stop() }
        .refreshable { await vm.refresh() }
        .appScaffold()
    }

    private var header: some View {
        HStack {
            Text("Jouw meldingen").appTitle()
            Spacer()
            Button { showNew = true } label: {
                Image(systemName: "plus.circle.fill").font(.system(size: 24, weight: .semibold))
            }
            .foregroundStyle(AppColors.primaryBlue)
        }
    }
}

private struct ReportRow: View {
    let report: Report

    var body: some View {
        GlassCard {
            HStack(alignment: .top, spacing: 12) {
                if let urlStr = report.photoUrl, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().scaledToFill()
                        case .failure(_): Image(systemName: "photo").resizable().scaledToFit().padding(18)
                        case .empty: ProgressView()
                        @unknown default: Color.clear
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipped()
                    .cornerRadius(12)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(report.title).font(.headline)
                    Text(report.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        CategoryPill(category: report.categoryEnum)
                        StatusPill(statusLabel(report.status), kind: pillKind(report.status))
                        if let date = report.createdAt {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()
            }
        }
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
    private func pillKind(_ s: String) -> StatusPill.Kind {
        switch s {
        case "resolved": return .success
        case "in_progress": return .warning
        case "need_info": return .danger
        default: return .info
        }
    }
}

private struct CategoryPill: View {
    let category: ReportCategory
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: category.symbolName)
            Text(category.label)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(category.color.opacity(0.18))
        .foregroundStyle(AppColors.darkText)
        .cornerRadius(999)
    }
}
