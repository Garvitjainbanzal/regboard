import UIKit

/// Adapts the real UITextDocumentProxy to the platform-independent TextProxy.
final class ProxyAdapter: TextProxy {
    weak var vc: UIInputViewController?
    private var proxy: UITextDocumentProxy? { vc?.textDocumentProxy }
    var documentContextBeforeInput: String? { proxy?.documentContextBeforeInput }
    var documentContextAfterInput: String? { proxy?.documentContextAfterInput }
    func insertText(_ text: String) { proxy?.insertText(text) }
    func deleteBackward() { proxy?.deleteBackward() }
    func adjustTextPosition(byCharacterOffset offset: Int) { proxy?.adjustTextPosition(byCharacterOffset: offset) }
}

final class KeyboardViewController: UIInputViewController {
    private let settingsStore = SettingsStore()
    private let adapter = ProxyAdapter()
    private var controller: InputController!
    private var keyboardView: KeyboardView!
    private var emojiPanel: EmojiPanel?
    private var heightConstraint: NSLayoutConstraint?
    private var settings = KeyboardSettings()

    override func viewDidLoad() {
        super.viewDidLoad()
        settings = settingsStore.load()
        adapter.vc = self
        controller = InputController(proxy: adapter, settings: settings)
        controller.onChange = { [weak self] in self?.render() }
        controller.onNextKeyboard = { [weak self] in self?.advanceToNextInputMode() }
        controller.onEmoji = { [weak self] in self?.showEmoji() }
        controller.onHide = { [weak self] in self?.dismissKeyboard() }

        keyboardView = KeyboardView()
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(keyboardView)
        NSLayoutConstraint.activate([
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor), keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor), keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        keyboardView.onKey = { [weak self] def in self?.controller.handle(def.action) }
        keyboardView.onAlternate = { [weak self] s in self?.controller.insertAlternate(s) }
        keyboardView.onRepeatDelete = { [weak self] in self?.controller.repeatDelete() }
        keyboardView.onSpaceDrag = { [weak self] n in self?.controller.moveCursor(by: n) }
        keyboardView.onSwipeDeleteWord = { [weak self] in self?.controller.deleteWord() }
        keyboardView.onHaptic = { [weak self] in self?.haptic() }
        applyTraits(); applySettings()
        controller.beginEditing()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Pick up changes made in the containing app.
        settings = settingsStore.load(); applySettings(); applyTraits(); controller.beginEditing()
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()
        let landscape = view.bounds.width > view.bounds.height
        let base: CGFloat = landscape ? 190 : 260
        let rowsExtra: CGFloat = settings.showNumberRow ? 0 : -42
        let h = (base + rowsExtra) * CGFloat(settings.heightScale)
        if heightConstraint == nil {
            let c = view.heightAnchor.constraint(equalToConstant: h); c.priority = UILayoutPriority(999); c.isActive = true; heightConstraint = c
        } else { heightConstraint?.constant = h }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        view.setNeedsUpdateConstraints()
    }

    override func textWillChange(_ textInput: UITextInput?) {}
    override func textDidChange(_ textInput: UITextInput?) {
        applyTraits(); applySettings()   // appearance may flip (dark/light) and traits may change
    }
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous); applySettings()
    }

    // MARK: Configuration
    private func applyTraits() {
        let p = textDocumentProxy
        var t = KeyboardTraits()
        switch p.autocapitalizationType ?? .sentences {
        case .none: t.autocapitalization = .none
        case .words: t.autocapitalization = .words
        case .allCharacters: t.autocapitalization = .allCharacters
        default: t.autocapitalization = .sentences
        }
        t.isSecure = p.isSecureTextEntry ?? false
        switch p.returnKeyType ?? .default {
        case .go: t.returnKeyLabel = "go"; case .search: t.returnKeyLabel = "search"; case .send: t.returnKeyLabel = "send"
        case .done: t.returnKeyLabel = "done"; case .next: t.returnKeyLabel = "next"; case .join: t.returnKeyLabel = "join"
        case .route: t.returnKeyLabel = "route"; case .continue: t.returnKeyLabel = "continue"; default: t.returnKeyLabel = "return"
        }
        controller.traits = t
        controller.needsGlobe = needsInputModeSwitchKey
    }

    private func systemIsDark() -> Bool {
        if textDocumentProxy.keyboardAppearance == .dark { return true }
        return traitCollection.userInterfaceStyle == .dark
    }

    private func applySettings() {
        controller.apply(settings: settings)
        let pal = ThemePalette.palette(mode: settings.themeMode, systemIsDark: systemIsDark())
        keyboardView.soundEnabled = settings.soundEnabled
        keyboardView.longPressDelay = settings.longPressDelay
        keyboardView.oneHanded = settings.oneHanded
        keyboardView.accent = AccentColor.named(settings.accentID).color.ui
        keyboardView.palette = pal
        emojiPanel?.palette = pal
        view.setNeedsUpdateConstraints()
        render()
    }

    private func render() {
        keyboardView.setRows(controller.layoutRows, shift: controller.shift)
        keyboardView.setNeedsLayout()
    }

    // MARK: Haptics (UIKit feedback generators require Full Access in extensions)
    private lazy var impact = UIImpactFeedbackGenerator(style: .light)
    private func haptic() {
        guard settings.hapticsEnabled, hasFullAccess else { return }
        impact.impactOccurred()
    }

    // MARK: Emoji
    private func showEmoji() {
        let panel = EmojiPanel()
        panel.recents = RecentEmojiStore()
        panel.palette = keyboardView.palette
        panel.translatesAutoresizingMaskIntoConstraints = false
        panel.onPick = { [weak self] e in self?.textDocumentProxy.insertText(e) }
        panel.onDelete = { [weak self] in self?.textDocumentProxy.deleteBackward() }
        panel.onBack = { [weak self] in self?.hideEmoji() }
        view.addSubview(panel)
        NSLayoutConstraint.activate([panel.leadingAnchor.constraint(equalTo: view.leadingAnchor), panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                     panel.topAnchor.constraint(equalTo: view.topAnchor), panel.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
        emojiPanel = panel
    }
    private func hideEmoji() { emojiPanel?.removeFromSuperview(); emojiPanel = nil; render() }
}
