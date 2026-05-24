import AppKit
import ApplicationServices
import Foundation

final class SelectionCaptureService {
    private let commandCKeyCode: CGKeyCode = 8

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

        if selectedTextResult == .success,
           let selectedText = selectedTextObject as? String,
           !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return selectedText
        }

        return try selectedTextFromClipboardCopyFallback()
    }

    func currentMouseLocation() -> NSPoint {
        NSEvent.mouseLocation
    }

    private func selectedTextFromClipboardCopyFallback() throws -> String {
        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot.capture(from: pasteboard)

        waitForShortcutModifiersToClear()
        pasteboard.clearContents()
        let emptyChangeCount = pasteboard.changeCount
        postCommandC()

        let deadline = Date().addingTimeInterval(0.6)
        var copiedText: String?
        while Date() < deadline {
            if pasteboard.changeCount != emptyChangeCount,
               let text = pasteboard.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                copiedText = text
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        }

        snapshot.restore(to: pasteboard)

        guard let copiedText else {
            throw AppError.selectionUnavailable
        }

        return copiedText
    }

    private func waitForShortcutModifiersToClear() {
        let deadline = Date().addingTimeInterval(0.8)
        while Date() < deadline {
            let flags = CGEventSource.flagsState(.hidSystemState)
            let shortcutModifiersAreDown = flags.contains(.maskControl)
                || flags.contains(.maskAlternate)
                || flags.contains(.maskCommand)
                || flags.contains(.maskShift)

            if !shortcutModifiersAreDown {
                return
            }

            Thread.sleep(forTimeInterval: 0.03)
        }
    }

    private func postCommandC() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: commandCKeyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: commandCKeyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

private struct ClipboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> ClipboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            item.types.reduce(into: [NSPasteboard.PasteboardType: Data]()) { result, type in
                result[type] = item.data(forType: type)
            }
        } ?? []

        return ClipboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()

        let restoredItems = items.map { storedItem in
            let item = NSPasteboardItem()
            for (type, data) in storedItem {
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(restoredItems)
    }
}
