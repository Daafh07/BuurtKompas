//
//  AuthService.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Firebase Authentication for iOS* [Developer documentation].
//      Firebase. https://firebase.google.com/docs/auth
//  Apple Inc. (2025). *Swift Concurrency Guide* [Developer documentation].
//      Apple Developer. https://developer.apple.com/documentation/swift/concurrency
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Code ontwikkeld door Daaf Heijnekamp (2025) op basis van Firebase-authenticatievoorbeelden.
//

import Foundation
import FirebaseAuth

enum AuthError: Error {
    case noCurrentUser
}

final class AuthService {
    static let shared = AuthService()
    private init() {}

    var currentUser: User? { Auth.auth().currentUser }

    func signUp(email: String, password: String) async throws {
        _ = try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }
}
