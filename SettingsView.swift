import SwiftUI
import FirebaseAuth

struct SettingsView: View {
    @State private var userProfile: UserProfile?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        VStack(spacing: 20) {
            Text("Instellingen").appTitle()

            if loading {
                ProgressView("Laden…")
            } else if let profile = userProfile {
                GlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("E-mail: \(profile.email)")
                        Text("Rol: \(profile.role)")
                        Text("Punten: \(profile.points)")
                            .foregroundStyle(AppColors.primaryBlue)
                        if let name = profile.displayName {
                            Text("Naam: \(name)")
                        }
                    }
                }
            }

            if let error = error {
                Text(error).foregroundColor(.red).font(.footnote)
            }

            Button("Uitloggen") {
                try? Auth.auth().signOut()
            }
            .buttonStyle(AppButtonStyle())

            Spacer(minLength: 0)
        }
        .task { await loadProfile() }
        .appScaffold()
    }

    private func loadProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            userProfile = try await UserService.shared.load(uid: uid)
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
