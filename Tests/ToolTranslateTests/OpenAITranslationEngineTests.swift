import Foundation
import XCTest
@testable import ToolTranslate

final class OpenAITranslationEngineTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testBuildsRequestAndParsesTranslation() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://api.openai.com/v1/responses")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-test")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

            let body = try XCTUnwrap(requestBodyData(from: request))
            let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            XCTAssertEqual(json?["model"] as? String, "gpt-4.1-mini")
            XCTAssertTrue(String(data: body, encoding: .utf8)?.contains("Translate the user's text into natural Vietnamese") == true)

            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            let data = """
            {
              "output": [
                {
                  "content": [
                    { "type": "output_text", "text": "Xin chao the gioi" }
                  ]
                }
              ]
            }
            """.data(using: .utf8)!
            return (response, data)
        }

        let engine = OpenAITranslationEngine(
            apiKeyProvider: { "sk-test" },
            session: .mocked
        )

        let result = try await engine.translate(
            text: "Hello world",
            options: .natural(target: .vietnamese, maxInputCharacters: 6000)
        )

        XCTAssertEqual(result.translatedText, "Xin chao the gioi")
        XCTAssertEqual(result.engineID, "openai")
        XCTAssertNil(result.detectedSourceLanguage)
        XCTAssertGreaterThanOrEqual(result.duration, 0)
    }

    func testMissingAPIKeyThrows() async {
        let engine = OpenAITranslationEngine(
            apiKeyProvider: { nil },
            session: .mocked
        )

        do {
            _ = try await engine.translate(
                text: "Hello",
                options: .natural(target: .vietnamese, maxInputCharacters: 6000)
            )
            XCTFail("Expected missing API key")
        } catch let error as AppError {
            XCTAssertEqual(error, .missingAPIKey)
        } catch {
            XCTFail("Expected AppError.missingAPIKey, got \(error)")
        }
    }

    func testMapsUnauthorizedStatus() async {
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let engine = OpenAITranslationEngine(
            apiKeyProvider: { "sk-test" },
            session: .mocked
        )

        do {
            _ = try await engine.translate(
                text: "Hello",
                options: .natural(target: .vietnamese, maxInputCharacters: 6000)
            )
            XCTFail("Expected unauthorized error")
        } catch let error as AppError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Expected AppError.unauthorized, got \(error)")
        }
    }
}

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: AppError.invalidResponse)
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private extension URLSession {
    static var mocked: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private func requestBodyData(from request: URLRequest) -> Data? {
    if let httpBody = request.httpBody {
        return httpBody
    }

    guard let stream = request.httpBodyStream else {
        return nil
    }

    stream.open()
    defer { stream.close() }

    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 1_024)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count < 0 {
            return nil
        }
        if count == 0 {
            break
        }
        data.append(buffer, count: count)
    }

    return data
}
