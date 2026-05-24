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
