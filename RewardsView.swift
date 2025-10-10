//
//  RewardsView.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *SwiftUI – Layout & Animation* [Developer documentation]. Apple Developer.
//  Google. (2025). *Cloud Firestore – Realtime Updates* [Developer documentation]. Firebase.
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct RewardsView: View {
    @State private var points: Int = 0
    @State private var error: String?
    @State private var listener: ListenerRegistration?   // ← realtime listener

    var body: some View {
        VStack(spacing: 16) {
            Text("Beloningen").appTitle()

            if let error {
                Text(error).foregroundStyle(.red).font(.footnote)
            }

            GlassCard {
                VStack(spacing: 12) {
                    Text("Jouw punten").font(.headline)

                    Text("\(points)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.primaryBlue)

                    ProgressView(value: progressToNextLevel, total: 1)
                        .tint(AppColors.primaryBlue)
                        .padding(.horizontal)

                    Text("Level \(currentLevel) • \(remainingToNext) punten tot Level \(currentLevel + 1)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Verdien punten").font(.headline)
                    Label("Melding plaatsen  •  +10", systemImage: "plus.app.fill")
                    Label("Melding liken      •  +1",  systemImage: "hand.thumbsup.fill")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)
        }
        .appScaffold()
        .onAppear { startListening() }
        .onDisappear { stopListening() }
    }

    // MARK: - Level-logica
    private var currentLevel: Int { max(1, points / 50 + 1) }      // elke 50 punten een level
    private var progressToNextLevel: Double { Double(points % 50) / 50.0 }
    private var remainingToNext: Int { 50 - (points % 50) }

    // MARK: - Realtime Firestore
    private func startListening() {
        stopListening() // safety: dubbele listeners voorkomen
        guard let uid = Auth.auth().currentUser?.uid else {
            self.error = "Je bent niet ingelogd."
            return
        }
        let ref = Firestore.firestore().collection("users").document(uid)
        listener = ref.addSnapshotListener { snapshot, err in
            if let err = err {
                Task { @MainActor in self.error = err.localizedDescription }
                return
            }
            guard let data = snapshot?.data() else { return }
            let newPoints = (data["points"] as? Int) ?? 0
            Task { @MainActor in
                self.points = newPoints
                if self.error != nil { self.error = nil }
            }
        }
    }

    private func stopListening() {
        listener?.remove()
        listener = nil
    }
}
