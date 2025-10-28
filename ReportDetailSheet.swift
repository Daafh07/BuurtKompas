import SwiftUI
import MapKit
import FirebaseAuth
import FirebaseFirestore
import Combine
import CoreLocation   // ⬅️ voeg ook bovenaan toe naast MapKit!

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

            // Info + status
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

                    // eigenaar of moderator: menu met delete
                    if isOwner || canModerate {
                        Menu {
                            Button(role: .destructive) { Task { await deleteAction() } } label: {
                                Label("Verwijderen", systemImage: "trash")
                            }
                        } label: { Image(systemName: "ellipsis.circle").font(.title3) }
                        .foregroundStyle(.secondary)
                    }
                }
            }

            // Reacties
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
        .onDisappear { commentsVM.stopListening() }
        .appScaffold()
        .presentationDetents([.medium, .large])
    }

    // MARK: Status helpers
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

    // MARK: Likes
    private func loadHasLiked() async {
        do { hasLiked = try await ReportService.shared.hasUserLiked(reportId: report.id) }
        catch { self.error = error.localizedDescription }
    }

    private func toggleLike() async {
        guard !likeBusy else { return }
        likeBusy = true
        do {
            let newVal = try await ReportService.shared.toggleLike(reportId: report.id, currentLiked: hasLiked)
            if newVal && !hasLiked { likeCount += 1 }
            if !newVal && hasLiked { likeCount = max(0, likeCount - 1) }
            hasLiked = newVal
        } catch {
            self.error = error.localizedDescription
        }
        likeBusy = false
    }

    // MARK: Delete
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

    // iOS 26 deprecation fix
    

    private func openInMaps(coord: CLLocationCoordinate2D, title: String) {
        // ✅ Compatibel met iOS 26 en ouder
        if #available(iOS 26.0, *) {
            // Apple’s nieuwe API kan ook nog altijd met MKPlacemark
            let placemark = MKPlacemark(coordinate: coord)
            let item = MKMapItem(placemark: placemark)
            item.name = title
            item.openInMaps()
        } else {
            // Oudere fallback met looprichting-opties
            let placemark = MKPlacemark(coordinate: coord)
            let item = MKMapItem(placemark: placemark)
            item.name = title
            let opts = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking]
            item.openInMaps(launchOptions: opts)
        }
    }
}

// MARK: Reacties UI + VM

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

private struct ReportComment: Identifiable {
    let id: String
    let authorId: String
    let text: String
    let isMunicipal: Bool
    let createdAt: Date?

    static func from(id: String, data: [String: Any]) -> ReportComment? {
        guard let authorId = data["authorId"] as? String,
              let text = data["text"] as? String else { return nil }

        // ⬇️ server timestamp + client fallback
        let createdServer = (data["createdAt"] as? Timestamp)?.dateValue()
        let createdClient = (data["createdAtClient"] as? Timestamp)?.dateValue()

        return ReportComment(
            id: id,
            authorId: authorId,
            text: text,
            isMunicipal: (data["isMunicipal"] as? Bool) ?? false,
            createdAt: createdServer ?? createdClient
        )
    }
}

private final class CommentsVM: ObservableObject {
    @Published var comments: [ReportComment] = []
    @Published var newText: String = ""
    @Published var loading = false
    @Published var sending = false

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

        let ref = Firestore.firestore()
            .collection("reports").document(reportId)
            .collection("comments")
            // ⬇️ Eenvoudige sortering (geen composite index nodig)
            .order(by: "createdAt", descending: false)

        listener = ref.addSnapshotListener(includeMetadataChanges: true) { [weak self] snap, err in
            guard let self = self else { return }

            if let err = err {
                print("⚠️ [CommentsVM] Listen error:", err.localizedDescription)
                self.loading = false
                self.comments = []
                return
            }

            self.loading = false
            var items = (snap?.documents ?? []).compactMap {
                ReportComment.from(id: $0.documentID, data: $0.data())
            }

            // ⬇️ Client-side pinning van gemeentelijke reacties
            items.sort { a, b in
                if a.isMunicipal != b.isMunicipal { return a.isMunicipal && !b.isMunicipal }
                let da = a.createdAt ?? .distantPast
                let db = b.createdAt ?? .distantPast
                return da < db
            }

            self.comments = items
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    @MainActor
    func send() async {
        let text = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }
        sending = true
        defer { sending = false }

        do {
            let db = Firestore.firestore()
            let reportRef = db.collection("reports").document(reportId)
            let willBeMunicipal = canPostMunicipal && postAsMunicipal

            let commentRef = reportRef.collection("comments").document()
            try await commentRef.setData([
                "id": commentRef.documentID,
                "authorId": uid,
                "text": text,
                "isMunicipal": willBeMunicipal,
                "createdAt": FieldValue.serverTimestamp(),
                "createdAtClient": Timestamp(date: Date()) // ⬅️ fallback zodat nieuwe reacties direct goed sorteren
            ])

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

// Kleine badges
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

private extension String {
    func trimmed() -> String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
