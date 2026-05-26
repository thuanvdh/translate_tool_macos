import Foundation

enum TargetLanguage: String, CaseIterable, Codable {
    case vietnamese = "vi"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case chinese = "zh"
    case french = "fr"
    case german = "de"

    var displayName: String {
        switch self {
        case .vietnamese: return "Tiếng Việt"
        case .english: return "Tiếng Anh"
        case .japanese: return "Tiếng Nhật"
        case .korean: return "Tiếng Hàn"
        case .chinese: return "Tiếng Trung"
        case .french: return "Tiếng Pháp"
        case .german: return "Tiếng Đức"
        }
    }

    var englishName: String {
        switch self {
        case .vietnamese: return "Vietnamese"
        case .english: return "English"
        case .japanese: return "Japanese"
        case .korean: return "Korean"
        case .chinese: return "Chinese"
        case .french: return "French"
        case .german: return "German"
        }
    }
}

extension UserDefaults {
    private static let targetLanguageKey = "com.tooltranslate.targetLanguage"

    var targetLanguage: TargetLanguage {
        get {
            guard let value = string(forKey: Self.targetLanguageKey),
                  let language = TargetLanguage(rawValue: value) else {
                return .vietnamese
            }
            return language
        }
        set {
            set(newValue.rawValue, forKey: Self.targetLanguageKey)
        }
    }
}

protocol TranslationEngine {
    var id: String { get }
    var displayName: String { get }

    func translate(
        text: String,
        options: TranslationOptions
    ) async throws -> TranslationResult
}

struct TranslationOptions: Equatable {
    enum Style: Equatable {
        case natural
    }

    let targetLanguage: TargetLanguage
    let style: Style
    let maxInputCharacters: Int

    static func natural(target: TargetLanguage, maxInputCharacters: Int) -> TranslationOptions {
        TranslationOptions(
            targetLanguage: target,
            style: .natural,
            maxInputCharacters: maxInputCharacters
        )
    }
}

struct TranslationResult: Equatable {
    let translatedText: String
    let detectedSourceLanguage: String?
    let engineID: String
    let duration: TimeInterval
}
