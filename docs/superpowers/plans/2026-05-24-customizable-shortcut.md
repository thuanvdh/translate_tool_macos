# Customizable Translation Shortcut Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow users to customize the global shortcut key for triggering translation from the Settings window.

**Architecture:** We will implement a custom `ShortcutRecorderButton` in the Settings window that intercepts key events, converts them to an `AppShortcut` structure, and saves them to `UserDefaults`. When saved, the app posts a notification that `AppDelegate` listens to, prompting `ShortcutManager` to register the new global hotkey.

**Tech Stack:** Swift, AppKit, Carbon APIs (for event translation and global hotkeys).

---

### Task 1: Update AppShortcut with Serialization and Localized Name Mapping

**Files:**
- Modify: `Sources/ToolTranslate/Shortcut/ShortcutManager.swift`

- [ ] **Step 1: Add serialization methods and dynamic character resolving to AppShortcut**
  
  Extend the `AppShortcut` struct in `ShortcutManager.swift` to add:
  1. A helper getter `keyDisplayName` using `UCKeyTranslate` and `TISCopyCurrentKeyboardInputSource` to resolve physical keycodes to matching localized strings.
  2. Modify `displayName` to format modifier keys with standard premium symbols (⌘, ⌥, ⌃, ⇧) and output the dynamic key name.
  3. Implement `save(to:key:)` and `load(from:key:)` utilizing `UserDefaults`.

  ```swift
  // Code block to be integrated inside AppShortcut struct
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
      let layoutBytes = CFDataGetBytePtr(layoutDataRef)
      
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
  ```

- [ ] **Step 2: Build project and verify no compilation errors**
  
  Run: `swift build`
  Expected: Build complete!

---

### Task 2: Implement ShortcutRecorderButton and Update Settings UI

**Files:**
- Modify: `Sources/ToolTranslate/Settings/SettingsWindowController.swift`

- [ ] **Step 1: Implement ShortcutRecorderButton**
  
  Define `ShortcutRecorderButton` (a subclass of `NSButton`) in `SettingsWindowController.swift` or a new helper block. It handles clicks, monitors local keydown events, checks that at least one modifier key is used, and invokes a callback.

  ```swift
  final class ShortcutRecorderButton: NSButton {
      var isRecording = false {
          didSet {
              updateButtonState()
          }
      }
      
      private var activeShortcut: AppShortcut? {
          didSet {
              updateButtonState()
          }
      }
      
      var onShortcutChanged: ((AppShortcut) -> Void)?
      
      override init(frame frameRect: NSRect) {
          super.init(frame: frameRect)
          self.bezelStyle = .rounded
          self.setButtonType(.momentaryPushIn)
          self.activeShortcut = AppShortcut.load() ?? .default
          updateButtonState()
      }
      
      required init?(coder: NSCoder) {
          super.init(coder: coder)
      }
      
      private func updateButtonState() {
          if isRecording {
              self.title = "Recording... Press keys"
              self.highlight(true)
          } else {
              self.title = activeShortcut?.displayName ?? "Click to record"
              self.highlight(false)
          }
      }
      
      override func mouseDown(with event: NSEvent) {
          if isRecording {
              cancelRecording()
          } else {
              startRecording()
          }
      }
      
      private func startRecording() {
          isRecording = true
          setupEventMonitor()
      }
      
      private func cancelRecording() {
          isRecording = false
          removeEventMonitor()
      }
      
      private var eventMonitor: Any?
      
      private func setupEventMonitor() {
          removeEventMonitor()
          
          eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
              guard let self = self, self.isRecording else { return event }
              
              let keyCode = event.keyCode
              
              if keyCode == 53 { // Escape
                  self.cancelRecording()
                  return nil
              }
              
              let flags = event.modifierFlags
              var modifiers: AppShortcut.Modifiers = []
              if flags.contains(.command) { modifiers.insert(.command) }
              if flags.contains(.option) { modifiers.insert(.option) }
              if flags.contains(.control) { modifiers.insert(.control) }
              if flags.contains(.shift) { modifiers.insert(.shift) }
              
              // Require at least one modifier key
              if modifiers.isEmpty {
                  return nil
              }
              
              let newShortcut = AppShortcut(keyCode: UInt32(keyCode), modifiers: modifiers)
              self.activeShortcut = newShortcut
              self.isRecording = false
              self.removeEventMonitor()
              
              self.onShortcutChanged?(newShortcut)
              return nil
          }
      }
      
      private func removeEventMonitor() {
          if let monitor = eventMonitor {
              NSEvent.removeMonitor(monitor)
              eventMonitor = nil
          }
      }
      
      deinit {
          removeEventMonitor()
      }
  }
  ```

- [ ] **Step 2: Update SettingsWindowController UI to display shortcut row**
  
  In `SettingsWindowController.swift`, update `makeContentView()` to display a clean horizontal `NSStackView` combining the label and the `ShortcutRecorderButton`. When a new shortcut is recorded, save it and trigger a notification.

  ```swift
  // Notification name extension
  extension Notification.Name {
      static let appShortcutDidChange = Notification.Name("appShortcutDidChange")
  }
  ```

  And wire the `onShortcutChanged` callback on `ShortcutRecorderButton` to:
  ```swift
  let recorder = ShortcutRecorderButton()
  recorder.onShortcutChanged = { shortcut in
      shortcut.save()
      NotificationCenter.default.post(name: .appShortcutDidChange, object: nil)
  }
  ```

- [ ] **Step 3: Build project and verify no compilation errors**
  
  Run: `swift build`
  Expected: Build complete!

---

### Task 3: Load and Listen to Shortcut Updates in AppDelegate

**Files:**
- Modify: `Sources/ToolTranslate/App/AppDelegate.swift`

- [ ] **Step 1: Update AppDelegate to load saved shortcut and observe changes**
  
  Modify `setupShortcut(coordinator:)` to load the shortcut using `AppShortcut.load() ?? .default`.
  Register `AppDelegate` as an observer of `.appShortcutDidChange` notification.
  Implement the observer callback to reload/re-register the shortcut in `ShortcutManager`.

  ```swift
  // Observer setup
  NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleShortcutChange),
      name: .appShortcutDidChange,
      object: nil
  )

  @objc private func handleShortcutChange() {
      let shortcut = AppShortcut.load() ?? .default
      do {
          try shortcutManager?.register(shortcut: shortcut)
      } catch {
          NSLog("Failed to register new shortcut: \(error.localizedDescription)")
      }
  }
  ```

- [ ] **Step 2: Build project and verify compile success**
  
  Run: `swift build`
  Expected: Build complete!
