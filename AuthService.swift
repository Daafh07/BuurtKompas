//
//  AuthService.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Firebase Authentication for iOS* [Developer documentation].
//  Apple Inc. (2025). *Swift Concurrency Guide* [Developer documentation].
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//  --
//  Auth + koppel/ontkoppel push tokens.
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
        // Na aanmaken ook direct push registreren + token koppelen
        await PushManager.shared.ensurePermissionsAndRegister()
        await PushManager.shared.attachTokenToUserIfNeeded()
    }

    func signIn(email: String, password: String) async throws {
        _ = try await Auth.auth().signIn(withEmail: email, password: password)
        // Na inloggen push autoriseren/registreren en token koppelen aan deze gebruiker
        await PushManager.shared.ensurePermissionsAndRegister()
        await PushManager.shared.attachTokenToUserIfNeeded()
    }

    func signOut() throws {
        // Probeer token eerst los te koppelen (fire-and-forget)
        PushManager.shared.detachTokenFromUser()
        try Auth.auth().signOut()
    }
}
