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

    // Cache the last computed height so we only update the constraint when it
    // actually changes — prevents repeated constraint churn on every keystroke.
    private var lastComputedHeight: CGFloat = 0

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
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.topAnchor.constraint(equalTo: view.topAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        keyboardView.onKey = { [weak self] def in
            self?.controller.handle(def.action)
            // Feed the bigram engine: record the letter just typed so the next
            // touch gets appropriately expanded hitboxes for likely following chars.
            if case .character(let s) = def.action, let ch = s.lowercased().first, ch.isLetter {
                self?.keyboardView.lastTypedLetter = ch
            } else if case .space = def.action {
                // After a space we're at a word boundary — clear the bigram context
                // so the first letter of the new word gets neutral hitboxes.
                self?.keyboardView.lastTypedLetter = nil
            }
        }
        keyboardView.onAlternate = { [weak self] s in self?.controller.insertAlternate(s) }
        keyboardView.onRepeatDelete = { [weak self] in self?.controller.repeatDelete() }
        keyboardView.onSpaceDrag = { [weak self] n in self?.controller.moveCursor(by: n) }
        keyboardView.onSwipeSelectChars = { [weak self] n in self?.textDocumentProxy.adjustTextPosition(byCharacterOffset: n) }
        keyboardView.onCommitSwipeDelete = { [weak self] in self?.commitSwipeDelete() }
        keyboardView.onSelectDrag = { [weak self] n in self?.extendSelection(by: n) }
        keyboardView.onHaptic = { [weak self] in self?.haptic() }
        applyTraits(); applySettings()
        controller.beginEditing()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // applySettings() reloads from the store itself, so no explicit load needed here.
        applySettings(); applyTraits()
        if !isBeingPresented { controller.beginEditing(); keyboardView.lastTypedLetter = nil }
    }

    override func updateViewConstraints() {
        super.updateViewConstraints()
        let h = targetHeight()
        // Only touch the constraint when the value actually changes — avoids
        // height flickering caused by repeated constraint invalidation.
        guard h != lastComputedHeight else { return }
        lastComputedHeight = h
        if heightConstraint == nil {
            let c = view.heightAnchor.constraint(equalToConstant: h)
            c.priority = UILayoutPriority(999)
            c.isActive = true
            heightConstraint = c
        } else {
            heightConstraint?.constant = h
        }
    }

    private func targetHeight() -> CGFloat {
        // Derive orientation from the view's own trait collection when available,
        // falling back to the window scene. UIScreen.main is deprecated on iOS 16+.
        let landscape: Bool
        if view.bounds.width > 0 {
            landscape = view.bounds.width > view.bounds.height
        } else {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let screenSize = scenes.first?.coordinateSpace.bounds.size ?? CGSize(width: 390, height: 844)
            landscape = screenSize.width > screenSize.height
        }
        let base: CGFloat = landscape ? 190 : 260
        let rowsExtra: CGFloat = settings.showNumberRow ? 0 : -42
        return (base + rowsExtra) * CGFloat(settings.heightScale)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        // Reset cached height on rotation so the constraint is recalculated.
        lastComputedHeight = 0
        view.setNeedsUpdateConstraints()
    }

    override func textWillChange(_ textInput: UITextInput?) {}
    override func textDidChange(_ textInput: UITextInput?) {
        // Re-apply settings on every document change so that any settings the user
        // adjusted in the companion app (accent, height, number row, one-handed mode)
        // are reflected immediately. applySettings() reloads from UserDefaults and
        // guards the constraint update behind a changed-value check, so this is cheap
        // when nothing has actually changed.
        applyTraits(); applySettings()
    }
    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous); applySettings()
    }

    // MARK: Configuration
    private func buildTraits() -> KeyboardTraits {
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
        return t
    }

    private func applyTraits() {
        controller.traits = buildTraits()
        controller.needsGlobe = needsInputModeSwitchKey
    }

    private func systemIsDark() -> Bool {
        if textDocumentProxy.keyboardAppearance == .dark { return true }
        return traitCollection.userInterfaceStyle == .dark
    }

    private func applySettings() {
        // Always reload from the store so changes made in the companion app
        // (height, number row, accent, one-handed mode, etc.) are picked up
        // immediately the next time the keyboard renders, without requiring the
        // user to switch away and back to the keyboard.
        let loaded = settingsStore.load()
        // Skip all work when nothing changed — keeps textDidChange cheap on every keystroke.
        guard loaded != settings else {
            // Still need to render in case shift state changed.
            render(); return
        }
        settings = loaded
        controller.apply(settings: settings)
        let pal = ThemePalette.palette(mode: settings.themeMode, systemIsDark: systemIsDark())
        keyboardView.soundEnabled = settings.soundEnabled
        keyboardView.longPressDelay = settings.longPressDelay
        keyboardView.oneHanded = settings.oneHanded
        keyboardView.accent = AccentColor.named(settings.accentID).color.ui
        keyboardView.palette = pal
        emojiPanel?.palette = pal
        // Trigger a constraint update whenever the target height may have changed.
        // The guard inside updateViewConstraints skips the work if nothing changed.
        let newH = targetHeight()
        if newH != lastComputedHeight { view.setNeedsUpdateConstraints() }
        render()
    }

    private func render() {
        keyboardView.setRows(controller.layoutRows, shift: controller.shift)
        // setNeedsLayout is only needed when the rows actually changed (KeyboardView
        // handles that internally). Calling it unconditionally here causes an extra
        // layout pass on every keystroke, contributing to input lag.
    }

    // MARK: Haptics (UIKit feedback generators require Full Access in extensions)
    private lazy var impact = UIImpactFeedbackGenerator(style: .light)
    private func haptic() {
        guard settings.hapticsEnabled, hasFullAccess else { return }
        impact.impactOccurred()
    }

    // MARK: Swipe-delete
    /// Called when the user lifts their finger after a swipe-left on backspace.
    /// At this point the proxy has moved the cursor left by N characters (which
    /// shows a selection in the host app). We delete backward once per selected
    /// character, then let the InputController sync shift state.
    private func commitSwipeDelete() {
        // UITextDocumentProxy exposes `selectedText` when text is selected.
        // We delete the selection by calling deleteBackward() once — on iOS 16+
        // with a selection active this removes the whole selection in one call.
        // On older OS versions it may only remove one character, so we call
        // controller.deleteWord() as a fallback which also cleans up shift state.
        if let sel = textDocumentProxy.selectedText, !sel.isEmpty {
            textDocumentProxy.deleteBackward()
        } else {
            controller.deleteWord()
        }
        controller.textContextChanged()
    }

    // MARK: Shift+space selection trackpad
    /// Extends or shrinks the text selection by moving the active selection end.
    /// `adjustTextPosition` on iOS begins a selection from the caret when called
    /// the first time, then extends it on subsequent calls. Positive = forward.
    private func extendSelection(by offset: Int) {
        guard offset != 0 else { return }
        textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
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
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            panel.topAnchor.constraint(equalTo: view.topAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        emojiPanel = panel
    }
    private func hideEmoji() { emojiPanel?.removeFromSuperview(); emojiPanel = nil; render() }
}
