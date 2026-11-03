import UIKit

/// Root keyboard view: key rows (plus one-handed offset). Rebuilds key views only when the layout actually changes.
final class KeyboardView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool { true }

    var palette: ThemePalette = .light { didSet { restyle() } }
    var accent: UIColor = .systemBlue { didSet { restyle() } }
    var soundEnabled = true
    var longPressDelay: TimeInterval = 0.35
    var onKey: ((KeyDef) -> Void)?
    var onAlternate: ((String) -> Void)?
    var onRepeatDelete: (() -> Void)?
    var onSpaceDrag: ((Int) -> Void)?
    var onHaptic: (() -> Void)?
    var onSwipeSelectChars: ((Int) -> Void)?
    var onCommitSwipeDelete: (() -> Void)?
    var onSelectDrag: ((Int) -> Void)?

    private let rowsContainer = UIView()
    private var rows: [[KeyDef]] = []
    private var keyViews: [[KeyView]] = []
    private var shift: ShiftState = .off
    var oneHanded: Handedness = .off { didSet { setNeedsLayout() } }

    private let rowSpacing: CGFloat = 12
    private let keySpacing: CGFloat = 6
    private let inset: CGFloat = 4

    // Tracks whether shift is physically down for shift+space selection trackpad.
    private var shiftIsHeld = false

    // Tracks UITouch objects currently active on modifier keys.
    // Using a Set<ObjectIdentifier> (wrapping the touch pointer) avoids retaining
    // UITouch objects and is safe from the asyncAfter race that previously crashed.
    private var activeModifierTouchIDs = Set<ObjectIdentifier>()

    init() {
        super.init(frame: .zero, inputViewStyle: .keyboard)
        allowsSelfSizing = true
        addSubview(rowsContainer)
        restyle()
    }
    required init?(coder: NSCoder) { fatalError() }

    func setRows(_ newRows: [[KeyDef]], shift newShift: ShiftState) {
        if newRows != rows {
            keyViews.flatMap { $0 }.forEach { $0.removeFromSuperview() }
            rows = newRows
            keyViews = newRows.map { row in row.map(makeKey) }
            keyViews.flatMap { $0 }.forEach(rowsContainer.addSubview)
            setNeedsLayout()
        }
        if newShift != shift {
            shift = newShift
            keyViews.flatMap { $0 }.filter { $0.def.action == .shift }.forEach { $0.shiftState = newShift }
        }
    }

    private func makeKey(_ d: KeyDef) -> KeyView {
        let k = KeyView(def: d, palette: palette, accent: accent)
        k.soundEnabled = soundEnabled; k.longPressDelay = longPressDelay
        switch d.action {
        case .shift:
            k.onTap = { [weak self] key in
                self?.shiftIsHeld = false
                self?.onKey?(key)
            }
            k.onShiftRelease = { [weak self] p in
                self?.shiftIsHeld = false
                self?.shiftRelease(at: p)
            }
        default:
            k.onTap = { [weak self] in self?.onKey?($0) }
        }
        k.onAlternate = { [weak self] in self?.onAlternate?($0) }
        k.onRepeat = { [weak self] in self?.onRepeatDelete?() }
        k.onSpaceDrag = { [weak self] in self?.onSpaceDrag?($0) }
        k.onHaptic = { [weak self] in self?.onHaptic?() }
        k.onTrackpadChanged = { [weak self] on in
            if !on { self?.shiftIsHeld = false }
            self?.setTrackpad(on)
        }
        k.onSwipeSelectChars = { [weak self] in self?.onSwipeSelectChars?($0) }
        k.onCommitSwipeDelete = { [weak self] in self?.onCommitSwipeDelete?() }
        k.onSelectDrag = { [weak self] in self?.onSelectDrag?($0) }
        return k
    }

    func restyle() {
        backgroundColor = palette.background.ui
        keyViews.flatMap { $0 }.forEach {
            $0.palette = palette; $0.accent = accent
            $0.soundEnabled = soundEnabled; $0.longPressDelay = longPressDelay
        }
    }

    private func shiftRelease(at p: CGPoint) {
        for k in keyViews.flatMap({ $0 }) {
            if case .character(let s) = k.def.action, k.convert(k.bounds, to: nil).contains(p) {
                onAlternate?(s.uppercased()); return
            }
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let full = bounds.width
        let w = oneHanded == .off ? full : full * 0.8
        let originX: CGFloat = oneHanded == .right ? full - w : 0
        rowsContainer.frame = CGRect(x: originX, y: 0, width: w, height: bounds.height)
        rowsContainer.bounds = CGRect(x: 0, y: 0, width: w, height: bounds.height)
        guard !rows.isEmpty else { return }

        let topInset: CGFloat = 8
        let bottomInset: CGFloat = 4
        let usableH = rowsContainer.bounds.height - topInset - bottomInset
        let totalSpacing = rowSpacing * CGFloat(rows.count - 1)
        let rowH = (usableH - totalSpacing) / CGFloat(rows.count)

        for (r, row) in rows.enumerated() {
            let totalWeight = CGFloat(row.reduce(0) { $0 + $1.widthWeight })
            let tenKeyUnit = (w - 2 * inset - keySpacing * 9) / 10
            let shortLetterRow = row.count < 10 && row.allSatisfy { !$0.isModifier }
            let unit = shortLetterRow
                ? tenKeyUnit
                : (w - 2 * inset - keySpacing * CGFloat(row.count - 1)) / totalWeight
            let rowWidth = shortLetterRow
                ? unit * totalWeight + keySpacing * CGFloat(row.count - 1)
                : w - 2 * inset
            var x = (w - rowWidth) / 2
            let y = topInset + CGFloat(r) * (rowH + rowSpacing)
            for (i, k) in keyViews[r].enumerated() {
                let kw = unit * CGFloat(row[i].widthWeight)
                k.frame = CGRect(x: x, y: y, width: kw, height: rowH)
                x += kw + keySpacing
            }
        }
    }

    // MARK: - Trackpad dimming

    func setTrackpad(_ on: Bool) {
        UIView.animate(withDuration: 0.12) {
            self.keyViews.flatMap { $0 }.filter { $0.def.action != .space }.forEach { $0.alpha = on ? 0.45 : 1 }
        }
    }

    // MARK: - Touch tracking for modifier-touch suppression

    /// Keep the active-modifier set in sync by observing every touch event that
    /// passes through this view. This is called by UIKit before hitTest on each
    /// touch event, so it is always up to date.
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
    }

    // MARK: - Dynamic tap-zone hit-testing

    /// The last lowercase letter that was tapped. Drives bigram-based hitbox expansion.
    var lastTypedLetter: Character? {
        get { objc_getAssociatedObject(self, &KeyboardView.lastTypedKey) as? Character }
        set { objc_setAssociatedObject(self, &KeyboardView.lastTypedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    private static var lastTypedKey = 0

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Guard: only process touches that are actually within our bounds.
        guard bounds.contains(point), !isHidden, alpha > 0.01, isUserInteractionEnabled else {
            return nil
        }

        // Update active-modifier-touch tracking from the live event.
        // UIKit passes the current UIEvent to hitTest; its allTouches set reflects
        // exactly which touches are on-screen right now. We use ObjectIdentifier(touch)
        // as a stable pointer-based key so we never retain the UITouch itself.
        if let event = event {
            let liveTouchIDs = Set((event.allTouches ?? []).map { ObjectIdentifier($0) })
            // Remove any IDs that are no longer live (touch ended / cancelled).
            activeModifierTouchIDs.formIntersection(liveTouchIDs)
        }

        let localPoint = convert(point, to: rowsContainer)
        let allKeys = keyViews.flatMap { $0 }

        // --- Step 1: Find the geometrically hit key (if any) ---
        var hitCharKey: KeyView? = nil
        var hitModifierKey: KeyView? = nil
        for k in allKeys {
            guard k.frame.contains(localPoint) else { continue }
            if case .character = k.def.action {
                hitCharKey = k
            } else {
                hitModifierKey = k
            }
            break  // frames don't overlap; first match is the answer
        }

        // --- Step 2: If a modifier key was directly hit, register it and return it ---
        if let modKey = hitModifierKey {
            if let event = event {
                for touch in event.allTouches ?? [] {
                    // A touch in .began phase that lands on this modifier key gets registered.
                    if touch.phase == .began {
                        activeModifierTouchIDs.insert(ObjectIdentifier(touch))
                    }
                }
            }
            if modKey.def.action == .shift { shiftIsHeld = true }
            return modKey
        }

        // --- Step 3: If any modifier touch is still live, bypass bigram scoring ---
        // This ensures a swipe that started on backspace/space is never stolen.
        if !activeModifierTouchIDs.isEmpty {
            // Return the geometrically hit character key if there is one,
            // otherwise let the touch go to whatever super finds.
            return hitCharKey ?? super.hitTest(point, with: event)
        }

        // --- Step 4: No modifier touches active — apply bigram scoring ---
        let charKeys = allKeys.filter { if case .character = $0.def.action { return true }; return false }
        guard !charKeys.isEmpty else { return hitCharKey ?? super.hitTest(point, with: event) }

        let prev = lastTypedLetter
        var bestKey: KeyView? = nil
        var bestScore = Double.greatestFiniteMagnitude

        for k in charKeys {
            if k.def.action == .space { k.shiftHeld = shiftIsHeld }
            let center = CGPoint(x: k.frame.midX, y: k.frame.midY)
            let dx = Double(localPoint.x - center.x)
            let dy = Double(localPoint.y - center.y)
            let rawDist = (dx * dx + dy * dy * 0.75).squareRoot()
            var boost = 1.0
            if let ch = k.def.label.lowercased().first, ch.isLetter {
                boost = BigramModel.boost(after: prev, candidate: ch)
            }
            let score = rawDist / boost
            if score < bestScore { bestScore = score; bestKey = k }
        }

        // Only redirect to the scored winner when the touch is within the keyboard area.
        // If the touch is far outside all keys (e.g. above the top row), fall back to
        // standard hit-testing so other subviews (popover, preview) can receive it.
        if let winner = bestKey, bestScore < 200 { return winner }
        return super.hitTest(point, with: event)
    }
}
