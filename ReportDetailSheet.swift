//
//  ReportDetailSheet.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). SwiftUI Sheets & Presentation [Developer documentation]. Apple Developer.
//  Apple Inc. (2025). MapKit – Open in Maps [Developer documentation]. Apple Developer.
//  Google. (2025). Cloud Firestore – Update & Query data [Developer documentation]. Firebase.
//  OpenAI. (2025). ChatGPT (GPT-5) [Large language model]. OpenAI.
//
//  Detailweergave voor een melding met acties + reacties + (moderator) status-wijziging.
//
import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore
import Combine

struct ReportDetailSheet: View, Identifiable {
    var id: String { report.id }

    @Environment(\.dismiss) private var dismiss
    let report: Report

    // Likes
    @State private var isLoading = true
    @State private var likeCount: Int = 0
    @State private var hasLiked: Bool = false
    @State private var likeBusy = false

    // Delete
    @State private var isDeleting = false

    // Errors
    @State private var error: String?

    // Moderation
    @State private var canModerate = false
    @State private var statusLocal: String

    // Comments VM
    @StateObject private var commentsVM: CommentsVM

    init(report: Report) {
        self.report = report
        _commentsVM = StateObject(wrappedValue: CommentsVM(reportId: report.id))
        _statusLocal = State(initialValue: report.status)
    }

    private var currentUserId: String? { Auth.auth().currentUser?.uid }
    private var isOwner: Bool { currentUserId == report.authorId }

    var body: some View {
        VStack(spacing: 16) {
            Text("Melding").appTitle()

            if let error {
                Text(error).foregroundStyle(.red).font(.footnote)
            }

            // Melding kaart + statusregel (moderators)
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(report.title)
                                .font(.title3.weight(.semibold))
                            HStack(spacing: 8) {
                                CategoryPill(category: report.categoryEnum)
                                StatusBadge(status: statusLocal)
                            }
                        }
                        Spacer()
                    }

                    // Moderation status control (alleen voor gemeente/moderator/admin)
                    if canModerate {
                        HStack(spacing: 8) {
                            Text("Status wijzigen:")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Menu(statusLabel(statusLocal)) {
                                ForEach(Array(ReportService.allowedStatuses), id: \.self) { st in
                                    Button {
                                        Task { await changeStatus(to: st) }
                                    } label: {
                                        Label(statusLabel(st), systemImage: statusIcon(st))
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                        }
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

            // Acties
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

            // Reacties (+ gemeentelijke pinning via CommentsVM)
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Reacties", systemImage: "text.bubble")
                            .font(.headline)
                        Spacer()
                        if commentsVM.loading { ProgressView().controlSize(.small) }
                    }

                    if commentsVM.comments.isEmpty && !commentsVM.loading {
                        Text("Nog geen reacties. Wees de eerste!")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(commentsVM.comments) { c in
                                CommentRow(viewModel: c, currentUserId: currentUserId)
                                Divider().opacity(0.1)
                            }
                        }
                    }

                    // Invoer + Gemeente toggle
                    VStack(spacing: 10) {
                        if commentsVM.canPostMunicipal {
                            Toggle("Gemeentelijke reactie (bovenaan vastpinnen)",
                                   isOn: $commentsVM.postAsMunicipal)
                                .toggleStyle(.switch)
                        }

                        HStack(spacing: 10) {
                            TextField("Schrijf een reactie…", text: $commentsVM.newText, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(1...3)

                            Button {
                                Task { await commentsVM.send() }
                            } label: {
                                if commentsVM.sending {
                                    ProgressView()
                                } else {
                                    Image(systemName: "paperplane.fill")
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(
                                commentsVM.sending
                                || commentsVM.newText.trimmed().isEmpty
                                || currentUserId == nil
                            )
                        }
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
            commentsVM.startListening()
            Task { await commentsVM.loadCurrentUserRole() }
            Task { await loadModerationRight() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if report.photoUrl == nil { isLoading = false }
            }
        }
        .onDisappear {
            commentsVM.stopListening()
        }
        .appScaffold()
        .presentationDetents([.medium, .large])
    }

    // MARK: Status helpers (UI)

    private func statusLabel(_ s: String) -> String {
        switch s {
        case "resolved": return "Opgelost"
        case "in_progress": return "In behandeling"
        case "need_info": return "Meer info"
        default: return "Open"
        }
    }

    private func statusIcon(_ s: String) -> String {
        switch s {
        case "resolved": return "checkmark.seal.fill"
        case "in_progress": return "clock.fill"
        case "need_info": return "questionmark.circle.fill"
        default: return "exclamationmark.circle.fill"
        }
    }

    private func loadModerationRight() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            if let profile = try await UserService.shared.load(uid: uid) {
                let role = profile.role.lowercased()
                await MainActor.run {
                    self.canModerate = (role == "municipality" || role == "moderator" || role == "admin")
                }
            }
        } catch {
            await MainActor.run { self.canModerate = false }
        }
    }

    private func changeStatus(to newStatus: String) async {
        guard canModerate else { return }
        do {
            try await ReportService.shared.updateStatus(reportId: report.id, newStatus: newStatus)
            await MainActor.run { self.statusLocal = newStatus }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    // MARK: Like logic

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

    // MARK: Overige acties

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
        // MKPlacemark is deprecated warning op iOS 26+, maar blijft werken.
        // Wil je 26-only API, dan kunnen we een #available pad maken.
        let placemark = MKPlacemark(coordinate: coord)
        let item = MKMapItem(placemark: placemark)
        item.name = title
        let opts = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
        item.openInMaps(launchOptions: opts)
    }
}

// MARK: Reacties UI

private struct CommentRow: View {
    let viewModel: ReportComment
    let currentUserId: String?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: viewModel.isMunicipal ? "building.2.crop.circle.fill" : "person.circle.fill")
                .font(.title3)
                .foregroundStyle(viewModel.isMunicipal ? .orange : .secondary)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(viewModel.isMunicipal ? "Gemeente" : (viewModel.authorId == currentUserId ? "Jij" : "Gebruiker"))
                        .font(.subheadline.weight(.semibold))

                    if viewModel.isMunicipal {
                        Text("Gemeente")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundStyle(.orange)
                            .cornerRadius(6)
                    }
                    if let date = viewModel.createdAt {
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                Text(viewModel.text)
                    .font(.body)
            }
            Spacer()
        }
    }
}

// MARK: Reacties model

private struct ReportComment: Identifiable {
    let id: String
    let authorId: String
    let text: String
    let isMunicipal: Bool
    let createdAt: Date?

    static func from(id: String, data: [String: Any]) -> ReportComment? {
        guard let authorId = data["authorId"] as? String,
              let text = data["text"] as? String else { return nil }
        return ReportComment(
            id: id,
            authorId: authorId,
            text: text,
            isMunicipal: (data["isMunicipal"] as? Bool) ?? false,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
        )
    }
}

// MARK: Reacties VM (incl. rolbepaling + gemeente toggle)

private final class CommentsVM: ObservableObject {
    @Published var comments: [ReportComment] = []
    @Published var newText: String = ""
    @Published var loading = false
    @Published var sending = false

    // Rol & UI
    @Published var canPostMunicipal = false
    @Published var postAsMunicipal = false

    private let reportId: String
    private var listener: ListenerRegistration?

    init(reportId: String) { self.reportId = reportId }

    @MainActor
    func loadCurrentUserRole() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            if let profile = try await UserService.shared.load(uid: uid) {
                let role = profile.role.lowercased()
                let isMod = (role == "municipality" || role == "moderator" || role == "admin")
                self.canPostMunicipal = isMod
                self.postAsMunicipal = isMod
            }
        } catch {
            self.canPostMunicipal = false
            self.postAsMunicipal = false
        }
    }

    func startListening() {
        guard listener == nil else { return }
        loading = true

        // Gemeente bovenaan (isMunicipal desc), daarna oudste eerst
        let ref = Firestore.firestore()
            .collection("reports").document(reportId)
            .collection("comments")
            .order(by: "isMunicipal", descending: true)
            .order(by: "createdAt", descending: false)

        listener = ref.addSnapshotListener { [weak self] snap, _ in
            guard let self = self else { return }
            self.loading = false
            if let docs = snap?.documents {
                self.comments = docs.compactMap { ReportComment.from(id: $0.documentID, data: $0.data()) }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    @MainActor
    func send() async {
        let text = newText.trimmed()
        guard !text.isEmpty else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        sending = true
        defer { sending = false }

        do {
            let db = Firestore.firestore()
            let reportRef = db.collection("reports").document(reportId)
            let willBeMunicipal = canPostMunicipal && postAsMunicipal

            // 1) Voeg comment toe
            let commentRef = reportRef.collection("comments").document()
            try await commentRef.setData([
                "id": commentRef.documentID,
                "authorId": uid,
                "text": text,
                "isMunicipal": willBeMunicipal,
                "createdAt": FieldValue.serverTimestamp()
            ])

            // 2) Teller + updatedAt
            try await reportRef.updateData([
                "commentsCount": FieldValue.increment(Int64(1)),
                "updatedAt": FieldValue.serverTimestamp()
            ])

            newText = ""
        } catch {
            print("⚠️ Comment plaatsen faalde: \(error.localizedDescription)")
        }
    }
}

// MARK: Kleine badges

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

// MARK: Helpers

private extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
