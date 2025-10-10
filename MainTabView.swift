//
//  MainTabView.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *SwiftUI Views and Controls* [Developer documentation].
//      Apple Developer. https://developer.apple.com/documentation/swiftui
//  OpenAI (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        ZStack {
            AppBackground() // alleen de achtergrond
            TabView {
                HomeView()
                    .tabItem { Label("Home", systemImage: "house.fill") }

                ReportsView()
                    .tabItem { Label("Meldingen", systemImage: "list.bullet.rectangle") }

                MapScreen()
                    .tabItem { Label("Kaart", systemImage: "map") }

                // ⭐ Nieuw: Rewards tab
                RewardsView()
                    .tabItem { Label("Beloningen", systemImage: "gift.fill") }

                SettingsView()
                    .tabItem { Label("Instellingen", systemImage: "gearshape.fill") }
            }
            // geen .appScaffold() hier -> geen extra padding, tabbar zakt omlaag
            .tint(AppColors.primaryBlue) // blauwe selectie
        }
        // veilig: achtergrond mag onder de tabbar doorlopen
        .ignoresSafeArea(edges: .bottom)
    }
}
