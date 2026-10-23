import Foundation

/// The UI language. `.system` leaves the choice to macOS; the others pin the app through the
/// AppleLanguages default, which AppKit reads at launch.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case japanese

    var id: String { rawValue }

    /// Lets SwiftUI views switch language without a relaunch.
    var locale: Locale {
        switch self {
        case .system: .current
        case .english: Locale(identifier: "en")
        case .japanese: Locale(identifier: "ja")
        }
    }

    /// Each language names itself, so neither row needs translating.
    var displayName: String {
        switch self {
        case .system: String(localized: "System default")
        case .english: "English"
        case .japanese: "日本語"
        }
    }
}
