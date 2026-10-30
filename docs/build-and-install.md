# Build, test, install

Requires macOS, Xcode 15+, an Apple ID (free works for device install, 7-day signing), and an iPhone for real-device testing.

1. `brew install xcodegen && xcodegen generate` → creates `RegBoard.xcodeproj`.
2. Pick your own identifiers: replace `com.regboard.regboard` (+ `.keyboard`) and `group.com.regboard.regboard` in `project.yml`, both `.entitlements`, and `Shared/KeyboardSettings.swift`. In Xcode select your Team for both targets; ensure the App Groups capability is on for both.
3. Core tests without the project: `swift test` in the repo root (macOS).
4. Full tests: `xcodebuild -scheme RegBoard -destination 'platform=iOS Simulator,name=iPhone 15' test`.
5. Run on device: select the RegBoard scheme + your iPhone, ⌘R.
6. Enable: Settings → General → Keyboard → Keyboards → Add New Keyboard → RegBoard. Optional: tap RegBoard → Allow Full Access.
7. In any text field, hold 🌐 and choose RegBoard.

Free-account note: App Groups may require a paid team; if signing fails, remove the App Group entitlement — the keyboard then uses its own defaults (app ↔ keyboard sync disabled).
