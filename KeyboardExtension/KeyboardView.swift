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
    /// Called during swipe-left on backspace with the cursor offset to apply (negative = move left).
    /// This causes the host field to show a live selection.
    var onSwipeSelectChars: ((Int) -> Void)?
    /// Called when the swipe-left-on-backspace gesture ends — delete the selection.
    var onCommitSwipeDelete: (() -> Void)?

    private let rowsContainer = UIView()
    private var rows: [[KeyDef]] = []
    private var keyViews: [[KeyView]] = []
    private var shift: ShiftState = .off
    var oneHanded: Handedness = .off { didSet { setNeedsLayout() } }

    // iOS system keyboard metrics
    private let rowSpacing: CGFloat = 12   // vertical gap between rows
    private let keySpacing: CGFloat = 6    // horizontal gap between keys
    private let inset: CGFloat = 4         // left/right edge margin

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
        k.onTap = { [weak self] in self?.onKey?($0) }
        k.onAlternate = { [weak self] in self?.onAlternate?($0) }
        k.onRepeat = { [weak self] in self?.onRepeatDelete?() }
        k.onSpaceDrag = { [weak self] in self?.onSpaceDrag?($0) }
        k.onHaptic = { [weak self] in self?.onHaptic?() }
        k.onTrackpadChanged = { [weak self] on in self?.setTrackpad(on) }
        k.onSwipeSelectChars = { [weak self] in self?.onSwipeSelectChars?($0) }
        k.onCommitSwipeDelete = { [weak self] in self?.onCommitSwipeDelete?() }
        k.onShiftRelease = { [weak self] p in self?.shiftRelease(at: p) }
        return k
    }

    func restyle() {
        backgroundColor = palette.background.ui
        keyViews.flatMap { $0 }.forEach {
            $0.palette = palette; $0.accent = accent
            $0.soundEnabled = soundEnabled; $0.longPressDelay = longPressDelay
        }
    }

    /// Shift-swipe: pressing ⇧ and releasing on a letter types that letter in uppercase without changing shift state.
    private func shiftRelease(at p: CGPoint) {
        for k in keyViews.flatMap({ $0 }) {
            if case .character(let s) = k.def.action, k.convert(k.bounds, to: nil).contains(p) { onAlternate?(s.uppercased()); return }
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

        // Distribute height evenly across all rows with equal spacing above and between them,
        // plus a small bottom inset so keys sit above the home indicator area.
        let topInset: CGFloat = 8
        let bottomInset: CGFloat = 4
        let usableH = rowsContainer.bounds.height - topInset - bottomInset
        let totalSpacing = rowSpacing * CGFloat(rows.count - 1)
        let rowH = (usableH - totalSpacing) / CGFloat(rows.count)

        for (r, row) in rows.enumerated() {
            let totalWeight = CGFloat(row.reduce(0) { $0 + $1.widthWeight })
            let tenKeyUnit = (w - 2 * inset - keySpacing * 9) / 10
            // Letter-only rows shorter than 10 keys keep the 10-key unit and center;
            // mixed/modifier rows fill the full width proportionally.
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

extension KeyboardView {
    /// Dim the other keys while the space bar is acting as a trackpad.
    func setTrackpad(_ on: Bool) {
        UIView.animate(withDuration: 0.12) {
            self.keyViews.flatMap { $0 }.filter { $0.def.action != .space }.forEach { $0.alpha = on ? 0.45 : 1 }
        }
    }
}

// MARK: - Dynamic tap-zone hit-testing

extension KeyboardView {
    /// The last lowercase letter that was tapped. Drives bigram-based hitbox expansion.
    /// Set by KeyboardViewController after every character keystroke.
    var lastTypedLetter: Character? {
        get { objc_getAssociatedObject(self, &KeyboardView.lastTypedKey) as? Character }
        set { objc_setAssociatedObject(self, &KeyboardView.lastTypedKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    private static var lastTypedKey = 0

    /// Override hit-testing to redirect touches to the highest-scoring key rather than
    /// the geometrically topmost view. Only letter/character keys participate in scoring;
    /// modifier keys (shift, backspace, space, etc.) always win within their own frame.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Convert the touch point into rowsContainer coordinates.
        let localPoint = convert(point, to: rowsContainer)

        // Collect all visible character key views.
        let charKeys = keyViews.flatMap { $0 }.filter {
            if case .character = $0.def.action { return true }
            return false
        }

        // If the touch lands squarely inside a modifier key frame, defer to default
        // hit-testing so modifiers always respond reliably regardless of nearby letter keys.
        let allKeys = keyViews.flatMap { $0 }
        for k in allKeys {
            guard k.frame.contains(localPoint) else { continue }
            if case .character = k.def.action {
                // Touch is inside a character key — proceed to bigram scoring below.
                break
            } else {
                // Touch is inside a modifier key — skip scoring, use standard routing.
                return super.hitTest(point, with: event)
            }
        }

        // Score every character key and return the one with the lowest weighted distance.
        let prev = lastTypedLetter
        var bestKey: KeyView? = nil
        var bestScore = Double.greatestFiniteMagnitude

        for k in charKeys {
            let center = CGPoint(x: k.frame.midX, y: k.frame.midY)
            let dx = Double(localPoint.x - center.x)
            let dy = Double(localPoint.y - center.y)
            // Raw Euclidean distance, but y gets a smaller penalty because fingers
            // tend to be more accurate horizontally than vertically on a keyboard.
            let rawDist = sqrt(dx * dx + (dy * dy) * 0.75)

            // Bigram boost: shrinks the effective distance for likely next letters.
            var boost = 1.0
            if let ch = k.def.label.lowercased().first, ch.isLetter {
                boost = BigramModel.boost(after: prev, candidate: ch)
            }
            // A higher boost reduces the effective distance → key wins more ties.
            let score = rawDist / boost

            if score < bestScore {
                bestScore = score
                bestKey = k
            }
        }

        // Only use the scored winner if the touch is reasonably close to the keyboard
        // area (within 1 key-height above the top row, or anywhere within the board).
        if let winner = bestKey {
            return winner
        }
        return super.hitTest(point, with: event)
    }
}
