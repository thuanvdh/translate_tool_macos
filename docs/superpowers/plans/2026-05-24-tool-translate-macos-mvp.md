# Tool Translate macOS MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that translates selected text into natural Vietnamese using OpenAI, with mini-input fallback and no local history.

**Architecture:** Use a Swift Package executable for the MVP so build and tests stay simple and CI-friendly. The app uses AppKit for the status item, global hotkey, floating popup, Accessibility checks, and Keychain integration, while translation logic is isolated behind a small `TranslationEngine` protocol.

**Tech Stack:** Swift 5.9+, Swift Package Manager, AppKit, Security/Keychain, ApplicationServices Accessibility APIs, URLSession, XCTest, GitHub Actions macOS runner.

---

## File Structure

- Create `Package.swift`: SwiftPM package definition, executable target, test target, macOS platform.
- Create `Sources/ToolTranslate/main.swift`: app entry point.
- Create `Sources/ToolTranslate/App/AppDelegate.swift`: app lifecycle, status item, dependency wiring.
- Create `Sources/ToolTranslate/App/AppCoordinator.swift`: coordinates shortcut/menu action, capture, translation, popup state.
- Create `Sources/ToolTranslate/App/AppError.swift`: user-facing typed errors.
- Create `Sources/ToolTranslate/Engines/TranslationEngine.swift`: engine protocol and shared translation models.
- Create `Sources/ToolTranslate/Engines/OpenAITranslationEngine.swift`: OpenAI HTTP implementation.
- Create `Sources/ToolTranslate/Services/TranslationService.swift`: validation, timeout, and engine orchestration.
- Create `Sources/ToolTranslate/Services/SelectionCaptureService.swift`: Accessibility permission and selected-text capture.
- Create `Sources/ToolTranslate/Security/KeychainStore.swift`: API key persistence.
- Create `Sources/ToolTranslate/Shortcut/ShortcutManager.swift`: default and configurable global shortcut support.
- Create `Sources/ToolTranslate/Popup/TranslationPopupWindowController.swift`: floating popup window.
- Create `Sources/ToolTranslate/Popup/TranslationPopupViewController.swift`: AppKit popup UI states.
- Create `Sources/ToolTranslate/Settings/SettingsWindowController.swift`: API key and shortcut settings UI.
- Create `Tests/ToolTranslateTests/TranslationServiceTests.swift`: service validation and orchestration tests.
- Create `Tests/ToolTranslateTests/OpenAITranslationEngineTests.swift`: request/response/error mapping tests with mock URL protocol.
- Create `Tests/ToolTranslateTests/KeychainStoreTests.swift`: Keychain save/load/delete tests with test service name.
- Create `Tests/ToolTranslateTests/ShortcutManagerTests.swift`: default shortcut encoding tests.
- Create `README.md`: setup, run, privacy, limitations.
- Create `.github/workflows/ci.yml`: macOS build and test workflow.
- Create `.github/ISSUE_TEMPLATE/bug_report.md`: bug report template.
- Create `.github/ISSUE_TEMPLATE/feature_request.md`: feature request template.
- Create `docs/RELEASE_CHECKLIST.md`: manual release checklist for unsigned MVP builds.

---

## Prerequisite: Initialize Git Repository

The current workspace is not a git repository. Initialize git before starting Task 1 so the commit steps work.

- [x] **Step 1: Initialize git**

Run:

```bash
git init
```

Expected: command exits with status 0 and creates `.git/`.

- [x] **Step 2: Commit existing design artifacts**

Run:

```bash
git add DESIGN.md skills-lock.json docs/superpowers/plans/2026-05-24-tool-translate-macos-mvp.md
git commit -m "docs: add tool translate design and implementation plan"
```

Expected: commit succeeds and records the design plus this plan.

---

## Task 1: Scaffold Swift Package

**Files:**
- Create: `Package.swift`
- Create: `Sources/ToolTranslate/main.swift`
- Create: `Sources/ToolTranslate/App/AppDelegate.swift`
- Create: `Tests/ToolTranslateTests/SmokeTests.swift`

- [x] **Step 1: Create package directories**

Run:

```bash
mkdir -p Sources/ToolTranslate/App Tests/ToolTranslateTests
```

Expected: command exits with status 0.

- [x] **Step 2: Create `Package.swift`**

Create `Package.swift` with:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ToolTranslate",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ToolTranslate", targets: ["ToolTranslate"])
    ],
    targets: [
        .executableTarget(
            name: "ToolTranslate",
            path: "Sources/ToolTranslate"
        ),
        .testTarget(
            name: "ToolTranslateTests",
            dependencies: ["ToolTranslate"],
            path: "Tests/ToolTranslateTests"
        )
    ]
)
```

- [x] **Step 3: Create app entry point**

Create `Sources/ToolTranslate/main.swift` with:

```swift
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
```

- [x] **Step 4: Create minimal app delegate**

Create `Sources/ToolTranslate/App/AppDelegate.swift` with:

```swift
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "VI"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Translate Selection", action: #selector(translateSelection), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    @objc private func translateSelection() {
        NSLog("Translate Selection selected")
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
```

- [x] **Step 5: Add smoke test**

Create `Tests/ToolTranslateTests/SmokeTests.swift` with:

```swift
import XCTest
@testable import ToolTranslate

final class SmokeTests: XCTestCase {
    func testTestTargetCanImportExecutableTarget() {
        XCTAssertTrue(true)
    }
}
```

- [x] **Step 6: Build and test**

Run:

```bash
swift test
```

Expected: PASS with `Executed 1 test`.

- [x] **Step 7: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "chore: scaffold macos swift package"
```

---

## Task 2: Translation Models and Service

**Files:**
- Create: `Sources/ToolTranslate/App/AppError.swift`
- Create: `Sources/ToolTranslate/Engines/TranslationEngine.swift`
- Create: `Sources/ToolTranslate/Services/TranslationService.swift`
- Create: `Tests/ToolTranslateTests/TranslationServiceTests.swift`

- [x] **Step 1: Write failing service tests**

Create `Tests/ToolTranslateTests/TranslationServiceTests.swift` with:

```swift
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
```

- [x] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter TranslationServiceTests
```

Expected: FAIL because `TranslationService`, `TranslationEngine`, and `AppError` are not defined.

- [x] **Step 3: Add user-facing app errors**

Create `Sources/ToolTranslate/App/AppError.swift` with:

```swift
import Foundation

enum AppError: Error, Equatable, LocalizedError {
    case emptyInput
    case inputTooLong(limit: Int)
    case missingAPIKey
    case accessibilityPermissionMissing
    case selectionUnavailable
    case unauthorized
    case rateLimited
    case network(String)
    case timeout
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "No text was provided."
        case .inputTooLong(let limit):
            return "Selected text is too long. Please select up to \(limit) characters."
        case .missingAPIKey:
            return "OpenAI API key is missing."
        case .accessibilityPermissionMissing:
            return "Accessibility permission is required to read selected text."
        case .selectionUnavailable:
            return "Selected text could not be read from the current app."
        case .unauthorized:
            return "OpenAI rejected the API key."
        case .rateLimited:
            return "OpenAI rate limit reached. Please try again later."
        case .network(let message):
            return "Network error: \(message)"
        case .timeout:
            return "The translation request timed out."
        case .invalidResponse:
            return "The translation response could not be read."
        }
    }
}
```

- [x] **Step 4: Add translation engine models**

Create `Sources/ToolTranslate/Engines/TranslationEngine.swift` with:

```swift
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
```

- [x] **Step 5: Add translation service**

Create `Sources/ToolTranslate/Services/TranslationService.swift` with:

```swift
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
```

- [x] **Step 6: Run tests**

Run:

```bash
swift test --filter TranslationServiceTests
```

Expected: PASS for all `TranslationServiceTests`.

- [x] **Step 7: Commit**

```bash
git add Sources/ToolTranslate/App Sources/ToolTranslate/Engines Sources/ToolTranslate/Services Tests/ToolTranslateTests/TranslationServiceTests.swift
git commit -m "feat: add translation service contract"
```

---

## Task 3: Keychain API Key Storage

**Files:**
- Create: `Sources/ToolTranslate/Security/KeychainStore.swift`
- Create: `Tests/ToolTranslateTests/KeychainStoreTests.swift`

- [x] **Step 1: Write failing Keychain tests**

Create `Tests/ToolTranslateTests/KeychainStoreTests.swift` with:

```swift
import XCTest
@testable import ToolTranslate

final class KeychainStoreTests: XCTestCase {
    private let service = "dev.tooltranslate.tests"

    override func tearDown() {
        try? KeychainStore(service: service).deleteAPIKey()
        super.tearDown()
    }

    func testSaveAndLoadAPIKey() throws {
        let store = KeychainStore(service: service)

        try store.saveAPIKey("sk-test-key")

        XCTAssertEqual(try store.loadAPIKey(), "sk-test-key")
    }

    func testDeleteAPIKey() throws {
        let store = KeychainStore(service: service)
        try store.saveAPIKey("sk-test-key")

        try store.deleteAPIKey()

        XCTAssertNil(try store.loadAPIKey())
    }

    func testSavingSecondKeyReplacesFirstKey() throws {
        let store = KeychainStore(service: service)

        try store.saveAPIKey("sk-first")
        try store.saveAPIKey("sk-second")

        XCTAssertEqual(try store.loadAPIKey(), "sk-second")
    }
}
```

- [x] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter KeychainStoreTests
```

Expected: FAIL because `KeychainStore` is not defined.

- [x] **Step 3: Add Keychain store**

Create `Sources/ToolTranslate/Security/KeychainStore.swift` with:

```swift
import Foundation
import Security

final class KeychainStore {
    private let service: String
    private let account = "openai-api-key"

    init(service: String = "dev.tooltranslate") {
        self.service = service
    }

    func saveAPIKey(_ apiKey: String) throws {
        let data = Data(apiKey.utf8)
        let query = baseQuery()

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw AppError.network("Keychain update failed with status \(updateStatus)")
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw AppError.network("Keychain save failed with status \(addStatus)")
        }
    }

    func loadAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data else {
            throw AppError.network("Keychain load failed with status \(status)")
        }

        return String(data: data, encoding: .utf8)
    }

    func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw AppError.network("Keychain delete failed with status \(status)")
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
```

- [x] **Step 4: Run tests**

Run:

```bash
swift test --filter KeychainStoreTests
```

Expected: PASS for all `KeychainStoreTests`.

- [x] **Step 5: Commit**

```bash
git add Sources/ToolTranslate/Security Tests/ToolTranslateTests/KeychainStoreTests.swift
git commit -m "feat: store api key in keychain"
```

---

## Task 4: OpenAI Translation Engine

**Files:**
- Create: `Sources/ToolTranslate/Engines/OpenAITranslationEngine.swift`
- Create: `Tests/ToolTranslateTests/OpenAITranslationEngineTests.swift`

- [x] **Step 1: Write failing OpenAI engine tests**

Create `Tests/ToolTranslateTests/OpenAITranslationEngineTests.swift` with:

```swift
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

            let body = try XCTUnwrap(request.httpBody)
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

        let result = try await engine.translateToVietnamese(
            text: "Hello world",
            options: .vietnameseNatural(maxInputCharacters: 6000)
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
            _ = try await engine.translateToVietnamese(
                text: "Hello",
                options: .vietnameseNatural(maxInputCharacters: 6000)
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
            _ = try await engine.translateToVietnamese(
                text: "Hello",
                options: .vietnameseNatural(maxInputCharacters: 6000)
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
```

- [x] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter OpenAITranslationEngineTests
```

Expected: FAIL because `OpenAITranslationEngine` is not defined.

- [x] **Step 3: Add OpenAI engine**

Create `Sources/ToolTranslate/Engines/OpenAITranslationEngine.swift` with:

```swift
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
            .text
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
```

- [x] **Step 4: Run engine tests**

Run:

```bash
swift test --filter OpenAITranslationEngineTests
```

Expected: PASS for all `OpenAITranslationEngineTests`.

- [x] **Step 5: Run all tests**

Run:

```bash
swift test
```

Expected: PASS for all tests.

- [x] **Step 6: Commit**

```bash
git add Sources/ToolTranslate/Engines/OpenAITranslationEngine.swift Tests/ToolTranslateTests/OpenAITranslationEngineTests.swift
git commit -m "feat: add openai translation engine"
```

---

## Task 5: Selection Capture and Accessibility Permission

**Files:**
- Create: `Sources/ToolTranslate/Services/SelectionCaptureService.swift`

- [x] **Step 1: Add selection capture service**

Create `Sources/ToolTranslate/Services/SelectionCaptureService.swift` with:

```swift
import AppKit
import ApplicationServices
import Foundation

final class SelectionCaptureService {
    func hasAccessibilityPermission(prompt: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func selectedText() throws -> String {
        guard hasAccessibilityPermission(prompt: false) else {
            throw AppError.accessibilityPermissionMissing
        }

        let systemWideElement = AXUIElementCreateSystemWide()
        var focusedObject: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedObject
        )

        guard focusedResult == .success, let focusedObject else {
            throw AppError.selectionUnavailable
        }

        let focusedElement = focusedObject as! AXUIElement
        var selectedTextObject: CFTypeRef?
        let selectedTextResult = AXUIElementCopyAttributeValue(
            focusedElement,
            kAXSelectedTextAttribute as CFString,
            &selectedTextObject
        )

        guard selectedTextResult == .success,
              let selectedText = selectedTextObject as? String,
              !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AppError.selectionUnavailable
        }

        return selectedText
    }

    func currentMouseLocation() -> NSPoint {
        NSEvent.mouseLocation
    }
}
```

- [x] **Step 2: Build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [x] **Step 3: Commit**

```bash
git add Sources/ToolTranslate/Services/SelectionCaptureService.swift
git commit -m "feat: add accessibility selection capture"
```

---

## Task 6: Shortcut Manager

**Files:**
- Create: `Sources/ToolTranslate/Shortcut/ShortcutManager.swift`
- Create: `Tests/ToolTranslateTests/ShortcutManagerTests.swift`

- [x] **Step 1: Write failing shortcut tests**

Create `Tests/ToolTranslateTests/ShortcutManagerTests.swift` with:

```swift
import XCTest
@testable import ToolTranslate

final class ShortcutManagerTests: XCTestCase {
    func testDefaultShortcutIsControlOptionT() {
        let shortcut = AppShortcut.default

        XCTAssertEqual(shortcut.keyCode, 17)
        XCTAssertTrue(shortcut.modifiers.contains(.control))
        XCTAssertTrue(shortcut.modifiers.contains(.option))
        XCTAssertFalse(shortcut.modifiers.contains(.command))
        XCTAssertFalse(shortcut.modifiers.contains(.shift))
    }

    func testShortcutDisplayName() {
        XCTAssertEqual(AppShortcut.default.displayName, "Control + Option + T")
    }
}
```

- [x] **Step 2: Run tests to verify failure**

Run:

```bash
swift test --filter ShortcutManagerTests
```

Expected: FAIL because `AppShortcut` is not defined.

- [x] **Step 3: Add shortcut manager**

Create `Sources/ToolTranslate/Shortcut/ShortcutManager.swift` with:

```swift
import AppKit
import Carbon
import Foundation

struct AppShortcut: Equatable {
    struct Modifiers: OptionSet, Equatable {
        let rawValue: UInt

        static let command = Modifiers(rawValue: 1 << 0)
        static let option = Modifiers(rawValue: 1 << 1)
        static let control = Modifiers(rawValue: 1 << 2)
        static let shift = Modifiers(rawValue: 1 << 3)
    }

    let keyCode: UInt32
    let modifiers: Modifiers

    static let `default` = AppShortcut(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: [.control, .option]
    )

    var displayName: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("Control") }
        if modifiers.contains(.option) { parts.append("Option") }
        if modifiers.contains(.shift) { parts.append("Shift") }
        if modifiers.contains(.command) { parts.append("Command") }
        parts.append("T")
        return parts.joined(separator: " + ")
    }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) { value |= UInt32(cmdKey) }
        if modifiers.contains(.option) { value |= UInt32(optionKey) }
        if modifiers.contains(.control) { value |= UInt32(controlKey) }
        if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }
}

final class ShortcutManager {
    private var hotKeyRef: EventHotKeyRef?
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    deinit {
        unregister()
    }

    func register(shortcut: AppShortcut = .default) throws {
        unregister()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPointer = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<ShortcutManager>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                manager.handler()
                return noErr
            },
            1,
            &eventType,
            selfPointer,
            nil
        )

        var hotKeyID = EventHotKeyID(signature: OSType(0x54524E53), id: 1)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard status == noErr else {
            throw AppError.network("Shortcut registration failed with status \(status)")
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
```

- [x] **Step 4: Run shortcut tests**

Run:

```bash
swift test --filter ShortcutManagerTests
```

Expected: PASS for all `ShortcutManagerTests`.

- [x] **Step 5: Commit**

```bash
git add Sources/ToolTranslate/Shortcut Tests/ToolTranslateTests/ShortcutManagerTests.swift
git commit -m "feat: add configurable shortcut foundation"
```

---

## Task 7: Popup UI and Settings UI

**Files:**
- Create: `Sources/ToolTranslate/Popup/TranslationPopupViewController.swift`
- Create: `Sources/ToolTranslate/Popup/TranslationPopupWindowController.swift`
- Create: `Sources/ToolTranslate/Settings/SettingsWindowController.swift`

- [x] **Step 1: Add popup view controller**

Create `Sources/ToolTranslate/Popup/TranslationPopupViewController.swift` with:

```swift
import AppKit

enum PopupState: Equatable {
    case loading(String)
    case result(String)
    case error(String)
    case input(prompt: String)
}

final class TranslationPopupViewController: NSViewController {
    var onSubmitInput: ((String) -> Void)?
    var onCopy: ((String) -> Void)?

    private let stack = NSStackView()
    private let textView = NSTextView()
    private let inputField = NSTextField()
    private let primaryButton = NSButton(title: "Copy", target: nil, action: nil)
    private var currentText = ""

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 180))
        view.wantsLayer = true
        view.layer?.cornerRadius = 8
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        stack.orientation = .vertical
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        stack.translatesAutoresizingMaskIntoConstraints = false

        textView.isEditable = false
        textView.drawsBackground = false
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 0, height: 0)

        inputField.placeholderString = "Paste text to translate"
        inputField.target = self
        inputField.action = #selector(submitInput)

        primaryButton.target = self
        primaryButton.action = #selector(copyCurrentText)

        stack.addArrangedSubview(textView)
        stack.addArrangedSubview(inputField)
        stack.addArrangedSubview(primaryButton)
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.heightAnchor.constraint(greaterThanOrEqualToConstant: 90)
        ])

        render(.loading("Ready"))
    }

    func render(_ state: PopupState) {
        switch state {
        case .loading(let message):
            currentText = message
            textView.string = message
            inputField.isHidden = true
            primaryButton.isHidden = true
        case .result(let translation):
            currentText = translation
            textView.string = translation
            inputField.isHidden = true
            primaryButton.title = "Copy"
            primaryButton.isHidden = false
        case .error(let message):
            currentText = message
            textView.string = message
            inputField.isHidden = true
            primaryButton.isHidden = true
        case .input(let prompt):
            currentText = ""
            textView.string = prompt
            inputField.stringValue = ""
            inputField.isHidden = false
            primaryButton.title = "Translate"
            primaryButton.isHidden = false
        }
    }

    @objc private func submitInput() {
        let text = inputField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        onSubmitInput?(text)
    }

    @objc private func copyCurrentText() {
        if inputField.isHidden {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(currentText, forType: .string)
            onCopy?(currentText)
        } else {
            submitInput()
        }
    }
}
```

- [x] **Step 2: Add popup window controller**

Create `Sources/ToolTranslate/Popup/TranslationPopupWindowController.swift` with:

```swift
import AppKit

final class TranslationPopupWindowController: NSWindowController {
    let popupViewController = TranslationPopupViewController()

    init() {
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 180),
            styleMask: [.nonactivatingPanel, .titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = popupViewController
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.hidesOnDeactivate = false
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(state: PopupState, near point: NSPoint) {
        popupViewController.render(state)
        let origin = NSPoint(x: point.x + 12, y: point.y - 200)
        window?.setFrameOrigin(origin)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func update(state: PopupState) {
        popupViewController.render(state)
    }
}
```

- [x] **Step 3: Add settings window**

Create `Sources/ToolTranslate/Settings/SettingsWindowController.swift` with:

```swift
import AppKit

final class SettingsWindowController: NSWindowController {
    private let apiKeyField = NSSecureTextField()
    private let shortcutLabel = NSTextField(labelWithString: AppShortcut.default.displayName)
    private let statusLabel = NSTextField(labelWithString: "")
    private let keychainStore: KeychainStore

    init(keychainStore: KeychainStore) {
        self.keychainStore = keychainStore

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Tool Translate Settings"
        super.init(window: window)
        window.contentView = makeContentView()
        loadSavedKey()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func makeContentView() -> NSView {
        let root = NSStackView()
        root.orientation = .vertical
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)

        apiKeyField.placeholderString = "OpenAI API key"

        let saveButton = NSButton(title: "Save API Key", target: self, action: #selector(saveAPIKey))
        let shortcutText = NSTextField(labelWithString: "Shortcut")
        let privacyText = NSTextField(labelWithString: "Privacy: selected text is sent to OpenAI for translation. This app does not store history or cache translations.")
        privacyText.lineBreakMode = .byWordWrapping
        privacyText.maximumNumberOfLines = 3

        root.addArrangedSubview(NSTextField(labelWithString: "OpenAI API Key"))
        root.addArrangedSubview(apiKeyField)
        root.addArrangedSubview(saveButton)
        root.addArrangedSubview(shortcutText)
        root.addArrangedSubview(shortcutLabel)
        root.addArrangedSubview(privacyText)
        root.addArrangedSubview(statusLabel)

        return root
    }

    private func loadSavedKey() {
        do {
            if let key = try keychainStore.loadAPIKey(), !key.isEmpty {
                apiKeyField.stringValue = key
            }
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func saveAPIKey() {
        do {
            try keychainStore.saveAPIKey(apiKeyField.stringValue)
            statusLabel.stringValue = "API key saved."
        } catch {
            statusLabel.stringValue = error.localizedDescription
        }
    }
}
```

- [x] **Step 4: Build**

Run:

```bash
swift build
```

Expected: build succeeds.

- [x] **Step 5: Commit**

```bash
git add Sources/ToolTranslate/Popup Sources/ToolTranslate/Settings
git commit -m "feat: add popup and settings windows"
```

---

## Task 8: App Coordinator Wiring

**Files:**
- Create: `Sources/ToolTranslate/App/AppCoordinator.swift`
- Modify: `Sources/ToolTranslate/App/AppDelegate.swift`

- [x] **Step 1: Add app coordinator**

Create `Sources/ToolTranslate/App/AppCoordinator.swift` with:

```swift
import AppKit

@MainActor
final class AppCoordinator {
    private let selectionCaptureService: SelectionCaptureService
    private let translationService: TranslationService
    private let popupWindowController: TranslationPopupWindowController
    private let settingsWindowController: SettingsWindowController

    init(
        selectionCaptureService: SelectionCaptureService,
        translationService: TranslationService,
        popupWindowController: TranslationPopupWindowController,
        settingsWindowController: SettingsWindowController
    ) {
        self.selectionCaptureService = selectionCaptureService
        self.translationService = translationService
        self.popupWindowController = popupWindowController
        self.settingsWindowController = settingsWindowController

        popupWindowController.popupViewController.onSubmitInput = { [weak self] text in
            Task { @MainActor in
                await self?.translate(text: text)
            }
        }
    }

    func translateSelection() {
        let point = selectionCaptureService.currentMouseLocation()

        do {
            let text = try selectionCaptureService.selectedText()
            popupWindowController.show(state: .loading("Translating..."), near: point)
            Task { @MainActor in
                await translate(text: text)
            }
        } catch AppError.accessibilityPermissionMissing {
            _ = selectionCaptureService.hasAccessibilityPermission(prompt: true)
            popupWindowController.show(
                state: .error("Enable Accessibility permission for Tool Translate in System Settings, then try again."),
                near: point
            )
        } catch AppError.selectionUnavailable {
            popupWindowController.show(
                state: .input(prompt: "Could not read selected text. Paste text here and press Return."),
                near: point
            )
        } catch {
            popupWindowController.show(
                state: .error(error.localizedDescription),
                near: point
            )
        }
    }

    func showSettings() {
        settingsWindowController.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func translate(text: String) async {
        popupWindowController.update(state: .loading("Translating..."))

        do {
            let result = try await translationService.translateToVietnamese(text)
            popupWindowController.update(state: .result(result.translatedText))
        } catch AppError.missingAPIKey {
            popupWindowController.update(state: .error("Open Settings and save your OpenAI API key."))
            showSettings()
        } catch {
            popupWindowController.update(state: .error(error.localizedDescription))
        }
    }
}
```

- [x] **Step 2: Replace app delegate with wired version**

Replace `Sources/ToolTranslate/App/AppDelegate.swift` with:

```swift
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var coordinator: AppCoordinator?
    private var shortcutManager: ShortcutManager?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let keychainStore = KeychainStore()
        let engine = OpenAITranslationEngine(apiKeyProvider: {
            try keychainStore.loadAPIKey()
        })
        let translationService = TranslationService(engine: engine)
        let popup = TranslationPopupWindowController()
        let settings = SettingsWindowController(keychainStore: keychainStore)
        let selection = SelectionCaptureService()

        let coordinator = AppCoordinator(
            selectionCaptureService: selection,
            translationService: translationService,
            popupWindowController: popup,
            settingsWindowController: settings
        )
        self.coordinator = coordinator

        setupStatusItem()
        setupShortcut(coordinator: coordinator)
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.title = "VI"

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Translate Selection", action: #selector(translateSelection), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(showSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        item.menu = menu
        statusItem = item
    }

    private func setupShortcut(coordinator: AppCoordinator) {
        let manager = ShortcutManager {
            Task { @MainActor in
                coordinator.translateSelection()
            }
        }

        do {
            try manager.register(shortcut: .default)
        } catch {
            NSLog("Shortcut registration failed: \(error.localizedDescription)")
        }

        shortcutManager = manager
    }

    @objc private func translateSelection() {
        coordinator?.translateSelection()
    }

    @objc private func showSettings() {
        coordinator?.showSettings()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
```

- [x] **Step 3: Build and test**

Run:

```bash
swift test
```

Expected: PASS for all tests.

- [x] **Step 4: Manual run**

Run:

```bash
swift run ToolTranslate
```

Expected: app starts, a `VI` menu bar item appears, Settings opens from the menu, and `Control + Option + T` triggers the translate flow. Stop with `Control + C` in the terminal after manual verification.

- [x] **Step 5: Commit**

```bash
git add Sources/ToolTranslate/App/AppCoordinator.swift Sources/ToolTranslate/App/AppDelegate.swift
git commit -m "feat: wire menu bar translation flow"
```

---

## Task 9: Documentation and Open Source Project Files

**Files:**
- Create: `README.md`
- Create: `.github/ISSUE_TEMPLATE/bug_report.md`
- Create: `.github/ISSUE_TEMPLATE/feature_request.md`
- Create: `docs/RELEASE_CHECKLIST.md`

- [x] **Step 1: Create README**

Create `README.md` with:

```markdown
# Tool Translate

Tool Translate is a native macOS menu bar app that translates selected text into Vietnamese.

## MVP Features

- Menu bar app with `VI` status item.
- Global shortcut: `Control + Option + T`.
- OpenAI-powered translation into natural Vietnamese.
- Popup result window with copy support.
- Mini input fallback when selected text cannot be captured.
- API key stored in macOS Keychain.
- No local translation history and no translation cache.

## Requirements

- macOS 13 or newer.
- Swift 5.9 or newer.
- An OpenAI API key.

## Run From Source

```bash
swift test
swift run ToolTranslate
```

After launch, open the `VI` menu bar item, choose Settings, and save your OpenAI API key.

## Accessibility Permission

Tool Translate needs macOS Accessibility permission to read selected text from the focused application.

If translation fails with a permission message:

1. Open System Settings.
2. Go to Privacy & Security.
3. Open Accessibility.
4. Enable Tool Translate or the terminal app used to run it.
5. Try the shortcut again.

## Privacy

Tool Translate sends the selected text to OpenAI for translation. The app does not store translation history, does not cache translated content, and stores only the OpenAI API key in macOS Keychain.

## Known Limitations

- Selected-text capture may not work in every macOS app.
- When capture fails, use the mini input fallback.
- MVP source builds are not signed or notarized.
- Offline translation is not included in the MVP.

## Development

```bash
swift build
swift test
```

## Project Status

This project is in MVP development. See `DESIGN.md` for the design and `docs/superpowers/plans/2026-05-24-tool-translate-macos-mvp.md` for the implementation plan.
```

- [x] **Step 2: Create issue templates**

Create `.github/ISSUE_TEMPLATE/bug_report.md` with:

```markdown
---
name: Bug report
about: Report a reproducible problem in Tool Translate
title: "[Bug]: "
labels: bug
assignees: ""
---

## Environment

- macOS version:
- Swift version:
- App version or commit:
- App where text was selected:

## What happened?

Describe the problem.

## Steps to reproduce

1. 
2. 
3. 

## Expected behavior

Describe what you expected.

## Logs or screenshots

Paste relevant logs or attach screenshots.
```

Create `.github/ISSUE_TEMPLATE/feature_request.md` with:

```markdown
---
name: Feature request
about: Suggest an improvement for Tool Translate
title: "[Feature]: "
labels: enhancement
assignees: ""
---

## Problem

Describe the workflow or limitation this feature would improve.

## Proposed solution

Describe the behavior you want.

## Alternatives considered

Describe other approaches you considered.

## Additional context

Add examples, screenshots, or related links.
```

- [x] **Step 3: Create release checklist**

Create `docs/RELEASE_CHECKLIST.md` with:

```markdown
# Release Checklist

## Pre-release

- Run `swift test`.
- Run `swift build -c release`.
- Launch with `swift run ToolTranslate`.
- Verify Settings can save and reload an OpenAI API key.
- Verify `Control + Option + T` opens the translation popup.
- Verify selected text translation in Safari or Chrome.
- Verify selected text translation in VS Code.
- Verify selected text translation in Notes.
- Verify mini input fallback works.
- Verify README privacy text is accurate.

## MVP Distribution Note

This MVP is not signed or notarized. Users may see macOS security warnings when running downloaded builds. Document the exact install path used for any release artifact.
```

- [x] **Step 4: Commit**

```bash
git add README.md .github docs/RELEASE_CHECKLIST.md
git commit -m "docs: add open source project documentation"
```

---

## Task 10: CI Build and Test

**Files:**
- Create: `.github/workflows/ci.yml`

- [x] **Step 1: Create GitHub Actions workflow**

Create `.github/workflows/ci.yml` with:

```yaml
name: CI

on:
  push:
    branches:
      - main
  pull_request:

jobs:
  build-test:
    runs-on: macos-14
    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Show Swift version
        run: swift --version

      - name: Build
        run: swift build

      - name: Test
        run: swift test
```

- [x] **Step 2: Run local CI commands**

Run:

```bash
swift build
swift test
```

Expected: both commands pass locally.

- [x] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add macos build and test workflow"
```

---

## Task 11: Manual MVP Acceptance Pass

**Files:**
- Modify only if acceptance reveals a defect in files from earlier tasks.

- [x] **Step 1: Run full automated checks**

Run:

```bash
swift test
swift build -c release
```

Expected: both commands pass.

- [x] **Step 2: Launch app**

Run:

```bash
swift run ToolTranslate
```

Expected: `VI` appears in the macOS menu bar.

- [ ] **Step 3: Verify Settings and Keychain**

Manual check:

```text
Open VI menu -> Settings.
Enter an OpenAI API key.
Click Save API Key.
Close Settings.
Open Settings again.
Confirm the field is populated.
```

Expected: Settings reports `API key saved.` and reloads the key from Keychain.

- [ ] **Step 4: Verify selected-text translation**

Manual check:

```text
Open Notes.
Type or select: Hello, this is a test of Tool Translate.
Press Control + Option + T.
```

Expected: popup opens and shows a Vietnamese translation.

- [ ] **Step 5: Verify mini input fallback**

Manual check:

```text
Click an area with no selected text.
Press Control + Option + T.
Paste: Please translate this fallback input.
Press Return.
```

Expected: popup translates the manually pasted text.

- [x] **Step 6: Verify no history files are created**

Run:

```bash
find . -maxdepth 4 -type f | sort
```

Expected: no app-created translation history or cache files appear in the repository. Keychain data is outside the repo by design.

- [ ] **Step 7: Commit acceptance fixes**

If defects were fixed during acceptance:

```bash
git add Sources Tests README.md docs .github
git commit -m "fix: address mvp acceptance findings"
```

If no defects were found, do not create an empty commit.

---

## Self-Review

- Spec coverage: menu bar app, selected text translation, popup, OpenAI MVP, engine abstraction, mini input fallback, Keychain settings, no history/cache, README privacy note, basic CI, and release checklist are covered.
- Scope choice: this is one MVP plan. Signing, notarization, auto-update, telemetry, crash reporting, offline translation, and runtime plugin engines remain outside MVP scope as documented in `DESIGN.md`.
- Placeholder scan: the plan contains concrete file paths, code blocks, commands, expected results, and commit messages for every task.
- Type consistency: `AppError`, `TranslationEngine`, `TranslationOptions`, `TranslationResult`, `TranslationService`, `KeychainStore`, `OpenAITranslationEngine`, `SelectionCaptureService`, `ShortcutManager`, `TranslationPopupWindowController`, `SettingsWindowController`, and `AppCoordinator` names are consistent across tasks.
