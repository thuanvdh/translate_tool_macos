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
