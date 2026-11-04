import UIKit

/// A single rounded key. Handles touch-down highlight, long-press alternates popover, flick-down hint symbols,
/// delete auto-repeat / slide-to-delete-words, shift-swipe, and the space-bar cursor drag / long-press trackpad.
final class KeyView: UIView {
    let def: KeyDef
    var palette: ThemePalette { didSet { applyColors() } }
    var accent: UIColor { didSet { applyColors() } }
    var shiftState: ShiftState = .off { didSet { applyColors(); updateLabel() } }
    var onTap: ((KeyDef) -> Void)?
    var onAlternate: ((String) -> Void)?
    var onRepeat: (() -> Void)?
    var onSpaceDrag: ((Int) -> Void)?
    var onHaptic: (() -> Void)?
    /// Called during a swipe-left gesture on backspace with the number of characters to select
    /// (always negative). The receiver should move the cursor left to show the selection.
    var onSwipeSelectChars: ((Int) -> Void)?
    /// Called when a swipe-left on backspace is committed (finger lifted) —
    /// the receiver should delete whatever is currently selected.
    var onCommitSwipeDelete: (() -> Void)?
    var onShiftRelease: ((CGPoint) -> Void)?
    var onTrackpadChanged: ((Bool) -> Void)?
    var longPressDelay: TimeInterval = 0.35
    var soundEnabled = true

    private let label = UILabel()
    private let hintLabel = UILabel()
    private let badgeLabel = UILabel()
    private var popover: UIView?
    private var altLabels: [UILabel] = []
    private var preview: UIView?
    private var longPressTimer: Timer?
    private var repeatTimer: Timer?
    private var touchStart: CGPoint = .zero
    private var lastX: CGFloat = 0
    // Tracks how many character positions we have moved left via swipe-select
    // so we know how far back to delete on lift.
    private var swipeSelectCount: Int = 0
    private var dragged = false, swipeDeleted = false, shiftSwiped = false, flicked = false, trackpad = false
    private var selectedAlt = 0
    private var pressed = false { didSet { applyColors() } }

    init(def: KeyDef, palette: ThemePalette, accent: UIColor) {
        self.def = def; self.palette = palette; self.accent = accent
        super.init(frame: .zero)
        layer.cornerRadius = 6; layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor; layer.shadowOpacity = 0.25; layer.shadowRadius = 0; layer.shadowOffset = CGSize(width: 0, height: 1)
        label.textAlignment = .center; label.adjustsFontSizeToFitWidth = true; label.minimumScaleFactor = 0.6
        label.isUserInteractionEnabled = false; label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        hintLabel.font = .systemFont(ofSize: 10, weight: .regular); hintLabel.textAlignment = .right
        hintLabel.text = def.hint; hintLabel.isUserInteractionEnabled = false; hintLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hintLabel)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor), label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: def.hint == nil ? 0 : 3),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 2), label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -2),
            hintLabel.topAnchor.constraint(equalTo: topAnchor, constant: 2), hintLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])
        if let b = def.badge {
            badgeLabel.text = b; badgeLabel.numberOfLines = 2; badgeLabel.font = .systemFont(ofSize: 9, weight: .medium)
            badgeLabel.isUserInteractionEnabled = false; badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(badgeLabel)
            NSLayoutConstraint.activate([badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10), badgeLabel.centerYAnchor.constraint(equalTo: centerYAnchor)])
        }
        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey
        accessibilityLabel = KeyView.accessibilityName(for: def)
        if let h = def.hint { accessibilityHint = "Pull down to type \(h)" }
        updateLabel(); applyColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    static func accessibilityName(for d: KeyDef) -> String {
        switch d.action {
        case .shift: return "Shift"; case .backspace: return "Delete"; case .space: return "Space"; case .returnKey: return d.label
        case .switchToLetters: return "Letters"; case .switchToNumbers: return "Numbers"; case .switchToSymbols: return "Symbols"
        case .nextKeyboard: return "Next keyboard"; case .emoji: return "Emoji"; case .character(let s): return s
        case .hideKeyboard: return "Hide keyboard"
        }
    }

    private func updateLabel() {
        var text = def.label
        if def.action == .shift { text = shiftState == .capsLock ? "⇪" : "⇧" }
        if def.action == .returnKey && def.label == "return" { text = "↵" }
        if def.action == .space && trackpad { text = "◀  ▶" }
        label.text = text
        let isText = text.count > 1 && def.action != .space
        let base: CGFloat = def.action == .space ? 14 : (isText ? 15 : 22)
        label.font = UIFontMetrics(forTextStyle: .body).scaledFont(for: .systemFont(ofSize: base), maximumPointSize: base * 1.4)
        label.adjustsFontForContentSizeCategory = true
        if def.action == .shift { accessibilityValue = shiftState == .off ? "off" : (shiftState == .once ? "on" : "caps lock") }
    }

    private func applyColors() {
        let highlighted = def.action == .shift && shiftState != .off
        var bg = def.isModifier ? palette.modifierKey.ui : palette.key.ui
        if def.action == .returnKey { bg = accent.withAlphaComponent(0.35) }        // light accent, dark arrow
        if def.action == .switchToLetters || def.action == .switchToNumbers || def.action == .switchToSymbols { bg = accent.withAlphaComponent(0.25) }
        if highlighted { bg = palette.key.ui }
        if pressed { bg = def.isModifier ? palette.key.ui : palette.modifierKey.ui }
        if trackpad { bg = accent.withAlphaComponent(0.35) }
        backgroundColor = bg
        label.textColor = def.action == .returnKey ? accent.darker() : (highlighted && shiftState == .capsLock ? accent : palette.keyText.ui)
        hintLabel.textColor = palette.keyText.ui.withAlphaComponent(0.55)
        badgeLabel.textColor = palette.keyText.ui.withAlphaComponent(0.55)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = def.pill ? min(bounds.width, bounds.height) / 2 : 6
    }

    // MARK: Touch handling
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        pressed = true; dragged = false; swipeDeleted = false; shiftSwiped = false; flicked = false; trackpad = false
        swipeSelectCount = 0
        touchStart = t.location(in: self); lastX = touchStart.x
        if soundEnabled { UIDevice.current.playInputClick() }
        onHaptic?()
        switch def.action {
        case .character:
            showPreview()
            if !def.alternates.isEmpty {
                longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressDelay, repeats: false) { [weak self] _ in self?.showPopover() }
            }
        case .backspace:
            // Fire the first delete immediately on touch-down so the keyboard feels
            // instantly responsive, but do NOT start the repeat — that waits for hold.
            onTap?(def)
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                guard let self, self.longPressTimer != nil else { return }
                self.startRepeat()
            }
        case .space:
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in self?.beginTrackpad() }
        default: break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        if popover != nil {
            let q = t.location(in: popover)
            if let idx = altLabels.firstIndex(where: { $0.frame.insetBy(dx: -2, dy: -40).contains(q) }) { highlightAlt(idx) }
            return
        }
        switch def.action {
        case .character:
            // Flick down for the hinted symbol.
            if def.hint != nil, p.y - touchStart.y > 16, abs(p.x - touchStart.x) < 30 {
                flicked = true; longPressTimer?.invalidate(); preview?.removeFromSuperview(); preview = nil
            }
        case .backspace:
            // Swipe-left: cancel repeat, accumulate selection steps, show selection live.
            // Each 20pt of leftward travel selects one more character. On lift we delete all.
            let totalDelta = touchStart.x - p.x   // positive when swiping left
            if totalDelta > 20 {
                if !swipeDeleted {
                    // First entry into swipe-select mode: cancel the repeat/long-press timers
                    // and cancel the initial instant-delete if we haven't done it yet
                    // (the user is clearly swiping, not tapping).
                    swipeDeleted = true
                    repeatTimer?.invalidate(); longPressTimer?.invalidate()
                    repeatTimer = nil; longPressTimer = nil
                }
                // How many characters should be selected based on total swipe distance.
                // Threshold per character: 20pt.
                let wantSelected = Int(totalDelta / 20)
                let delta = wantSelected - swipeSelectCount
                if delta > 0 {
                    // Select more characters to the left.
                    onSwipeSelectChars?(-delta)
                    swipeSelectCount += delta
                    onHaptic?()
                }
            }
        case .shift:
            if !bounds.insetBy(dx: -10, dy: -10).contains(p) { shiftSwiped = true }
        case .space:
            let step: CGFloat = trackpad ? 7 : 12
            let delta = p.x - lastX
            if abs(p.x - touchStart.x) > 10 || dragged || trackpad {
                if !trackpad { longPressTimer?.invalidate() }
                dragged = true
                let moves = Int(delta / step)
                if moves != 0 { onSpaceDrag?(moves); lastX += CGFloat(moves) * step }
            }
        default: break
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { cleanup() }
        if popover != nil {
            if altLabels.indices.contains(selectedAlt) { onAlternate?(altLabels[selectedAlt].text ?? "") }
            return
        }
        if flicked, let h = def.hint { onAlternate?(h); return }
        switch def.action {
        case .shift where shiftSwiped:
            if let t = touches.first { onShiftRelease?(t.location(in: nil)) }
        case .backspace where swipeDeleted:
            // Commit: delete all the currently selected characters.
            if swipeSelectCount > 0 { onCommitSwipeDelete?() }
        case .backspace:
            break   // Already fired on touch-down; no-op here.
        case .space where dragged || trackpad:
            break
        default:
                    // Dynamic tap zones can route a touch that landed outside this key's visible bounds to it,
            // so judge "slid off to cancel" by distance travelled, not by the key's bounds.
            let end = touches.first?.location(in: self) ?? touchStart
            if bounds.insetBy(dx: -8, dy: -8).contains(end) || hypot(end.x - touchStart.x, end.y - touchStart.y) < 30 { onTap?(def) }
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        // If we had built up a selection, move the cursor back to where it was
        // so the cancelled gesture leaves no side-effects.
        if swipeDeleted, swipeSelectCount > 0 { onSwipeSelectChars?(swipeSelectCount) }
        cleanup()
    }

    private func startRepeat() {
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [weak self] _ in
            // Guard: if the timer was already invalidated by cleanup() but this fire snuck through,
            // do nothing. This prevents a single stray delete after touch-cancel.
            guard let self, self.repeatTimer != nil else { return }
            self.onRepeat?()
        }
    }
    private func beginTrackpad() {
        trackpad = true; updateLabel(); applyColors(); onHaptic?(); onTrackpadChanged?(true)
    }
    private func cleanup() {
        let wasTrackpad = trackpad
        pressed = false; trackpad = false; swipeSelectCount = 0
        longPressTimer?.invalidate(); repeatTimer?.invalidate(); longPressTimer = nil; repeatTimer = nil
        popover?.removeFromSuperview(); popover = nil; altLabels = []; preview?.removeFromSuperview(); preview = nil
        if wasTrackpad { updateLabel(); onTrackpadChanged?(false) }
        applyColors()
    }

    // MARK: Popups
    private func showPreview() {
        guard case .character = def.action, let host = window ?? superview else { return }
        let v = UILabel(); v.text = def.label; v.textAlignment = .center; v.font = .systemFont(ofSize: 32)
        v.textColor = palette.keyText.ui; v.backgroundColor = palette.popover.ui
        v.layer.cornerRadius = 8; v.layer.masksToBounds = true
        let f = convert(bounds, to: host)
        v.frame = CGRect(x: f.midX - 27, y: f.minY - 58, width: 54, height: 58)
        if v.frame.minY < 0 { v.frame.origin.y = 0 }
        host.addSubview(v); preview = v
    }
    private func showPopover() {
        guard !def.alternates.isEmpty, let host = window else { return }
        preview?.removeFromSuperview(); preview = nil
        let options = [def.label] + def.alternates
        let w: CGFloat = 38, h: CGFloat = 50
        let container = UIView(); container.backgroundColor = palette.popover.ui; container.layer.cornerRadius = 8
        container.layer.shadowOpacity = 0.3; container.layer.shadowRadius = 4; container.layer.shadowOffset = .zero
        altLabels = options.enumerated().map { i, s in
            let l = UILabel(frame: CGRect(x: CGFloat(i) * w + 4, y: 4, width: w, height: h - 8)); l.text = s; l.textAlignment = .center
            l.font = .systemFont(ofSize: 24); l.textColor = palette.keyText.ui; l.layer.cornerRadius = 6; l.layer.masksToBounds = true
            container.addSubview(l); return l
        }
        let total = w * CGFloat(options.count) + 8
        let f = convert(bounds, to: host)
        var x = f.midX - total / 2
        x = max(2, min(x, host.bounds.width - total - 2))
        container.frame = CGRect(x: x, y: max(0, f.minY - h - 4), width: total, height: h)
        host.addSubview(container); popover = container
        highlightAlt(0)
        onHaptic?()
    }
    private func highlightAlt(_ idx: Int) {
        selectedAlt = idx
        for (i, l) in altLabels.enumerated() { l.backgroundColor = i == idx ? accent : .clear; l.textColor = i == idx ? .white : palette.keyText.ui }
    }
}

extension UIColor {
    /// A darker shade, used for the arrow on the light-accent return key.
    func darker(by f: CGFloat = 0.35) -> UIColor {
        var h: CGFloat = 0, sat: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &sat, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h, saturation: min(1, sat + 0.1), brightness: b * (1 - f), alpha: a)
    }
}
