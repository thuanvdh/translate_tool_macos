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

    var keyDisplayName: String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Escape: return "⎋"
        case kVK_Delete: return "⌫"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        default:
            break
        }

        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return "?"
        }
        
        let layoutDataRef = unsafeBitCast(layoutData, to: CFData.self)
        let layoutBytes = unsafeBitCast(CFDataGetBytePtr(layoutDataRef), to: UnsafePointer<UCKeyboardLayout>.self)
        
        var deadKeys: UInt32 = 0
        var unicodeStringLength = 0
        var unicodeString = [UniChar](repeating: 0, count: 4)
        
        let status = UCKeyTranslate(
            layoutBytes,
            UInt16(keyCode),
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeys,
            4,
            &unicodeStringLength,
            &unicodeString
        )
        
        if status == noErr && unicodeStringLength > 0 {
            return String(utf16CodeUnits: unicodeString, count: unicodeStringLength).uppercased()
        }
        return "?"
    }

    var displayName: String {
        var parts: [String] = []
        if modifiers.contains(.control) { parts.append("⌃") }
        if modifiers.contains(.option) { parts.append("⌥") }
        if modifiers.contains(.shift) { parts.append("⇧") }
        if modifiers.contains(.command) { parts.append("⌘") }
        parts.append(keyDisplayName)
        return parts.joined(separator: " ")
    }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) { value |= UInt32(cmdKey) }
        if modifiers.contains(.option) { value |= UInt32(optionKey) }
        if modifiers.contains(.control) { value |= UInt32(controlKey) }
        if modifiers.contains(.shift) { value |= UInt32(shiftKey) }
        return value
    }

    func save(to defaults: UserDefaults = .standard, key: String = "AppTranslationShortcut") {
        defaults.set(Int(keyCode), forKey: "\(key)_keyCode")
        defaults.set(Int(modifiers.rawValue), forKey: "\(key)_modifiers")
    }

    static func load(from defaults: UserDefaults = .standard, key: String = "AppTranslationShortcut") -> AppShortcut? {
        guard defaults.object(forKey: "\(key)_keyCode") != nil else { return nil }
        let keyCode = defaults.integer(forKey: "\(key)_keyCode")
        let modifiersRaw = defaults.integer(forKey: "\(key)_modifiers")
        return AppShortcut(keyCode: UInt32(keyCode), modifiers: Modifiers(rawValue: UInt(modifiersRaw)))
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
            { _, _, userData in
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

        let hotKeyID = EventHotKeyID(signature: OSType(0x54524E53), id: 1)
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
