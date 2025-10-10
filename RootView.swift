//
//  RootView.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *SwiftUI State Management* [Developer documentation].
//  Google. (2025). *Firebase Authentication State Changes (iOS)* [Developer documentation].
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//

import SwiftUI
import FirebaseAuth
import Combine

struct RootView: View {
    @State private var isLoggedIn: Bool = (Auth.auth().currentUser != nil)
    @State private var profile: UserProfile?
    @State private var loading = false
    @State private var error: String?

    var body: some View {
        Group {
            if !isLoggedIn {
                AuthView()
            } else {
                MainTabView()
            }
        }
        // 🔊 Luister ALTIJD naar auth-state (ook wanneer MainTabView zichtbaar is)
        .onReceive(Auth.auth().authStateDidChangePublisher()) { user in
            let logged = (user != nil)
            if logged && isLoggedIn == false, let u = user {
                Task { await ensureUserProfile(for: u) }
            }
            isLoggedIn = logged
            if !logged { profile = nil }
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

// Publisher helper
extension Auth {
    func authStateDidChangePublisher() -> AnyPublisher<User?, Never> {
        let subject = PassthroughSubject<User?, Never>()
        let handle = addStateDidChangeListener { _, user in subject.send(user) }
        return subject
            .handleEvents(receiveCancel: { self.removeStateDidChangeListener(handle) })
            .eraseToAnyPublisher()
    }
}
