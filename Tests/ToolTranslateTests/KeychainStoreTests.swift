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
