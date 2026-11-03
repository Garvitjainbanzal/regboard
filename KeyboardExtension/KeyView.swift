import UIKit

/// A single key view. Matches the iOS system keyboard visual language:
/// flat rounded rectangles, large corner radius, no drop shadows on letter keys,
/// subtle shadow only on letter keys in light mode, SF Symbol glyphs for shift/delete.
final class KeyView: UIView {

    // MARK: - Public configuration

    let def: KeyDef
    var palette: ThemePalette { didSet { applyColors() } }
    var accent: UIColor       { didSet { applyColors() } }
    var shiftState: ShiftState = .off { didSet { applyColors(); updateLabel() } }

    var onTap:              ((KeyDef) -> Void)?
    var onAlternate:        ((String) -> Void)?
    var onRepeat:           (() -> Void)?
    var onSpaceDrag:        ((Int) -> Void)?
    var onHaptic:           (() -> Void)?
    var onSwipeSelectChars: ((Int) -> Void)?
    var onCommitSwipeDelete:(() -> Void)?
    var onTrackpadChanged:  ((Bool) -> Void)?
    var onSelectDrag:       ((Int) -> Void)?
    var onShiftRelease:     ((CGPoint) -> Void)?
    var longPressDelay: TimeInterval = 0.35
    var soundEnabled = true
    /// Set by KeyboardView before the touch lands on space, when shift is held.
    var shiftHeld: Bool = false

    // MARK: - Private subviews

    // Main glyph — UILabel for characters, UIImageView for SF Symbol keys.
    private let label      = UILabel()
    private let symbolView = UIImageView()   // used for shift and backspace
    private let hintLabel  = UILabel()       // small flick-hint (hidden by default)
    private let badgeLabel = UILabel()

    // MARK: - Gesture state

    private var popover:    UIView?
    private var altLabels:  [UILabel] = []
    private var preview:    UIView?
    private var longPressTimer: Timer?
    private var repeatTimer:    Timer?
    private var touchStart:  CGPoint = .zero
    private var lastX: CGFloat = 0

    private var swipeSelectCount = 0
    private var swipeDeleted     = false
    private var dragged          = false
    private var trackpad         = false
    private var selectionTrackpad = false
    private var selectionOffset   = 0
    private var shiftSwiped = false
    private var flicked     = false
    private var selectedAlt = 0
    private var pressed = false { didSet { applyColors() } }

    // MARK: - Init

    init(def: KeyDef, palette: ThemePalette, accent: UIColor) {
        self.def = def; self.palette = palette; self.accent = accent
        super.init(frame: .zero)

        // Corner radius is set in layoutSubviews once we know the actual height.
        // No drop shadow — the iOS system keyboard in dark mode is completely flat.
        layer.masksToBounds = true

        // Label (used for character/text keys)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        // Symbol view (shift ⇧ and backspace ⌫ use SF Symbols for crisp rendering)
        symbolView.contentMode = .scaleAspectFit
        symbolView.isUserInteractionEnabled = false
        symbolView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(symbolView)

        // Hint label (small superscript in top-right for flick symbols)
        hintLabel.font = .systemFont(ofSize: 10, weight: .regular)
        hintLabel.textAlignment = .right
        hintLabel.text = def.hint
        hintLabel.isUserInteractionEnabled = false
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.isHidden = true   // hidden by default; shown only when flickSymbols is on
        addSubview(hintLabel)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -2),

            symbolView.centerXAnchor.constraint(equalTo: centerXAnchor),
            symbolView.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.6),
            symbolView.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, multiplier: 0.6),

            hintLabel.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            hintLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
        ])

        if let b = def.badge {
            badgeLabel.text = b
            badgeLabel.numberOfLines = 2
            badgeLabel.font = .systemFont(ofSize: 9, weight: .medium)
            badgeLabel.isUserInteractionEnabled = false
            badgeLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(badgeLabel)
            NSLayoutConstraint.activate([
                badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
                badgeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            ])
        }

        isAccessibilityElement = true
        accessibilityTraits = .keyboardKey
        accessibilityLabel = KeyView.accessibilityName(for: def)
        if let h = def.hint { accessibilityHint = "Pull down to type \(h)" }

        updateLabel()
        applyColors()
    }
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Accessibility

    static func accessibilityName(for d: KeyDef) -> String {
        switch d.action {
        case .shift:           return "Shift"
        case .backspace:       return "Delete"
        case .space:           return "Space"
        case .returnKey:       return d.label
        case .switchToLetters: return "Letters"
        case .switchToNumbers: return "Numbers"
        case .switchToSymbols: return "Symbols"
        case .nextKeyboard:    return "Next keyboard"
        case .emoji:           return "Emoji"
        case .character(let s):return s
        case .hideKeyboard:    return "Hide keyboard"
        }
    }

    // MARK: - Label / glyph update

    private func updateLabel() {
        // Decide what to show based on key type
        switch def.action {

        case .shift:
            // SF Symbol: filled arrow for shift, double-filled for caps lock
            label.isHidden = true
            symbolView.isHidden = false
            let name = shiftState == .capsLock ? "capslock.fill" : "shift.fill"
            symbolView.image = UIImage(systemName: name,
                withConfiguration: UIImage.SymbolConfiguration(weight: .medium))

        case .backspace:
            label.isHidden = true
            symbolView.isHidden = false
            symbolView.image = UIImage(systemName: "delete.backward",
                withConfiguration: UIImage.SymbolConfiguration(weight: .regular))

        case .space where (trackpad || selectionTrackpad):
            label.isHidden = false
            symbolView.isHidden = true
            label.text = "◀  ▶"
            configureFont(for: "◀  ▶")

        default:
            label.isHidden = false
            symbolView.isHidden = true
            let text: String
            switch def.action {
            case .returnKey where def.label == "return": text = "return"
            default: text = def.label
            }
            label.text = text
            configureFont(for: text)
        }

        // Flick hint
        hintLabel.text = def.hint
        hintLabel.isHidden = def.hint == nil

        // Accessibility
        if def.action == .shift {
            accessibilityValue = shiftState == .off ? "off"
                : (shiftState == .once ? "on" : "caps lock")
        }
    }

    private func configureFont(for text: String) {
        let isMultiChar = text.count > 1 && def.action != .space
        let base: CGFloat
        switch def.action {
        case .space:        base = 16
        case .returnKey:    base = 16
        case .switchToNumbers, .switchToLetters, .switchToSymbols: base = 16
        default:            base = isMultiChar ? 15 : 22
        }
        label.font = UIFontMetrics(forTextStyle: .body)
            .scaledFont(for: .systemFont(ofSize: base, weight: .regular),
                        maximumPointSize: base * 1.3)
        label.adjustsFontForContentSizeCategory = true
    }

    // MARK: - Color

    private func applyColors() {
        // Determine the correct background for this key state
        let isModifier: Bool
        switch def.action {
        case .character, .space: isModifier = false
        default: isModifier = true
        }

        var bg = isModifier ? palette.modifierKey.ui : palette.key.ui

        // Shift highlight: when active, shift shows as a letter key (lighter in dark)
        if def.action == .shift, shiftState != .off {
            bg = palette.key.ui
        }
        // Press inversion: momentary feedback
        if pressed {
            bg = isModifier ? palette.key.ui : palette.modifierKey.ui
        }
        // Trackpad tint
        if trackpad || selectionTrackpad {
            bg = accent.withAlphaComponent(0.3)
        }

        backgroundColor = bg

        // Text / tint color
        let textColor = palette.keyText.ui
        label.textColor = textColor
        symbolView.tintColor = textColor
        hintLabel.textColor = textColor.withAlphaComponent(0.4)
        badgeLabel.textColor = textColor.withAlphaComponent(0.5)

        // Caps lock: accent-tint the symbol
        if def.action == .shift, shiftState == .capsLock {
            symbolView.tintColor = accent
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // Corner radius: ~22% of key height, matching iOS system keyboard.
        // Clamped to [8, 12] so very short/tall keys still look reasonable.
        layer.cornerRadius = min(max(bounds.height * 0.22, 8), 12)
    }

    // MARK: - Touch handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        pressed = true
        dragged = false; swipeDeleted = false; shiftSwiped = false
        flicked = false; trackpad = false; selectionTrackpad = false
        swipeSelectCount = 0; selectionOffset = 0
        touchStart = t.location(in: self); lastX = touchStart.x
        if soundEnabled { UIDevice.current.playInputClick() }
        onHaptic?()

        switch def.action {
        case .character:
            showPreview()
            if !def.alternates.isEmpty {
                longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressDelay, repeats: false) { [weak self] _ in
                    self?.showPopover()
                }
            }

        case .backspace:
            onTap?(def)
            longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: false) { [weak self] _ in
                guard let self, self.longPressTimer != nil else { return }
                self.startRepeat()
            }

        case .space:
            if shiftHeld {
                beginSelectionTrackpad()
            } else {
                longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
                    self?.beginTrackpad()
                }
            }

        default: break
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)

        if popover != nil {
            let q = t.location(in: popover)
            if let idx = altLabels.firstIndex(where: { $0.frame.insetBy(dx: -2, dy: -40).contains(q) }) {
                highlightAlt(idx)
            }
            return
        }

        switch def.action {
        case .character:
            if def.hint != nil, p.y - touchStart.y > 16, abs(p.x - touchStart.x) < 30 {
                flicked = true; longPressTimer?.invalidate()
                preview?.removeFromSuperview(); preview = nil
            }

        case .backspace:
            handleBackspaceMoved(to: p)

        case .shift:
            if !bounds.insetBy(dx: -10, dy: -10).contains(p) { shiftSwiped = true }

        case .space:
            handleSpaceMoved(to: p)

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
            if swipeSelectCount > 0 { onCommitSwipeDelete?() }

        case .backspace:
            break

        case .space where dragged || trackpad || selectionTrackpad:
            break

        default:
            if bounds.insetBy(dx: -8, dy: -8).contains(touches.first?.location(in: self) ?? .zero) {
                onTap?(def)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        if swipeDeleted, swipeSelectCount > 0 { onSwipeSelectChars?(swipeSelectCount) }
        if selectionTrackpad, selectionOffset != 0 { onSelectDrag?(-selectionOffset) }
        cleanup()
    }

    // MARK: - Backspace swipe

    private func handleBackspaceMoved(to p: CGPoint) {
        let totalDelta = touchStart.x - p.x
        guard totalDelta > 10 else { return }

        if !swipeDeleted {
            onSwipeSelectChars?(1)
            onSwipeSelectChars?(-1)
            swipeSelectCount = 1
            swipeDeleted = true
            repeatTimer?.invalidate(); repeatTimer = nil
            longPressTimer?.invalidate(); longPressTimer = nil
            onHaptic?()
        }

        let wantSelected = max(1, Int(totalDelta / 20))
        let delta = wantSelected - swipeSelectCount

        if delta > 0 {
            onSwipeSelectChars?(-delta)
            swipeSelectCount += delta
            onHaptic?()
        } else if delta < 0 {
            let shrink = -delta
            onSwipeSelectChars?(shrink)
            swipeSelectCount -= shrink
            if swipeSelectCount <= 0 { swipeSelectCount = 0; swipeDeleted = false }
            onHaptic?()
        }
    }

    // MARK: - Space drag

    private func handleSpaceMoved(to p: CGPoint) {
        if selectionTrackpad {
            let step: CGFloat = 7
            let dx = p.x - lastX
            let moves = Int(dx / step)
            if moves != 0 { onSelectDrag?(moves); selectionOffset += moves; lastX += CGFloat(moves) * step }
            return
        }
        let step: CGFloat = trackpad ? 7 : 12
        let dx = p.x - lastX
        if abs(p.x - touchStart.x) > 10 || dragged || trackpad {
            if !trackpad { longPressTimer?.invalidate() }
            dragged = true
            let moves = Int(dx / step)
            if moves != 0 { onSpaceDrag?(moves); lastX += CGFloat(moves) * step }
        }
    }

    // MARK: - Trackpad

    private func beginTrackpad() {
        trackpad = true; updateLabel(); applyColors(); onHaptic?(); onTrackpadChanged?(true)
    }
    private func beginSelectionTrackpad() {
        selectionTrackpad = true; updateLabel(); applyColors(); onHaptic?(); onTrackpadChanged?(true)
    }

    // MARK: - Repeat delete

    private func startRepeat() {
        repeatTimer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: true) { [weak self] _ in
            guard let self, self.repeatTimer != nil else { return }
            self.onRepeat?()
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        let wasTrackpad = trackpad || selectionTrackpad
        pressed = false; trackpad = false; selectionTrackpad = false
        swipeSelectCount = 0; selectionOffset = 0
        longPressTimer?.invalidate(); repeatTimer?.invalidate()
        longPressTimer = nil; repeatTimer = nil
        popover?.removeFromSuperview(); popover = nil; altLabels = []
        preview?.removeFromSuperview(); preview = nil
        if wasTrackpad { updateLabel(); onTrackpadChanged?(false) }
        applyColors()
    }

    // MARK: - Key-press preview popup

    private func showPreview() {
        guard case .character = def.action, let host = window ?? superview else { return }
        let v = UILabel()
        v.text = def.label
        v.textAlignment = .center
        v.font = .systemFont(ofSize: 32)
        v.textColor = palette.keyText.ui
        v.backgroundColor = palette.popover.ui
        v.layer.cornerRadius = 10
        v.layer.masksToBounds = true
        let f = convert(bounds, to: host)
        v.frame = CGRect(x: f.midX - 27, y: f.minY - 58, width: 54, height: 58)
        if v.frame.minY < 0 { v.frame.origin.y = 0 }
        host.addSubview(v); preview = v
    }

    // MARK: - Long-press alternates popover

    private func showPopover() {
        guard !def.alternates.isEmpty, let host = window else { return }
        preview?.removeFromSuperview(); preview = nil
        let options = [def.label] + def.alternates
        let w: CGFloat = 38, h: CGFloat = 50
        let container = UIView()
        container.backgroundColor = palette.popover.ui
        container.layer.cornerRadius = 10
        container.layer.shadowOpacity = 0.25
        container.layer.shadowRadius = 6
        container.layer.shadowOffset = .zero
        container.layer.masksToBounds = false
        altLabels = options.enumerated().map { i, s in
            let l = UILabel(frame: CGRect(x: CGFloat(i) * w + 4, y: 4, width: w, height: h - 8))
            l.text = s; l.textAlignment = .center; l.font = .systemFont(ofSize: 24)
            l.textColor = palette.keyText.ui; l.layer.cornerRadius = 8; l.layer.masksToBounds = true
            container.addSubview(l); return l
        }
        let total = w * CGFloat(options.count) + 8
        let f = convert(bounds, to: host)
        var x = f.midX - total / 2
        x = max(2, min(x, host.bounds.width - total - 2))
        container.frame = CGRect(x: x, y: max(0, f.minY - h - 4), width: total, height: h)
        host.addSubview(container); popover = container
        highlightAlt(0); onHaptic?()
    }

    private func highlightAlt(_ idx: Int) {
        selectedAlt = idx
        for (i, l) in altLabels.enumerated() {
            l.backgroundColor = i == idx ? accent : .clear
            l.textColor = i == idx ? .white : palette.keyText.ui
        }
    }
}

// MARK: - UIColor helpers

extension UIColor {
    /// Returns a version of the color darkened by the given fraction.
    func darker(by f: CGFloat = 0.35) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard getHue(&h, saturation: &s, brightness: &b, alpha: &a) else { return self }
        return UIColor(hue: h, saturation: min(1, s + 0.1), brightness: b * (1 - f), alpha: a)
    }
}
