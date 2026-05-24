import XCTest
@testable import ToolTranslate

final class TranslationServiceTests: XCTestCase {
    func testRejectsEmptyInput() async {
        let engine = MockTranslationEngine(result: .success(.sample))
        let service = TranslationService(engine: engine, maxInputCharacters: 20)

        do {
            _ = try await service.translateToVietnamese("   ")
            XCTFail("Expected empty input to throw")
        } catch let error as AppError {
            XCTAssertEqual(error, .emptyInput)
        } catch {
            XCTFail("Expected AppError.emptyInput, got \(error)")
        }
    }

    func testRejectsTextOverLimit() async {
        let engine = MockTranslationEngine(result: .success(.sample))
        let service = TranslationService(engine: engine, maxInputCharacters: 5)

        do {
            _ = try await service.translateToVietnamese("abcdef")
            XCTFail("Expected long input to throw")
        } catch let error as AppError {
            XCTAssertEqual(error, .inputTooLong(limit: 5))
        } catch {
            XCTFail("Expected AppError.inputTooLong, got \(error)")
        }
    }

    func testTrimsInputBeforeCallingEngine() async throws {
        let engine = MockTranslationEngine(result: .success(.sample))
        let service = TranslationService(engine: engine, maxInputCharacters: 100)

        _ = try await service.translateToVietnamese("  hello world  ")

        XCTAssertEqual(engine.receivedText, "hello world")
        XCTAssertEqual(engine.receivedOptions?.targetLanguage, "vi")
        XCTAssertEqual(engine.receivedOptions?.style, .natural)
    }

    func testReturnsEngineResult() async throws {
        let expected = TranslationResult(
            translatedText: "Xin chao",
            detectedSourceLanguage: "en",
            engineID: "mock",
            duration: 0.2
        )
        let engine = MockTranslationEngine(result: .success(expected))
        let service = TranslationService(engine: engine, maxInputCharacters: 100)

        let actual = try await service.translateToVietnamese("hello")

        XCTAssertEqual(actual, expected)
    }
}

private final class MockTranslationEngine: TranslationEngine {
    let id = "mock"
    let displayName = "Mock"
    private let result: Result<TranslationResult, Error>
    private(set) var receivedText: String?
    private(set) var receivedOptions: TranslationOptions?

    init(result: Result<TranslationResult, Error>) {
        self.result = result
    }

    func translateToVietnamese(
        text: String,
        options: TranslationOptions
    ) async throws -> TranslationResult {
        receivedText = text
        receivedOptions = options
        return try result.get()
    }
}

private extension TranslationResult {
    static let sample = TranslationResult(
        translatedText: "Ban dich",
        detectedSourceLanguage: "en",
        engineID: "mock",
        duration: 0.1
    )
}
