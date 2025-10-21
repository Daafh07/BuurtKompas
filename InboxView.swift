//
//  InboxView.swift
//  BuurtKompas
//
//  Simpele inbox met live updates, swipe-acties,
//  en “Open melding” die ReportDetailSheet toont.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct InboxView: View {
    @State private var items: [AppNotification] = []
    @State private var loading = true
    @State private var error: String?
    @State private var selectedReport: Report?

    @State private var listener: ListenerRegistration?

    private var uid: String? { Auth.auth().currentUser?.uid }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                VStack(spacing: 12) {
                    HStack {
                        Text("Inbox").appTitle()
                        Spacer()
                        if loading { ProgressView().controlSize(.small) }
                    }

                    if let error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }

                    if items.isEmpty && !loading {
                        VStack(spacing: 8) {
                            Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                            Text("Geen meldingen")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        List {
                            ForEach(items) { n in
                                Button {
                                    Task { await openReportIfPossible(n) }
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Circle()
                                            .fill(n.read ? .clear : AppColors.primaryBlue.opacity(0.9))
                                            .frame(width: 10, height: 10)
                                            .padding(.top, 6)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(n.title)
                                                .font(.subheadline.weight(.semibold))
                                            Text(n.body)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                            if let date = n.createdAt {
                                                Text(date.formatted(date: .abbreviated, time: .shortened))
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if n.type == "status_changed" {
                                            Image(systemName: "arrow.triangle.2.circlepath")
                                                .foregroundStyle(.secondary)
                                        } else if n.type == "official_comment" {
                                            Image(systemName: "checkmark.seal")
                                                .foregroundStyle(.secondary)
                                        } else {
                                            Image(systemName: "bell")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    if !(n.read) {
                                        Button("Gelezen") {
                                            Task { await markRead(n) }
                                        }.tint(.blue)
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        Task { await deleteItem(n) }
                                    } label: {
                                        Label("Verwijder", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }

                    HStack {
                        Button("Markeer alles als gelezen") {
                            Task { await markAllRead() }
                        }
                        .buttonStyle(.bordered)

                        Spacer()

                        Button(role: .destructive) {
                            Task { await clearAll() }
                        } label: {
                            Text("Leeg inbox")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .onAppear { startListening() }
            .onDisappear { stopListening() }
            .sheet(item: $selectedReport) { report in
                ReportDetailSheet(report: report)
            }
        }
    }

    // MARK: - Live listen

    private func startListening() {
        guard listener == nil, let uid else {
            loading = false
            return
        }
        loading = true
        listener = NotificationsService.shared.listenInbox(for: uid) { newItems in
            self.items = newItems
            self.loading = false
        }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Actions

    private func markRead(_ n: AppNotification) async {
        guard let uid else { return }
        do {
            try await NotificationsService.shared.markRead(noteId: n.id, for: uid)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func deleteItem(_ n: AppNotification) async {
        guard let uid else { return }
        do {
            try await NotificationsService.shared.delete(noteId: n.id, for: uid)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func markAllRead() async {
        guard let uid else { return }
        do { try await NotificationsService.shared.markAllRead(for: uid) }
        catch { self.error = error.localizedDescription }
    }

    private func clearAll() async {
        guard let uid else { return }
        do { try await NotificationsService.shared.clearAll(for: uid) }
        catch { self.error = error.localizedDescription }
    }

    private func openReportIfPossible(_ n: AppNotification) async {
        // markeer gelezen en open detail indien reportId aanwezig
        await markRead(n)
        guard let reportId = n.reportId else { return }
        do {
            if let report = try await ReportService.shared.fetchReportById(reportId) {
                await MainActor.run { self.selectedReport = report }
            }
        } catch {
            self.error = error.localizedDescription
        }
    }
}
