# iOS platform constraints for third-party keyboards

**Source status:** the two Apple pages named in the brief could not be retrieved in this environment (the fetch returned only the page title; the pages are JavaScript-rendered). The constraints below come from established knowledge of the Custom Keyboard API (App Extension Programming Guide, `UIInputViewController`, `UITextDocumentProxy`) and are **not re-verified against the live pages**. Re-check them against Apple's docs before relying on them.

## What a keyboard extension can do (no Full Access)
- Subclass `UIInputViewController`; draw any UIKit/SwiftUI view in `inputView`; set height with Auto Layout constraints.
- Insert/delete text via `textDocumentProxy` (`insertText`, `deleteBackward`), read limited context (`documentContextBeforeInput` / `AfterInput`, usually the current sentence/paragraph only), move cursor with `adjustTextPosition(byCharacterOffset:)`.
- Read traits: `keyboardType`, `returnKeyType`, `autocapitalizationType`, `keyboardAppearance`, `isSecureTextEntry`.
- Provide the required next-keyboard (globe) control: `handleInputModeList(from:with:)`, `needsInputModeSwitchKey`.
- Use `UIFeedbackGenerator` haptics only with Full Access (see below), `UIDevice.current.playInputClick()` for the system click sound.
- Use `UserDefaults` in the extension's own sandbox.

## Requires Full Access (`RequestsOpenAccess = YES`, user toggles in Settings)
- **Sharing data with the containing app** via an App Group container (without it the extension and app cannot reliably share files/defaults).
- **Haptics** (`UIImpactFeedbackGenerator`) — needs Full Access to work in the extension.
- Network access, reading `UIPasteboard.general` contents (iOS shows a paste prompt), location/contacts-style APIs.
- Full Access lets the keyboard process anything the user types and transmit it; Apple shows a warning. This project **uses no network and no telemetry**; Full Access is requested only for App Group sync and haptics, and the keyboard works without it (defaults fall back to built-ins).

## Not available to third-party keyboards
- **Secure text fields and phone-pad/number-pad-style fields**: the system substitutes its own keyboard; the extension never sees them (do not try to work around this).
- Reading text outside the proxy context window; no whole-document access; no monitoring of other apps.
- **Microphone/dictation inside the extension**: extensions cannot use the microphone; the globe/mic key of the system keyboard is not available to us. Alternative: dictate with the system keyboard's mic, or a containing-app recorder that hands text over through the App Group (user must switch apps) — **not implemented**.
- Launching the containing app from the extension is not officially supported (`openURL` via responder chain is an unsupported hack; not used).
- Replacing the system keyboard everywhere: the user can always switch; Apple's emoji/dictation keys are system-only.
- Memory ceiling (~50–70 MB in practice; the system may kill the extension) → keep dictionaries small.
- Cursor movement is limited to `adjustTextPosition`; selection can't be set or read (no select-all/cut/copy of selection from the proxy).
- No Siri/system autocorrect, QuickType, or system lexicon integration (only `UILexicon` via `requestSupplementaryLexicon`, which is available and optional).

## Feature classification

| Feature | Class |
|---|---|
| QWERTY, shift/caps, symbols, long-press alternates, backspace repeat | Keyboard extension |
| Double-space full stop, auto punctuation (fixed rules; no prediction) | Keyboard extension |
| Cross-process settings/dictionary sync, haptics | Keyboard extension **with Full Access** + App Group |
| Dictionary editor, themes picker, privacy controls | Containing app |
| Space-bar cursor drag | Extension (`adjustTextPosition`) |
| Swipe typing | Extension, feasible but **deferred** (not implemented) |
| Emoji picker | Extension (own picker; not the system emoji keyboard) |
| Clipboard history/monitoring | **Not available** (arbitrary monitoring); explicit paste button needs Full Access — not implemented |
| Voice dictation | **Not available** in extension; closest: system mic |
| Translation | Dependent on a separately configured network service — **not implemented** (no network by policy) |
