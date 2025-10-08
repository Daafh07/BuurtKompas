import SwiftUI

struct AuthView: View {
    @StateObject private var vm = AuthViewModel()

    var body: some View {
        ZStack {
            AppBackground()   // uit Theme/

            VStack(spacing: 22) {
                Text("BuurtKompas")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.darkText)
                    .shadow(color: .white.opacity(0.8), radius: 4)

                GlassCard {     // uit Theme/
                    VStack(spacing: 16) {
                        TextField("E-mail", text: $vm.email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(14)

                        SecureField("Wachtwoord", text: $vm.password)
                            .textContentType(.password)
                            .padding()
                            .background(.ultraThinMaterial)
                            .cornerRadius(14)

                        Button(vm.isRegister ? "Account aanmaken" : "Inloggen") {
                            Task { await vm.submit() }
                        }
                        .buttonStyle(AppButtonStyle()) // uit Theme/

                        Button(vm.isRegister ? "Ik heb al een account" : "Nieuw? Maak een account") {
                            withAnimation { vm.isRegister.toggle() }
                        }
                        .foregroundColor(AppColors.primaryBlue)
                    }
                    .padding(.vertical)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
        }
    }
}
