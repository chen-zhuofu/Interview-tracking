import Foundation
import SwiftUI
import Combine

/// App UI language. Default is English.
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case english = "en"
    case chinese = "zh"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .english: return Locale(identifier: "en_US")
        case .chinese: return Locale(identifier: "zh_CN")
        }
    }

    /// Label shown in the language picker (always bilingual so either side can find it).
    var pickerLabel: String {
        switch self {
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    static let storageKey = "appLanguage"

    nonisolated static var current: AppLanguage {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? AppLanguage.english.rawValue
        return AppLanguage(rawValue: raw) ?? .english
    }
}

/// Observes and persists the UI language. Inject as `@EnvironmentObject`.
final class LanguageStore: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        }
    }

    init() {
        language = AppLanguage.current
    }

    /// Pick English or Chinese copy. Prefer calling from View bodies so SwiftUI refreshes on change.
    func t(_ english: String, _ chinese: String) -> String {
        language == .chinese ? chinese : english
    }
}

/// Convenience for non-View call sites (models / helpers). Not reactive — Views should use `LanguageStore`.
enum L10n {
    nonisolated static func t(_ english: String, _ chinese: String) -> String {
        AppLanguage.current == .chinese ? chinese : english
    }
}
