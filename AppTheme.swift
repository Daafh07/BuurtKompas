//
//  AppTheme.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *SwiftUI Materials and Visual Effects* [Developer documentation].
//      Apple Developer. https://developer.apple.com/documentation/swiftui/material
//  Cuberto. (2021, March 22). *Glassmorphism in User Interface Design* [Blog post].
//      Medium. https://uxdesign.cc/glassmorphism-in-user-interface-design-1f39bb8f6cfe
//  Apple Inc. (2025). *Human Interface Guidelines: Color and Typography* [Design guide].
//      Apple Developer. https://developer.apple.com/design/human-interface-guidelines
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Ontwerp en code door Daaf Heijnekamp (2025) met ondersteuning van ChatGPT.
//  Deze module definieert het centrale AppTheme voor BuurtKompas.
//

import SwiftUI

// MARK: - Kleurenpalet (centraal)
public enum AppColors {
    public static let primaryBlue      = Color(red: 0.29, green: 0.57, blue: 0.96)   // #4A90E2
    public static let softBlue         = Color(red: 0.73, green: 0.86, blue: 1.00)   // #BBDBFF
    public static let lightBackground  = Color(red: 0.85, green: 0.93, blue: 1.00)   // #DAE9FF
    public static let darkText         = Color(red: 0.10, green: 0.25, blue: 0.50)
    public static let accentMint       = Color(red: 0.65, green: 0.90, blue: 0.78)
    public static let danger           = Color(red: 0.95, green: 0.30, blue: 0.35)
    public static let success          = Color(red: 0.25, green: 0.70, blue: 0.45)
    public static let warning          = Color(red: 0.98, green: 0.75, blue: 0.25)
}

// MARK: - Achtergrond (liquid glass look)
public struct AppBackground: View {
    public init() {}
    public var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                AppColors.lightBackground,
                AppColors.softBlue
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

// MARK: - Glasachtige kaarten (voor hergebruik)
public struct GlassCard<Content: View>: View {
    private let content: () -> Content
    public init(@ViewBuilder _ content: @escaping () -> Content) {
        self.content = content
    }
    public var body: some View {
        content()
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 6)
    }
}

// MARK: - Standaard knopstijl (modern minimalistisch, blauw)
public struct AppButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding()
            .frame(maxWidth: .infinity)
            .background(AppColors.primaryBlue.opacity(configuration.isPressed ? 0.85 : 1))
            .foregroundStyle(.white)
            .cornerRadius(16)
            .shadow(color: AppColors.primaryBlue.opacity(0.28), radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Tekststijlen
private struct AppTitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(AppColors.darkText)
            .shadow(color: .white.opacity(0.7), radius: 3, x: 0, y: 1)
    }
}

private struct AppSubtitleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(.secondary)
    }
}

public extension View {
    func appTitle() -> some View { modifier(AppTitleModifier()) }
    func appSubtitle() -> some View { modifier(AppSubtitleModifier()) }
}

// MARK: - Invoerveld-stijl (glass input)
private struct AppTextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(.white.opacity(0.35), lineWidth: 0.5)
            )
    }
}

public extension View {
    func appTextField() -> some View { modifier(AppTextFieldModifier()) }
}

// MARK: - Status Pill (handig voor meldingsstatus/labels)
public struct StatusPill: View {
    public enum Kind { case info, success, warning, danger }
    let text: String
    let kind: Kind

    public init(_ text: String, kind: Kind) {
        self.text = text
        self.kind = kind
    }

    public var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(background)
            .foregroundStyle(.white)
            .cornerRadius(999)
    }

    private var background: Color {
        switch kind {
        case .info:    return AppColors.primaryBlue
        case .success: return AppColors.success
        case .warning: return AppColors.warning
        case .danger:  return AppColors.danger
        }
    }
}

// MARK: - Globale scaffold (achtergrond + standaard padding)
public struct AppScaffold<Content: View>: View {
    private let content: () -> Content
    public init(@ViewBuilder _ content: @escaping () -> Content) {
        self.content = content
    }
    public var body: some View {
        ZStack {
            AppBackground()
            content()
                .padding()
        }
    }
}

public extension View {
    /// Snel een view in de BuurtKompas-stijl zetten (gradient + padding).
    func appScaffold() -> some View { AppScaffold { self } }
}

// MARK: - (Optioneel) Systeem-navigatie stylen (TabBar/NavBar)
public enum AppTheme {
    /// Roep dit één keer aan bij app-start om TabBar/NavBar te themen.
    public static func configureAppearance() {
        #if canImport(UIKit)
        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        tab.backgroundColor = UIColor.white.withAlphaComponent(0.15)

        UITabBar.appearance().standardAppearance = tab
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = tab
        }
        UITabBar.appearance().tintColor = UIColor(Color.white) // geselecteerd icoon/label wit
        UITabBar.appearance().unselectedItemTintColor = UIColor(AppColors.lightBackground.opacity(0.9))

        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialLight)
        nav.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        nav.titleTextAttributes = [.foregroundColor: UIColor(AppColors.darkText)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(AppColors.darkText)]

        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(AppColors.primaryBlue)
        #endif
    }
}
