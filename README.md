# RegBoard — a privacy-first iOS keyboard (Gboard-inspired)

Native Swift/UIKit keyboard extension + SwiftUI companion app. Original design and code; no Google assets. **No prediction of any kind** (no suggestions, autocorrect, learning or glide typing) by design; adjustable height, number-row toggle, one-handed mode, flick symbols, gestures, hide-keyboard key, and toggles for double-space full stop and auto punctuation.

## ⚠️ Read first
1. The first APK supplied was the Uptodown store client, not Gboard. A real Gboard 18.5.4 bundle was analysed afterwards: see [docs/gboard-vs-regboard.md](docs/gboard-vs-regboard.md) (settings/features verified from manifest and strings; layouts, models and runtime behaviour not extracted).
2. **Nothing here has been compiled or run.** The authoring machine is Linux without Swift/Xcode. See "Verification status".

## Layout
`GboardCloneApp/` app · `KeyboardExtension/` keyboard · `Shared/` core · `Tests/` XCTest · `project.yml` XcodeGen · `docs/`

## Docs
[findings](docs/reverse-engineering-findings.md) · [iOS constraints](docs/ios-platform-constraints.md) · [architecture](docs/architecture.md) · [feature matrix](docs/feature-matrix.md) · [build & install](docs/build-and-install.md)

## Quick start (macOS)
`xcodegen generate`, set team/bundle IDs/App Group, run on device, enable under Settings → General → Keyboard. Details in build-and-install.md.

## Privacy
No network code, analytics or logging. Nothing typed is stored; only settings and recent emoji are persisted locally (App Group `UserDefaults`). Full Access is optional (settings sync + haptics).

## Verification status
| Check | Result |
|---|---|
| Workspace/APK/REA inspection | Done (APK identity verified by hash, manifest, zip listing) |
| Apple docs read | **Not possible** — fetch returned titles only; constraints written from prior knowledge |
| Swift compile / `swift test` / Xcode build / simulator / device | **Not run** (no toolchain on Linux). Tests were traced by hand against the logic only |
| Project generation | `project.yml` written, never executed |
Expect some compile errors on first build; they should be small.
