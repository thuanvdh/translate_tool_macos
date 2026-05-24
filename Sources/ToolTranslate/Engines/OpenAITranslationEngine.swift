import Foundation

final class OpenAITranslationEngine: TranslationEngine {
    let id = "openai"
    let displayName = "OpenAI"

    private let apiKeyProvider: () throws -> String?
    private let session: URLSession
    private let endpoint = URL(string: "https://api.openai.com/v1/responses")!
    private let model = "gpt-4.1-mini"

    init(
        apiKeyProvider: @escaping () throws -> String?,
        session: URLSession = .shared
    ) {
        self.apiKeyProvider = apiKeyProvider
        self.session = session
    }

    func translateToVietnamese(
        text: String,
        options: TranslationOptions
    ) async throws -> TranslationResult {
        let started = Date()
        guard let apiKey = try apiKeyProvider(), !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.missingAPIKey
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(makeRequestBody(text: text))

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw AppError.timeout
        } catch {
            throw AppError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401, 403:
            throw AppError.unauthorized
        case 429:
            throw AppError.rateLimited
        default:
            throw AppError.network("OpenAI returned HTTP \(httpResponse.statusCode)")
        }

        let translatedText = try parseTranslatedText(from: data)
        return TranslationResult(
            translatedText: translatedText,
            detectedSourceLanguage: nil,
            engineID: id,
            duration: Date().timeIntervalSince(started)
        )
    }

    private func makeRequestBody(text: String) -> OpenAIResponsesRequest {
        OpenAIResponsesRequest(
            model: model,
            input: [
                .init(
                    role: "system",
                    content: "Translate the user's text into natural Vietnamese. Preserve proper nouns, code, commands, API names, file paths, and technical terms. Return only the Vietnamese translation."
                ),
                .init(role: "user", content: text)
            ],
            temperature: 0.2
        )
    }

    private func parseTranslatedText(from data: Data) throws -> String {
        let response = try JSONDecoder().decode(OpenAIResponsesResponse.self, from: data)
        let text = response.output
            .flatMap(\.content)
            .first(where: { $0.type == "output_text" })?
            .text?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let text, !text.isEmpty else {
            throw AppError.invalidResponse
        }

        return text
    }
}

private struct OpenAIResponsesRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    let model: String
    let input: [Message]
    let temperature: Double
}

private struct OpenAIResponsesResponse: Decodable {
    struct Output: Decodable {
        let content: [Content]
    }

    struct Content: Decodable {
        let type: String
        let text: String?
    }

    let output: [Output]
}
