import SwiftUI

@main
struct RegBoardApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup { RootView().environmentObject(model) }
    }
}

/// Observable wrapper around the shared settings. Every edit is persisted immediately so the keyboard can pick it up.
final class AppModel: ObservableObject {
    private let store = SettingsStore()
    let recents = RecentEmojiStore()
    @Published var settings: KeyboardSettings { didSet { scheduleSave() } }

    init() { settings = store.load() }

    func eraseEverything() { recents.clear(); settings = KeyboardSettings() }

    // Debounce saves so rapid slider drags don't encode+write on every tick.
    private var saveWork: DispatchWorkItem?
    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.store.save(self.settings)
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            SetupView().tabItem { Label("Setup", systemImage: "keyboard") }
            AppearanceView().tabItem { Label("Appearance", systemImage: "paintpalette") }
            TypingView().tabItem { Label("Typing", systemImage: "textformat") }
            PrivacyView().tabItem { Label("Privacy", systemImage: "lock.shield") }
        }
    }
}
