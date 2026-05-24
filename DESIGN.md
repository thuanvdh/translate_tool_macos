# Tool Translate Design

## Understanding Summary

- Build a native macOS menu bar app with Swift/SwiftUI for translating selected text into Vietnamese.
- Primary flow: select text in another app, trigger a global shortcut or menu bar action, then receive a Vietnamese translation.
- Translation result appears in a small popup near the cursor or selection, optimized for quick reading.
- MVP uses OpenAI first, but the architecture must allow future translation engines.
- Default translation style is natural, easy-to-read Vietnamese with source language auto-detection.
- If selected text cannot be captured, the app opens a mini input so the user can paste or type manually.
- The project is intended as a moderately serious open-source project with clear documentation, basic CI, issue templates, and a release checklist.

## Assumptions

- The default shortcut will be configurable; MVP starts with `Control + Option + T`.
- The app requires macOS Accessibility permission for selected-text capture and contextual popup behavior.
- If Accessibility permission is missing, the app guides the user to enable it.
- Performance target for MVP is a few paragraphs translated in about 3-5 seconds when the network and API are healthy.
- The app does not store translation history or cache translated content.
- Text is sent to OpenAI for MVP translation; this is documented clearly in README and Settings.
- API keys are entered in Settings and stored in macOS Keychain.
- Offline or local translation is not part of MVP, but the engine interface should allow it later.
- MVP does not include signing, notarization, auto-update, telemetry, or crash reporting.

## Decision Log

| Decision | Alternatives Considered | Rationale |
| --- | --- | --- |
| Build a menu bar app | Popup-only app, windowed app, CLI/service | Best fit for quick translation in daily macOS workflows. |
| Use Swift/SwiftUI native macOS | Electron, Tauri, local service shell | Native macOS gives better menu bar, permissions, shortcut, popup, and Keychain integration. |
| Use Approach 1: native app with engine protocol | Native UI with local HTTP service, Electron/Tauri | Lowest complexity for MVP while keeping future engine flexibility. |
| MVP uses OpenAI first | Google Cloud Translation, local model | Good quality and flexible prompting; architecture remains open for later engines. |
| Keep a small `TranslationEngine` abstraction | Full plugin system, hard-coded OpenAI only | Avoids over-engineering while preventing provider lock-in. |
| Do not store history or cache | Local history, local cache | Reduces privacy risk and simplifies MVP. |
| Use mini input fallback | Auto-copy selected text, clipboard fallback, error only | Avoids modifying clipboard and gives users a reliable manual path. |
| Store API key in Keychain | Environment variable, config file | More appropriate for a user-facing macOS app. |

## Recommended Architecture

The app is a native Swift/SwiftUI macOS application composed of five main areas.

### App Shell

Manages the menu bar icon, lifecycle, Settings window, global shortcut registration, and Accessibility permission status.

### Selection Capture

Attempts to retrieve selected text from the focused application. If capture fails, it returns a typed error so the UI can open mini input instead of presenting a dead-end error.

### Popup Presenter

Displays a small floating popup near the cursor or selected region. The popup supports loading, translated result, error state, retry, copy, close, and mini input mode.

### Translation Core

Coordinates input validation, timeout, retry behavior, and calls the configured translation engine. MVP provides `OpenAITranslationEngine`.

### Secure Settings

Provides SwiftUI settings for API key entry, shortcut configuration, and future engine selection. Sensitive data is stored in Keychain; non-sensitive preferences use `UserDefaults`.

## Core Data Flow

1. User selects text in any app.
2. User triggers the global shortcut or menu bar action.
3. App checks Accessibility permission.
4. If permission is missing, app shows guidance for enabling it.
5. `SelectionCaptureService` attempts to read selected text.
6. If text is captured, the app trims and validates it, then opens the popup in loading state.
7. `TranslationService` calls the configured `TranslationEngine`.
8. Popup updates with the Vietnamese translation.
9. If selected text cannot be captured, popup opens mini input for manual paste or typing.
10. When popup closes, source text and translated text are discarded from UI state.

## Proposed Module Structure

- `ToolTranslateApp`: app entry point, menu bar, lifecycle.
- `Services/SelectionCaptureService`: permission checks and selected-text capture.
- `Services/TranslationService`: orchestration, validation, timeout, retry.
- `Engines/TranslationEngine`: engine protocol.
- `Engines/OpenAITranslationEngine`: OpenAI API implementation.
- `Security/KeychainStore`: API key storage.
- `Settings/SettingsView`: API key, shortcut, future engine settings.
- `Popup/TranslationPopupView`: loading, result, error, and mini input UI.
- `Shortcut/ShortcutManager`: global shortcut registration and updates.

## Translation Engine Interface

```swift
protocol TranslationEngine {
    var id: String { get }
    var displayName: String { get }

    func translateToVietnamese(
        text: String,
        options: TranslationOptions
    ) async throws -> TranslationResult
}
```

MVP `TranslationOptions` can include:

- `targetLanguage = "vi"`
- `style = .natural`
- `maxInputCharacters`

MVP `TranslationResult` can include:

- `translatedText`
- `detectedSourceLanguage`
- `engineID`
- `duration`

## OpenAI Engine Behavior

- Reads API key from `KeychainStore`.
- Calls OpenAI through `URLSession`.
- Uses a fixed MVP prompt: translate into natural, easy-to-read Vietnamese; preserve proper nouns, code, commands, API names, and technical terms; do not add explanations unless needed to avoid meaning loss.
- Applies a reasonable timeout, such as 15-30 seconds.
- Maps provider and network failures into app-level errors: missing API key, unauthorized, rate limited, network error, timeout, invalid response.

## Error Handling

- Missing Accessibility permission: show in-app guidance.
- Missing API key: show an error with a shortcut to Settings.
- Empty selected text: show mini input.
- Capture unavailable for current app: show mini input.
- Text too long: explain MVP limit and ask the user to choose a shorter passage.
- Network or timeout error: show short error and retry action.
- Invalid API response: show generic translation failure and allow retry.

## Testing Strategy

- Unit tests for `TranslationService` using a mock `TranslationEngine`.
- Unit tests for request/prompt mapping and provider error mapping.
- Unit tests for `KeychainStore` where practical.
- UI state tests around loading, result, error, and mini input flows if the project setup supports them.
- Manual QA checklist for Chrome/Safari, VS Code, Slack/Discord, and Notes.
- CI on macOS runner for build and test.

## Risks

- Selected-text capture can vary across applications and may be unreliable in some apps.
- Global shortcut conflicts may occur; the shortcut must be configurable and registration errors must be visible.
- Privacy must be clear because selected text is sent to OpenAI.
- Unsigned or unnotarized open-source builds may trigger macOS Gatekeeper warnings.

## MVP Acceptance Criteria

- Menu bar app runs in the background on macOS.
- Settings accepts an OpenAI API key and stores it in Keychain.
- Configurable shortcut exists, with default `Control + Option + T`.
- Selected text can be translated from common apps such as Chrome/Safari, VS Code, and Notes.
- Popup supports loading, result, error, copy, close, and mini input fallback.
- App does not store translation history or cache translated content.
- README documents setup, privacy behavior, and known limitations.
- Basic macOS CI build/test passes.

## Implementation Handoff

The next step is to create an implementation plan for a Swift/SwiftUI MVP, then scaffold the macOS project and implement incrementally.
