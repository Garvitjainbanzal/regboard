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
        // Single dark theme: force dark so the system keyboard background is dark regardless of the host app.
        overrideUserInterfaceStyle = .dark
        view.overrideUserInterfaceStyle = .dark
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
            guard let self else { return }
            if def.action == .backspace {
                // Snapshot for the swipe-left gesture (see SwipeDelete); the tap itself removes one character.
                let ctx = self.textDocumentProxy.documentContextBeforeInput ?? ""
                self.swipeDelete = SwipeDelete(context: ctx, alreadyRemoved: ctx.isEmpty ? 0 : 1)
            }
            self.controller.handle(def.action)
        }
        keyboardView.onAlternate = { [weak self] s in self?.controller.insertAlternate(s) }
        keyboardView.onRepeatDelete = { [weak self] in self?.controller.repeatDelete() }
        keyboardView.onSpaceDrag = { [weak self] n in self?.controller.moveCursor(by: n) }
        keyboardView.onSwipeDelete = { [weak self] words in self?.applySwipeDelete(words: words) }
        keyboardView.onSwipeDeleteEnd = { [weak self] in self?.controller.syncAfterDelete() }
                keyboardView.onHaptic = { [weak self] in self?.haptic() }
        keyboardView.wordPrefix = { [weak self] in
            // Letters (and apostrophes) typed since the last space/punctuation.
            let ctx = self?.textDocumentProxy.documentContextBeforeInput ?? ""
            return String(ctx.reversed().prefix { $0.isLetter || $0 == "'" || $0 == "’" }.reversed())
        }
        applyTraits(); applySettings()
        controller.beginEditing()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Pick up changes made in the containing app.
        // isBeingPresented guard prevents a redundant beginEditing() on the very first appearance
        // since viewDidLoad already called it. On subsequent appearances (switching back to this
        // keyboard from another input mode) we do want to reset state.
        settings = settingsStore.load(); applySettings(); applyTraits()
        if !isBeingPresented { controller.beginEditing() }
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
        // Use the screen width/height to determine orientation — view.bounds may
        // not be valid yet when this is called early in the layout pass.
        let screen = UIScreen.main.bounds
        let landscape = screen.width > screen.height
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
        // Only re-apply traits/appearance when something structural may have changed
        // (return key type, secure flag, keyboard appearance). Avoid calling render()
        // directly here — that happens inside applySettings → render(). To prevent a
        // full key-row rebuild on every host-app keystroke (e.g. live-search fields),
        // we check whether the derived traits or palette actually changed before doing work.
        let newTraits = buildTraits()
        guard newTraits != controller.traits else { return }
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

    private func applySettings() {
        controller.apply(settings: settings)
        let pal = ThemePalette.dark
        keyboardView.soundEnabled = settings.soundEnabled
        keyboardView.longPressDelay = settings.longPressDelay
        keyboardView.oneHanded = settings.oneHanded
        keyboardView.dynamicTapZones = settings.dynamicTapZones
        keyboardView.palette = pal
        emojiPanel?.palette = pal
        // Only trigger a constraint update when the target height has actually changed,
        // not on every keystroke. render() handles the key-row update separately.
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
    /// Swipe left on backspace deletes words live; sliding back types them again (see `SwipeDelete`).
    private var swipeDelete: SwipeDelete?
    private func applySwipeDelete(words: Int) {
        guard var plan = swipeDelete else { return }
        let step = plan.plan(words: words)
        swipeDelete = plan
        for _ in 0..<step.deletes { textDocumentProxy.deleteBackward() }
        if !step.insert.isEmpty { textDocumentProxy.insertText(step.insert) }
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
