//
//  SettingsView.swift
//  BuurtKompas
//
//  Instellingen met gemeente-keuze, gekoppeld aan MunicipalitiesNB + kaart-refresh.
//

import SwiftUI
import FirebaseAuth

// Belangrijk: de Notification.Name("municipalityDidChange") staat in AppNotifications.swift.
// Definieer 'm NIET opnieuw hier (anders "Invalid redeclaration").

struct SettingsView: View {
    @State private var userProfile: UserProfile?
    @State private var loading = true
    @State private var error: String?

    // Gemeente-keuze voor dit account
    @State private var selectedMunicipalityId: String = ""

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

                        Divider().padding(.vertical, 4)

                        // Gemeente-keuze
                        Text("Gemeente").font(.headline)

                        Picker("Gemeente", selection: $selectedMunicipalityId) {
                            Text("— Kies je gemeente —").tag("")
                            ForEach(MunicipalitiesNB.all, id: \.id) { m in
                                Text(m.name).tag(m.id)
                            }
                        }
                        .pickerStyle(.menu)

                        if !selectedMunicipalityId.isEmpty,
                           let lbl = MunicipalitiesNB.label(for: selectedMunicipalityId) {
                            Text("Geselecteerd: \(lbl)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            Task { await saveMunicipality() }
                        } label: {
                            Label("Opslaan", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }

            if let error {
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

    // MARK: - Data

    private func loadProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let profile = try await UserService.shared.load(uid: uid)
            self.userProfile = profile
            self.selectedMunicipalityId = profile?.municipalityId ?? ""
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func saveMunicipality() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            // Lege keuze = geen filter; anders valideren
            let trimmed = selectedMunicipalityId.trimmingCharacters(in: .whitespacesAndNewlines)
            let finalValue: String? =
                trimmed.isEmpty ? nil :
                (MunicipalitiesNB.isValid(trimmed) ? trimmed : nil)

            if trimmed.isEmpty == false && finalValue == nil {
                // Ongeldige keuze (zou niet moeten gebeuren met Picker op MunicipalitiesNB.all)
                await MainActor.run { self.error = "Kies een geldige gemeente." }
                return
            }

            try await UserService.shared.updateMunicipality(uid: uid, municipalityId: finalValue)

            // UI opnieuw laden
            try? await Task.sleep(nanoseconds: 150_000_000)
            await loadProfile()

            // 🔔 Laat kaart/listeners opnieuw starten met nieuwe gemeente
            await MainActor.run {
                NotificationCenter.default.post(name: .municipalityDidChange, object: nil)
            }

        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }
}
