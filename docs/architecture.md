# Architecture

```
GboardCloneApp/      SwiftUI companion app (setup guide, appearance, typing, dictionary, privacy)
KeyboardExtension/   UIKit keyboard extension (UIInputViewController, KeyView, KeyboardView, EmojiPanel)
Shared/              Platform-neutral core, compiled into both targets AND a SwiftPM library (RegBoardCore)
Tests/               XCTest suite for Shared (run by `swift test` or the Xcode test target)
project.yml          XcodeGen spec → generates RegBoard.xcodeproj on macOS
```

## Data flow
`KeyView` touch → `KeyboardView.onKey` → `InputController.handle(KeyAction)` → `TextProxy` (adapter over `UITextDocumentProxy`) → `onChange` → VC re-renders the key rows.

All behaviour (shift state, autocap, double-space period, auto punctuation, cursor moves, secure-field policy) lives in `InputController`, which depends only on the `TextProxy` protocol, so it is unit-tested with a mock proxy and never touches UIKit.

## Shared storage
`UserDefaults(suiteName: "group.com.regboard.regboard")` holds `KeyboardSettings` (JSON) and recent emoji. The App Group is declared in both entitlements files. Without Full Access the extension may not see the app's values → it falls back to defaults (still functional). **Change `com.example` / the group ID to your own team's** in `project.yml`, both `.entitlements`, and `SettingsStore.appGroupID`.

## Text rules (no prediction)
By request, RegBoard has **no suggestions, autocorrection, next-word prediction, glide typing or learning**, and no dictionary. `InputController` only types what is pressed, plus two optional fixed rules (both on by default, each with its own toggle):
1. **Double-space full stop** (`doubleSpacePeriod`): second space within 0.5 s after a word character or closing bracket/quote replaces the space with `. `.
2. **Auto punctuation** (`autoPunctuation`): removes a space typed before `. , ! ? ; :`; inserts a space after `, ! ?` when a letter follows directly; after `.` only when an uppercase letter follows a letter/digit (so `google.com`, `3.5`, `1,000`, `:)` are untouched).
Both are disabled in secure fields. Auto-capitalisation (`autoCapitalize`) follows the host field's trait.

## Safety & privacy decisions
- Nothing typed is stored; settings and recent emoji are the only persisted data. No networking, analytics, or logging.

## Layout engine
`KeyboardLayouts.rows(...)` returns `[[KeyDef]]` per page (letters/numbers/symbols) and language (QWERTY, QWERTZ, AZERTY, Spanish QWERTY). `KeyboardView` rebuilds key views only when the row model changes; letter rows shorter than 10 keys are centered at the 10-key width. Height: 260pt portrait / 190pt landscape × user scale (0.7–1.4), no number row → −42pt. One-handed mode shrinks the key area to 80% width, aligned left or right. Flick hints: each letter key shows a small symbol (`a`→`@`, `s`→`#` …); with the number row hidden, top-row keys hint digits. Space bar: drag to move the cursor, long-press for trackpad mode (horizontal only — iOS gives no vertical cursor API).
