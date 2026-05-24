import Foundation

final class TranslationService {
    private let engine: TranslationEngine
    private let maxInputCharacters: Int

    init(engine: TranslationEngine, maxInputCharacters: Int = 6_000) {
        self.engine = engine
        self.maxInputCharacters = maxInputCharacters
    }

    func translateToVietnamese(_ rawText: String) async throws -> TranslationResult {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw AppError.emptyInput
        }

        guard text.count <= maxInputCharacters else {
            throw AppError.inputTooLong(limit: maxInputCharacters)
        }

        let options = TranslationOptions.vietnameseNatural(
            maxInputCharacters: maxInputCharacters
        )
        return try await engine.translateToVietnamese(text: text, options: options)
    }
}
