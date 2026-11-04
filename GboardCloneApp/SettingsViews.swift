import SwiftUI

private func color(_ c: RGBA) -> Color { Color(red: c.r, green: c.g, blue: c.b, opacity: c.a) }

struct AppearanceView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        NavigationStack {
            Form {
                Section("Theme") {
                    Picker("Mode", selection: $model.settings.themeMode) {
                        ForEach(ThemeMode.allCases) { Text($0.rawValue.capitalized).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("Accent colour") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6)) {
                        ForEach(AccentColor.all) { a in
                            Circle().fill(color(a.color)).frame(width: 38, height: 38)
                                .overlay(Circle().stroke(Color.primary, lineWidth: model.settings.accentID == a.id ? 3 : 0))
                                .onTapGesture { model.settings.accentID = a.id }
                                .accessibilityLabel(a.name).accessibilityAddTraits(model.settings.accentID == a.id ? .isSelected : [])
                        }
                    }
                }
                Section("Size") {
                    VStack(alignment: .leading) {
                        Text("Keyboard height: \(Int(model.settings.heightScale * 100))%")
                        Slider(value: $model.settings.heightScale, in: KeyboardSettings.heightRange, step: 0.05)
                    }
                    Toggle("Number row", isOn: $model.settings.showNumberRow)
                    Picker("One-handed mode", selection: $model.settings.oneHanded) {
                        ForEach(Handedness.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Section("Feedback") {
                    Toggle("Key click sound", isOn: $model.settings.soundEnabled)
                    Toggle("Haptic feedback (needs Full Access)", isOn: $model.settings.hapticsEnabled)
                    VStack(alignment: .leading) {
                        Text("Long-press delay: \(String(format: "%.2f", model.settings.longPressDelay)) s")
                        Slider(value: $model.settings.longPressDelay, in: 0.2...0.8, step: 0.05)
                    }
                }
                Section { Text("The click sound also requires “Keyboard Clicks” in iOS Settings → Sounds & Haptics.").font(.footnote) }
            }.navigationTitle("Appearance")
        }
    }
}

struct TypingView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        NavigationStack {
            Form {
                Section("Language & layout") {
                    Picker("Layout", selection: $model.settings.language) {
                        ForEach(LanguageLayout.allCases) { Text($0.displayName).tag($0) }
                    }
                }
                Section {
                    Toggle("Double-space inserts full stop", isOn: $model.settings.doubleSpacePeriod)
                    Toggle("Auto punctuation", isOn: $model.settings.autoPunctuation)
                    Toggle("Auto-capitalisation", isOn: $model.settings.autoCapitalize)
                } header: { Text("Punctuation & capitals") } footer: {
                    Text("Double-space: tapping space twice quickly turns “word  ” into “word. ”.\nAuto punctuation: removes the space typed before , . ! ? ; : and adds a space after , ! ? when a letter follows (and after “.” before a capital letter). Domains like google.com are left alone.\nThese are simple fixed rules — RegBoard has no word prediction or autocorrection.")
                }
                Section {
                    Toggle("Dynamic tap zones", isOn: $model.settings.dynamicTapZones)
                } header: { Text("Accuracy") } footer: {
                    Text("Keys you are more likely to press next get a slightly larger invisible tap area, and gaps between keys are never dead, so near-misses still type the right letter. The keys look the same. Uses a fixed letter-pair table; nothing you type is learned or stored.")
                }
                Section("Gestures") {
                    Toggle("Flick keys down for symbols", isOn: $model.settings.flickSymbols)
                    Label("Long-press a key for accents and alternates", systemImage: "hand.tap")
                    Label("Hold ⌫ to repeat delete; slide left on it to delete words", systemImage: "delete.left")
                    Label("Double-tap ⇧ for caps lock; hold ⇧ and slide to a letter for one capital", systemImage: "capslock")
                    Label("Drag across the space bar to move the cursor; hold it for trackpad mode", systemImage: "arrow.left.and.right")
                    Label("⌄ key hides the keyboard", systemImage: "keyboard.chevron.compact.down")
                    Text("Glide (swipe) typing is not available: it needs a word dictionary to match paths against, and RegBoard deliberately has none.").font(.footnote)
                }
            }.navigationTitle("Typing")
        }
    }
}

struct PrivacyView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirm = false
    var body: some View {
        NavigationStack {
            Form {
                Section("What RegBoard does") {
                    Text("• All typing logic runs on your device.\n• No network code, analytics, or telemetry.\n• Typed text is never logged, stored, or analysed — there is no prediction, autocorrection or word learning.\n• Password and secure fields get the iOS system keyboard; RegBoard never sees them. If one is ever shown, auto punctuation and double-space are disabled.")
                }
                Section("Your data") {
                    Text("RegBoard stores only your settings (and recently used emoji).").font(.footnote)
                    Button("Reset settings & clear recent emoji", role: .destructive) { confirm = true }
                }
                Section("Full Access") {
                    Text("Needed only to read the settings saved by this app (App Group) and for haptics. Without it the keyboard still types, using defaults.").font(.footnote)
                }
            }
            .navigationTitle("Privacy")
            .confirmationDialog("Reset all settings and clear recent emoji?", isPresented: $confirm, titleVisibility: .visible) {
                Button("Reset", role: .destructive) { model.eraseEverything() }
            }
        }
    }
}
