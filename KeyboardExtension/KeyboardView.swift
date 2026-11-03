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
    /// Backspace swipe: incremental cursor-position delta to show live selection.
    var onSwipeSelectChars: ((Int) -> Void)?
    /// Backspace swipe commit: delete the current selection.
    var onCommitSwipeDelete: (() -> Void)?
    /// Shift+space selection trackpad: cumulative character offset (positive = forward).
    var onSelectDrag: ((Int) -> Void)?

    private let rowsContainer = UIView()
    private var rows: [[KeyDef]] = []
    private var keyViews: [[KeyView]] = []
    private var shift: ShiftState = .off
    var oneHanded: Handedness = .off { didSet { setNeedsLayout() } }

    // iOS system keyboard metrics
    private let rowSpacing: CGFloat = 12
    private let keySpacing: CGFloat = 6
    private let inset: CGFloat = 4

    // Tracks whether the shift key is currently being held (finger down).
    // Used to immediately enter selection-trackpad on a simultaneous space touch.
    private var shiftIsHeld = false

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
}

// MARK: - Trackpad / selection trackpad dimming

extension KeyboardView {
    func setTrackpad(_ on: Bool) {
        UIView.animate(withDuration: 0.12) {
            self.keyViews.flatMap { $0 }.filter { $0.def.action != .space }.forEach { $0.alpha = on ? 0.45 : 1 }
        }
    }
}

// MARK: - Dynamic tap-zone hit-testing

extension KeyboardView {
    /// The last lowercase letter that was tapped. Drives bigram-based hitbox expansion.
    var lastTypedLetter: Character? {
        get { objc_getAssociatedObject(self, &KeyboardView.lastTypedKey) as? Character }
        set { objc_setAssociatedObject(self, &KeyboardView.lastTypedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    private static var lastTypedKey = 0

    /// Tracks how many touches are currently active on non-character (modifier) keys.
    /// When non-zero the bigram scoring is suppressed, protecting mid-gesture swipes
    /// on backspace / space from being hijacked to a letter key.
    private var activeModifierTouches: Int {
        get { (objc_getAssociatedObject(self, &KeyboardView.activeModifierKey) as? Int) ?? 0 }
        set { objc_setAssociatedObject(self, &KeyboardView.activeModifierKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    private static var activeModifierKey = 0

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let localPoint = convert(point, to: rowsContainer)

        // Determine what key the point lands inside geometrically.
        let allKeys = keyViews.flatMap { $0 }

        // Check if we're inside a modifier key frame first.
        for k in allKeys {
            guard k.frame.contains(localPoint) else { continue }
            if case .character = k.def.action {
                // Inside a character key — fall through to bigram scoring.
                break
            } else {
                // Inside a modifier key.
                // Track shift being held for shift+space detection.
                if k.def.action == .shift {
                    shiftIsHeld = true
                    // Will be cleared when shift key fires onTap or onShiftRelease.
                }
                // Suppress bigram scoring for as long as this touch is active.
                // UIKit calls hitTest once per touch-begin event; we mark that a
                // modifier touch is in flight so subsequent scoring passes are skipped.
                activeModifierTouches += 1
                // Schedule a cleanup after a short delay since there's no touch-end
                // callback at this level (UIView.hitTest has no paired "end").
                // We use a weak reference to avoid a retain cycle.
                let weakSelf = self
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    weakSelf.activeModifierTouches = max(0, weakSelf.activeModifierTouches - 1)
                }
                return super.hitTest(point, with: event)
            }
        }

        // If any modifier touch is currently active (e.g. finger sliding off backspace
        // onto the letter rows), skip bigram scoring entirely and use standard hit-test.
        // This prevents the swipe-left gesture from being stolen mid-slide.
        if activeModifierTouches > 0 {
            return super.hitTest(point, with: event)
        }

        // Bigram scoring: find the character key with the lowest weighted distance.
        let charKeys = allKeys.filter { if case .character = $0.def.action { return true }; return false }
        let prev = lastTypedLetter
        var bestKey: KeyView? = nil
        var bestScore = Double.greatestFiniteMagnitude

        for k in charKeys {
            // Also tell the space key whether shift is held before touch begins.
            if k.def.action == .space { k.shiftHeld = shiftIsHeld }

            let center = CGPoint(x: k.frame.midX, y: k.frame.midY)
            let dx = Double(localPoint.x - center.x)
            let dy = Double(localPoint.y - center.y)
            let rawDist = sqrt(dx * dx + dy * dy * 0.75)
            var boost = 1.0
            if let ch = k.def.label.lowercased().first, ch.isLetter {
                boost = BigramModel.boost(after: prev, candidate: ch)
            }
            let score = rawDist / boost
            if score < bestScore { bestScore = score; bestKey = k }
        }

        if let winner = bestKey { return winner }
        return super.hitTest(point, with: event)
    }
}
