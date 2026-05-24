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
