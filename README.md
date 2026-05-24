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

## Build a macOS App

Create a double-clickable app bundle:

```bash
./scripts/build_app.sh
```

The app is created at:

```text
dist/ToolTranslate.app
```

Open it from Finder or run:

```bash
open dist/ToolTranslate.app
```

This MVP app is ad-hoc signed for local use, but it is not notarized. macOS may still show a security warning on first launch.

## Accessibility Permission

Tool Translate needs macOS Accessibility permission to read selected text from the focused application.

If translation fails with a permission message:

1. Open System Settings.
2. Go to Privacy & Security.
3. Open Accessibility.
4. Enable Tool Translate, or enable the terminal app if you are running from source.
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
