//
//  RootView.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *SwiftUI State Management* [Developer documentation].
//      Apple Developer. https://developer.apple.com/documentation/swiftui
//  Google. (2025). *Firebase Authentication State Changes (iOS)* [Developer documentation].
//      Firebase. https://firebase.google.com/docs/auth
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Geschreven door Daaf Heijnekamp (2025) met hulp van ChatGPT.
//  Verzorgt de routering tussen AuthView en de hoofdapp na succesvolle login.

import SwiftUI
import FirebaseAuth

struct RootView: View {
    @State private var isLoggedIn: Bool = (Auth.auth().currentUser != nil)
    @State private var profile: UserProfile?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        Group {
            if !isLoggedIn {
                AuthView()
                    .onReceive(Auth.auth().authStateDidChangePublisher()) { user in
                        isLoggedIn = (user != nil)
                        if let user { Task { await ensureUserProfile(for: user) } }
                    }
            } else {
                LoggedInHome(
                    profile: profile,
                    onSignOut: {
                        do { try Auth.auth().signOut() } catch { print(error) }
                        isLoggedIn = false
                        profile = nil
                    },
                    loading: loading,
                    error: error
                )
            }
        }
    }

    @MainActor
    private func ensureUserProfile(for user: User) async {
        loading = true; error = nil
        do {
            let p = try await UserService.shared.createIfNeeded(uid: user.uid, email: user.email ?? "")
            profile = p
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

// Klein, stijlvol “ingelogd” scherm in jouw thema
struct LoggedInHome: View {
    let profile: UserProfile?
    let onSignOut: () -> Void
    let loading: Bool
    let error: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("BuurtKompas").appTitle()

            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    if loading {
                        ProgressView("Profiel laden…")
                    } else {
                        Text("Ingelogd ✅").font(.headline)
                        if let p = profile {
                            Text("E-mail: \(p.email)")
                            Text("Rol: \(p.role)")
                            Text("Punten: \(p.points)")
                                .foregroundStyle(AppColors.primaryBlue)
                        } else {
                            Text("Profiel niet gevonden").foregroundStyle(.secondary)
                        }
                    }
                    if let error = error {
                        Text(error).foregroundStyle(.red).font(.footnote)
                    }
                }
            }

            Button("Uitloggen", action: onSignOut)
                .buttonStyle(AppButtonStyle())

            Spacer(minLength: 0)
        }
        .appScaffold()
    }
}

// Publisher helper (zoals eerder)
import Combine
extension Auth {
    func authStateDidChangePublisher() -> AnyPublisher<User?, Never> {
        let subject = PassthroughSubject<User?, Never>()
        let handle = addStateDidChangeListener { _, user in subject.send(user) }
        return subject
            .handleEvents(receiveCancel: { self.removeStateDidChangeListener(handle) })
            .eraseToAnyPublisher()
    }
}
