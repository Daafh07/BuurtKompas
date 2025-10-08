//
//  AuthViewModel.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *Combine Framework Documentation* [Developer documentation].
//      Apple Developer. https://developer.apple.com/documentation/combine
//  Google. (2025). *Firebase Authentication with SwiftUI Examples* [Support article].
//      Firebase. https://firebase.google.com/docs/auth/ios/start
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Code geschreven door Daaf Heijnekamp (2025) als onderdeel van het BuurtKompas-inlogsysteem.
//

import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isRegister: Bool = false
    @Published var errorMessage: String?

    func submit() async {
        do {
            if isRegister {
                try await AuthService.shared.signUp(email: email, password: password)
            } else {
                try await AuthService.shared.signIn(email: email, password: password)
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
