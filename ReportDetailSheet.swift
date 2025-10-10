//
//  ReportDetailSheet.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *SwiftUI Sheets & Presentation* [Developer documentation]. Apple Developer.
//  Apple Inc. (2025). *MapKit – Open in Maps* [Developer documentation]. Apple Developer.
//  Google. (2025). *Cloud Firestore – Update data* [Developer documentation]. Firebase.
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//  --
//  Detailweergave voor een melding met acties.
//

import SwiftUI
import MapKit
import FirebaseAuth

struct ReportDetailSheet: View, Identifiable {
    var id: String { report.id }

    @Environment(\.dismiss) private var dismiss
    let report: Report

    @State private var isLoading = true
    @State private var likeCount: Int = 0
    @State private var hasLiked: Bool = false
    @State private var likeBusy = false
    @State private var isDeleting = false
    @State private var error: String?

    private var currentUserId: String? { Auth.auth().currentUser?.uid }
    private var isOwner: Bool { currentUserId == report.authorId }

    var body: some View {
        VStack(spacing: 16) {
            Text("Melding").appTitle()

            if let error {
                Text(error).foregroundStyle(.red).font(.footnote)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(report.title)
                                .font(.title3.weight(.semibold))
                            HStack(spacing: 8) {
                                CategoryPill(category: report.categoryEnum)
                                StatusBadge(status: report.status)
                            }
                        }
                        Spacer()
                    }

                    if let urlStr = report.photoUrl, let url = URL(string: urlStr) {
                        AsyncImage(url: url, transaction: .init(animation: .easeInOut)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().scaledToFill()
                                    .onAppear { isLoading = false }
                            case .failure(_):
                                Image(systemName: "photo").resizable().scaledToFit().padding(18)
                                    .onAppear { isLoading = false }
                            case .empty:
                                ProgressView().onAppear { isLoading = true }
                            @unknown default:
                                Color.clear
                            }
                        }
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(12)
                    } else {
                        Color.clear.frame(height: 0).onAppear { isLoading = false }
                    }

                    Text(report.description)
                        .font(.body)
                        .foregroundStyle(AppColors.darkText)

                    if let date = report.createdAt {
                        Text("Geplaatst \(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            GlassCard {
                HStack(spacing: 12) {
                    Button { Task { await toggleLike() } } label: {
                        HStack(spacing: 6) {
                            Image(systemName: hasLiked ? "hand.thumbsup.fill" : "hand.thumbsup")
                            Text(likeBusy ? "Bezig…" : (hasLiked ? "Vind ik niet meer leuk" : "Vind ik leuk"))
                            Text("(\(likeCount))")
                        }
                    }
                    .buttonStyle(AppButtonStyle())
                    .disabled(likeBusy || currentUserId == nil)

                    if let coord = report.coordinate {
                        Button { openInMaps(coord: coord, title: report.title) } label: {
                            Label("Route", systemImage: "map.fill")
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    if isOwner {
                        Menu {
                            Button(role: .destructive) { Task { await deleteAction() } } label: {
                                Label("Verwijderen", systemImage: "trash")
                            }
                        } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            Button("Sluiten") { dismiss() }
                .buttonStyle(AppButtonStyle())

            Spacer(minLength: 0)
        }
        .onAppear {
            likeCount = report.likes
            Task { await loadHasLiked() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if report.photoUrl == nil { isLoading = false }
            }
        }
        .appScaffold()
        .presentationDetents([.medium, .large])
    }

    // MARK: - Like logic

    private func loadHasLiked() async {
        do {
            hasLiked = try await ReportService.shared.hasUserLiked(reportId: report.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func toggleLike() async {
        guard !likeBusy else { return }
        likeBusy = true
        do {
            let newStatus = try await ReportService.shared.toggleLike(reportId: report.id, currentLiked: hasLiked)
            if newStatus && !hasLiked { likeCount += 1 }
            if !newStatus && hasLiked { likeCount = max(0, likeCount - 1) }
            hasLiked = newStatus
        } catch {
            self.error = error.localizedDescription
        }
        likeBusy = false
    }

    // MARK: - Overige acties

    private func deleteAction() async {
        guard !isDeleting else { return }
        isDeleting = true
        do {
            try await ReportService.shared.deleteReport(reportId: report.id)
            await MainActor.run { dismiss() }
        } catch {
            self.error = error.localizedDescription
        }
        isDeleting = false
    }

    private func openInMaps(coord: CLLocationCoordinate2D, title: String) {
        // Compatibele, veilige variant — placemark-fallback blijft het meest robuust.
        let placemark = MKPlacemark(coordinate: coord)
        let item = MKMapItem(placemark: placemark)
        item.name = title
        let opts = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        item.openInMaps(launchOptions: opts)
    }
}

// MARK: - Kleine badges

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

private struct StatusBadge: View {
    let status: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon(for: status))
            Text(label(for: status))
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint(for: status).opacity(0.18))
        .foregroundStyle(AppColors.darkText)
        .cornerRadius(999)
    }

    private func label(for s: String) -> String {
        switch s {
        case "resolved": return "Opgelost"
        case "in_progress": return "In behandeling"
        case "need_info": return "Meer info"
        default: return "Open"
        }
    }
    private func icon(for s: String) -> String {
        switch s {
        case "resolved": return "checkmark.seal.fill"
        case "in_progress": return "clock.fill"
        case "need_info": return "questionmark.circle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }
    private func tint(for s: String) -> Color {
        switch s {
        case "resolved": return .green
        case "in_progress": return .orange
        case "need_info": return .pink
        default: return AppColors.primaryBlue
        }
    }
}
