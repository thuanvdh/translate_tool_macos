import Foundation

protocol TranslationEngine {
    var id: String { get }
    var displayName: String { get }

    func translateToVietnamese(
        text: String,
        options: TranslationOptions
    ) async throws -> TranslationResult
}

struct TranslationOptions: Equatable {
    enum Style: Equatable {
        case natural
    }

    let targetLanguage: String
    let style: Style
    let maxInputCharacters: Int

    static func vietnameseNatural(maxInputCharacters: Int) -> TranslationOptions {
        TranslationOptions(
            targetLanguage: "vi",
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
