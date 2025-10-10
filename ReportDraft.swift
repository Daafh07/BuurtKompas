//
//  ReportDraft.swift
//
//  Bronvermelding (APA 7):
//  Google. (2025). *Cloud Firestore data model documentation* [Developer documentation]. Firebase. https://firebase.google.com/docs/firestore
//  Apple Inc. (2025). *Core Location* [Developer documentation]. Apple Developer. https://developer.apple.com/documentation/corelocation
//  OpenAI. (2025). *ChatGPT (GPT-5)* [Large language model]. OpenAI. https://chat.openai.com/
//

import Foundation

struct ReportDraft {
    var title: String = ""
    var description: String = ""
    /// Opslag als rawValue van ReportCategory (bv. "vandalisme")
    var category: String = ReportCategory.anders.rawValue
    var isAnonymous: Bool = true

    var latitude: Double?
    var longitude: Double?
}
