//
//  NewReportView.swift
//

import SwiftUI
import PhotosUI
import MapKit
import FirebaseAuth

struct NewReportView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft = ReportDraft()
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?

    @State private var isSubmitting = false
    @State private var error: String?
    @State private var success = false

    // Gemeente-UI
    @State private var selectedMunicipalityId: String = ""   // ← verplicht voor dit report
    @State private var profileLoaded = false

    // Focusbeheer
    enum Field: Hashable { case title, description }
    @FocusState private var focusedField: Field?

    // Hoogte van de (auto-groeiende) omschrijving
    @State private var descriptionHeight: CGFloat = 120

    var body: some View {
        ZStack {
            AppBackground()

            // ===== Scrollbare content =====
            ScrollView(.vertical) {
                VStack(spacing: 16) {
                    Text("Nieuwe melding").appTitle()

                    GlassCard {
                        VStack(alignment: .leading, spacing: 14) {

                            // MARK: Titel
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "textformat.size")
                                        .foregroundStyle(.secondary)
                                    Text("Titel")
                                        .font(.subheadline.weight(.semibold))
                                }
                                TextField("Bijv. kapotte straatlamp", text: $draft.title)
                                    .appTextField()
                                    .focused($focusedField, equals: .title)
                                    .submitLabel(.done)
                                    .onSubmit { focusedField = nil }
                            }

                            // MARK: Omschrijving (auto-groeiend)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "text.alignleft")
                                        .foregroundStyle(.secondary)
                                    Text("Omschrijving")
                                        .font(.subheadline.weight(.semibold))
                                }
                                GlassTextArea(
                                    text: $draft.description,
                                    placeholder: "Geef meer details…",
                                    focusedField: $focusedField,
                                    current: .description,
                                    dynamicHeight: $descriptionHeight
                                )
                                .frame(minHeight: descriptionHeight, maxHeight: 220) // ruim & begrensd
                            }

                            // MARK: Categorie
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "tag")
                                        .foregroundStyle(.secondary)
                                    Text("Categorie")
                                        .font(.subheadline.weight(.semibold))
                                }
                                HStack {
                                    Spacer(minLength: 0)
                                    Menu {
                                        ForEach(ReportCategory.allCases, id: \.self) { cat in
                                            Button {
                                                draft.category = cat.rawValue
                                            } label: {
                                                Label(cat.label, systemImage: cat.symbolName)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: ReportCategory.from(draft.category).symbolName)
                                            Text(ReportCategory.from(draft.category).label)
                                        }
                                        .font(.callout.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(ReportCategory.from(draft.category).color.opacity(0.18))
                                        .foregroundStyle(AppColors.darkText)
                                        .cornerRadius(10)
                                    }
                                }
                            }

                            // MARK: Gemeente (verplicht)
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    Image(systemName: "building.2")
                                        .foregroundStyle(.secondary)
                                    Text("Gemeente van deze melding")
                                        .font(.subheadline.weight(.semibold))
                                }

                                Picker("Gemeente", selection: $selectedMunicipalityId) {
                                    Text("— Kies een gemeente —").tag("")
                                    ForEach(MunicipalitiesNB.all, id: \.id) { m in
                                        Text(m.name).tag(m.id)
                                    }
                                }
                                .pickerStyle(.menu)

                                if !selectedMunicipalityId.isEmpty,
                                   let lab = MunicipalitiesNB.label(for: selectedMunicipalityId) {
                                    Text("Geselecteerd: \(lab)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            // MARK: Anoniem
                            Toggle("Anoniem plaatsen", isOn: $draft.isAnonymous)

                            // MARK: Locatie
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundStyle(.secondary)
                                    Text("Locatie")
                                        .font(.subheadline.weight(.semibold))
                                }
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

                            // MARK: Foto
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Image(systemName: "photo")
                                        .foregroundStyle(.secondary)
                                    Text("Foto (optioneel)")
                                        .font(.subheadline.weight(.semibold))
                                }

                                if let img = selectedImage {
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 160)
                                        .clipped()
                                        .cornerRadius(14)
                                }

                                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                                    Label(selectedImage == nil ? "Kies foto" : "Andere foto kiezen",
                                          systemImage: "photo.on.rectangle")
                                }
                                .onChange(of: selectedItem) { _, newValue in
                                    Task { await loadImage(from: newValue) }
                                }
                            }
                        }
                    }

                    // Fouten/feedback in de scroll (zodat je ze altijd ziet)
                    if let error {
                        Text(error).foregroundColor(.red).font(.footnote)
                    }
                    if success {
                        Text("Melding geplaatst ✅").foregroundColor(AppColors.success)
                    }

                    // Extra spacing zodat de sticky bar niets overlapt
                    Color.clear.frame(height: 120)
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively) // on-drag klapt keyboard in

            // ===== Sticky bottom action bar =====
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Divider().opacity(0.2)
                    HStack(spacing: 12) {
                        Button("Annuleren") {
                            focusedField = nil
                            dismiss()
                        }
                        .buttonStyle(.bordered)

                        Button(isSubmitting ? "Bezig…" : "Plaatsen") {
                            focusedField = nil
                            Task { await submit() }
                        }
                        .buttonStyle(AppButtonStyle())
                        .disabled(isSubmitting
                                  || draft.title.trimmingCharacters(in: .whitespaces).isEmpty
                                  || !MunicipalitiesNB.isValid(selectedMunicipalityId))
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: -2)
            }
        }
        .task { await preloadMunicipalityFromProfile() }
        .onTapGesture { focusedField = nil }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Gereed") { focusedField = nil }
            }
        }
        .appScaffold()
    }

    // MARK: - Prefill gemeente uit profiel

    private func preloadMunicipalityFromProfile() async {
        guard !profileLoaded, let uid = Auth.auth().currentUser?.uid else { return }
        defer { profileLoaded = true }
        if let profile = try? await UserService.shared.load(uid: uid),
           let muni = profile.municipalityId,
           MunicipalitiesNB.isValid(muni) {
            selectedMunicipalityId = muni
        }
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
        guard draft.latitude != nil, draft.longitude != nil else {
            error = "Selecteer eerst een locatie op de kaart."
            return
        }
        guard MunicipalitiesNB.isValid(selectedMunicipalityId) else {
            error = "Kies een geldige gemeente."
            return
        }

        error = nil; success = false; isSubmitting = true
        do {
            try await ReportService.shared.createReport(
                draft: draft,
                image: selectedImage,
                overrideMunicipalityId: selectedMunicipalityId // expliciet vastleggen
            )
            success = true
            try? await Task.sleep(nanoseconds: 700_000_000)
            await MainActor.run { dismiss() }
        } catch {
            self.error = error.localizedDescription
        }
        isSubmitting = false
    }
}

// MARK: - GLASSY TEXT AREA (auto-groeiend)

private struct GlassTextArea: View {
    @Binding var text: String
    var placeholder: String
    @FocusState<NewReportView.Field?>.Binding var focusedField: NewReportView.Field?
    var current: NewReportView.Field
    @Binding var dynamicHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CustomTextEditor(
                text: $text,
                placeholder: placeholder,
                focusedField: $focusedField,
                current: current,
                dynamicHeight: $dynamicHeight
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(LinearGradient(
                        colors: [.white.opacity(0.35), .white.opacity(0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        }
    }
}

// TextEditor op UIKit-basis met placeholder + auto-height
private struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    @FocusState<NewReportView.Field?>.Binding var focusedField: NewReportView.Field?
    var current: NewReportView.Field
    @Binding var dynamicHeight: CGFloat

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.font = UIFont.preferredFont(forTextStyle: .body)
        tv.backgroundColor = .clear
        tv.delegate = context.coordinator
        tv.isScrollEnabled = false            // laat hoogte meegroeien
        tv.textContainerInset = UIEdgeInsets(top: 6, left: 2, bottom: 6, right: 2)
        tv.text = ""
        tv.textColor = .label
        DispatchQueue.main.async { self.dynamicHeight = max(120, tv.contentSize.height) }
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        if focusedField == current {
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

        // hoogte updaten
        DispatchQueue.main.async {
            self.dynamicHeight = max(120, min(220, tv.contentSize.height))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, placeholder: placeholder, focusedField: $focusedField, current: current, height: $dynamicHeight)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        let placeholder: String
        @FocusState<NewReportView.Field?>.Binding var focusedField: NewReportView.Field?
        let current: NewReportView.Field
        @Binding var height: CGFloat

        init(text: Binding<String>, placeholder: String,
             focusedField: FocusState<NewReportView.Field?>.Binding,
             current: NewReportView.Field, height: Binding<CGFloat>) {
            _text = text
            self.placeholder = placeholder
            _focusedField = focusedField
            self.current = current
            _height = height
        }

        func textViewDidBeginEditing(_ tv: UITextView) {
            focusedField = current
            if tv.textColor == .placeholderText {
                tv.textColor = .label
                tv.text = ""
            }
        }

        func textViewDidEndEditing(_ tv: UITextView) {
            focusedField = nil
            if tv.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                tv.textColor = .placeholderText
                tv.text = placeholder
                text = ""
            }
        }

        func textViewDidChange(_ tv: UITextView) {
            if tv.textColor != .placeholderText {
                text = tv.text
            }
            height = max(120, min(220, tv.contentSize.height))
        }

        func textView(_ tv: UITextView, shouldChangeTextIn range: NSRange, replacementText newText: String) -> Bool {
            if newText == "\n" {
                tv.resignFirstResponder()
                focusedField = nil
                return false
            }
            if tv.textColor == .placeholderText {
                tv.textColor = .label
                tv.text = ""
            }
            return true
        }
    }
}
