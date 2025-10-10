//
//  NewReportView.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *PHPickerViewController* [Developer documentation]. Apple Developer.
//  Apple Inc. (2025). *SwiftUI forms & pickers* [Developer documentation]. Apple Developer.
//  Apple Inc. (2025). *MapKit (MKMapView & gestures)* [Developer documentation]. Apple Developer.
//  Google. (2025). *Cloud Firestore & Storage* [Developer documentation]. Firebase.
//  Apple Inc. (2025). *UITextView & UIResponder* [Developer documentation]. Apple Developer.
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI.
//
//  Formulier om een melding te maken met optionele foto-upload en centrale live-locatie.
//  Inclusief: custom meerregelige editor met Enter/Done-toets om het toetsenbord te sluiten + glassy stijl.
//

import SwiftUI
import PhotosUI
import MapKit

struct NewReportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ReportDraft()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    @State private var isSubmitting = false
    @State private var error: String?
    @State private var success = false

    // Focusbeheer voor velden
    enum Field: Hashable { case title, description }
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(spacing: 16) {
            Text("Nieuwe melding").appTitle()

            GlassCard {
                VStack(spacing: 12) {
                    // Titel
                    TextField("Titel", text: $draft.title)
                        .appTextField()
                        .focused($focusedField, equals: .title)
                        .submitLabel(.done)
                        .onSubmit { focusedField = nil }

                    // Omschrijving (meerregelig) — GLASSY + sluit bij Enter/Done
                    GlassTextArea(
                        text: $draft.description,
                        placeholder: "Omschrijving",
                        focusedField: $focusedField,
                        current: .description
                    )

                    // Categorie (centraal via ReportCategory)
                    HStack {
                        Label("Categorie", systemImage: ReportCategory.from(draft.category).symbolName)
                            .font(.subheadline)
                        Spacer()
                        Menu {
                            ForEach(ReportCategory.allCases, id: \.self) { cat in
                                Button {
                                    draft.category = cat.rawValue
                                } label: {
                                    Label(cat.label, systemImage: cat.symbolName)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: ReportCategory.from(draft.category).symbolName)
                                Text(ReportCategory.from(draft.category).label)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(ReportCategory.from(draft.category).color.opacity(0.18))
                            .foregroundStyle(AppColors.darkText)
                            .cornerRadius(12)
                        }
                    }

                    // Anoniem toggle
                    Toggle("Anoniem plaatsen", isOn: $draft.isAnonymous)

                    // 📍 CENTRAAL: Live-locatiekaart met verplaatsbare pin
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Locatie").font(.subheadline)
                        LiveLocationPicker(
                            latitude: $draft.latitude,
                            longitude: $draft.longitude
                        )
                        .frame(height: 260)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.3), lineWidth: 0.5))

                        Text("Tip: sleep de pin om de exacte plek te kiezen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // 📸 Foto upload
                    VStack(alignment: .leading, spacing: 8) {
                        if let img = selectedImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(height: 160)
                                .clipped()
                                .cornerRadius(14)
                        }

                        PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                            Label(selectedImage == nil ? "Kies foto (optioneel)" : "Andere foto kiezen",
                                  systemImage: "photo")
                        }
                        .onChange(of: selectedItem) { _, newValue in
                            Task { await loadImage(from: newValue) }
                        }
                    }
                }
            }

            if let error {
                Text(error).foregroundColor(.red).font(.footnote)
            }
            if success {
                Text("Melding geplaatst ✅").foregroundColor(AppColors.success)
            }

            Button(isSubmitting ? "Bezig…" : "Plaatsen") {
                focusedField = nil
                Task { await submit() }
            }
            .buttonStyle(AppButtonStyle())
            .disabled(isSubmitting || draft.title.trimmingCharacters(in: .whitespaces).isEmpty)

            Button("Annuleren") {
                focusedField = nil
                dismiss()
            }
            .foregroundStyle(AppColors.primaryBlue)

            Spacer(minLength: 0)
        }
        // Tik-buiten-veld sluit keyboard
        .onTapGesture { focusedField = nil }
        // Keyboard toolbar met "Gereed"
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Gereed") { focusedField = nil }
            }
        }
        .appScaffold()
    }

    // MARK: - Helpers

    private func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            if let data = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run { self.selectedImage = image }
            }
        } catch {
            await MainActor.run { self.error = error.localizedDescription }
        }
    }

    private func submit() async {
        guard !draft.title.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        // Vereis een gekozen locatie
        guard draft.latitude != nil, draft.longitude != nil else {
            error = "Selecteer eerst een locatie op de kaart."
            return
        }

        error = nil; success = false; isSubmitting = true
        do {
            try await ReportService.shared.createReport(draft: draft, image: selectedImage)
            success = true
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run { dismiss() }
        } catch {
            self.error = error.localizedDescription
        }
        isSubmitting = false
    }
}

//
// MARK: - GLASSY TEXT AREA (meerregelig) die het toetsenbord sluit bij Enter/Done
//

private struct GlassTextArea: View {
    @Binding var text: String
    var placeholder: String
    @FocusState<NewReportView.Field?>.Binding var focusedField: NewReportView.Field?
    var current: NewReportView.Field

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CustomTextEditor(
                text: $text,
                placeholder: placeholder,
                focusedField: $focusedField,
                current: current
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(LinearGradient(
                        colors: [
                            .white.opacity(0.35),
                            .white.opacity(0.12)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
    }
}

// MARK: - Aangepaste TextEditor (UIKit) met Enter=Done + placeholder die nooit in je binding komt
private struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    @FocusState<NewReportView.Field?>.Binding var focusedField: NewReportView.Field?
    var current: NewReportView.Field

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.delegate = context.coordinator
        tv.isScrollEnabled = true
        tv.returnKeyType = .done
        tv.textContainerInset = UIEdgeInsets(top: 6, left: 2, bottom: 6, right: 2)
        tv.text = ""                // start leeg
        tv.textColor = .label
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        // Deterministisch gedrag o.b.v. focus + binding
        if focusedField == current {
            // Actief veld: NOOIT placeholder tonen
            if text.isEmpty {
                if tv.textColor != .label || tv.text != "" {
                    tv.textColor = .label
                    tv.text = ""
                }
            } else {
                if tv.text != text || tv.textColor != .label {
                    tv.textColor = .label
                    tv.text = text
                }
            }
        } else {
            // Niet actief
            if text.isEmpty {
                if tv.text != placeholder || tv.textColor != .placeholderText {
                    tv.textColor = .placeholderText
                    tv.text = placeholder
                }
            } else {
                if tv.text != text || tv.textColor != .label {
                    tv.textColor = .label
                    tv.text = text
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, placeholder: placeholder, focusedField: $focusedField, current: current)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let placeholder: String
        @FocusState<NewReportView.Field?>.Binding var focusedField: NewReportView.Field?
        let current: NewReportView.Field

        init(text: Binding<String>, placeholder: String, focusedField: FocusState<NewReportView.Field?>.Binding, current: NewReportView.Field) {
            _text = text
            self.placeholder = placeholder
            _focusedField = focusedField
            self.current = current
        }

        func textViewDidBeginEditing(_ tv: UITextView) {
            focusedField = current
            // Als er nog placeholder stond → direct leegmaken
            if tv.textColor == .placeholderText {
                tv.textColor = .label
                tv.text = ""
            }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            focusedField = nil
            // Geen tekst? placeholder tonen (binding blijft leeg)
            if tv.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                tv.textColor = .placeholderText
                tv.text = placeholder
                text = "" // binding leeg houden
            }
        }

        func textViewDidChange(_ tv: UITextView) {
            // Alleen echte tekst (geen placeholder) naar binding schrijven
            if tv.textColor != .placeholderText {
                text = tv.text
            }
        }

        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText newText: String) -> Bool {
            // Enter/Return → sluit toetsenbord
            if newText == "\n" {
                tv.resignFirstResponder()
                focusedField = nil
                return false
            }

            // 🔧 Belangrijk: als er nog placeholder staat en de user typt een normaal teken,
            // wis eerst de placeholder en begin met echte tekst.
            if tv.textColor == .placeholderText {
                tv.textColor = .label
                tv.text = ""
                // iOS gaat nu alsnog het nieuwe teken invoegen (range is nog geldig)
            }

            return true
        }
    }
}
