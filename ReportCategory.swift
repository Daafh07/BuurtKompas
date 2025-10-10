//
//  ReportCategory.swift
//
//  Bronvermelding (APA 7):
//  Apple Inc. (2025). *SF Symbols* [Developer documentation]. Apple Developer. https://developer.apple.com/sf-symbols
//  Apple Inc. (2025). *SwiftUI Color* [Developer documentation]. Apple Developer. https://developer.apple.com/documentation/swiftui/color
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//  --
//  Centrale definitie van meldingscategorieën (labels, iconen, kleuren).
//

import SwiftUI
import UIKit

enum ReportCategory: String, CaseIterable, Codable, Hashable {
    case verlichting    // Verlichting
    case vuilnisbak     // Vuilnisbak
    case verkeer        // Verkeer
    case vandalisme     // Vandalisme
    case overlast       // Overlast
    case anders         // Anders

    var label: String {
        switch self {
        case .verlichting: return "Verlichting"
        case .vuilnisbak:  return "Vuilnisbak"
        case .verkeer:     return "Verkeer"
        case .vandalisme:  return "Vandalisme"
        case .overlast:    return "Overlast"
        case .anders:      return "Anders"
        }
    }

    /// SF Symbol voor UI (kaartpin, chips, etc.)
    var symbolName: String {
        switch self {
        case .verlichting: return "lightbulb.max.fill"
        case .vuilnisbak:  return "trash.fill"
        case .verkeer:     return "car.fill"              // alternatief: "traffic.light"
        case .vandalisme:  return "hammer.fill"
        case .overlast:    return "exclamationmark.bubble.fill"
        case .anders:      return "questionmark.circle.fill"
        }
    }

    /// Voor SwiftUI
    var color: Color {
        switch self {
        case .verlichting: return .yellow
        case .vuilnisbak:  return .green
        case .verkeer:     return .orange
        case .vandalisme:  return .red
        case .overlast:    return .pink
        case .anders:      return AppColors.primaryBlue
        }
    }

    /// Voor MapKit (pins)
    var uiColor: UIColor {
        UIColor(color)
    }

    /// Lookup vanuit Firestore string (fallback op .anders)
    static func from(_ raw: String?) -> ReportCategory {
        guard let raw, let c = ReportCategory(rawValue: raw) else { return .anders }
        return c
    }
}
