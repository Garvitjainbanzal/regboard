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
    var onSwipeDeleteWord: (() -> Void)?

    private let rowsContainer = UIView()
    private var rows: [[KeyDef]] = []
    private var keyViews: [[KeyView]] = []
    private var shift: ShiftState = .off
    var oneHanded: Handedness = .off { didSet { setNeedsLayout() } }
    private let rowSpacing: CGFloat = 8, keySpacing: CGFloat = 5, inset: CGFloat = 3

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
        shift = newShift
        keyViews.flatMap { $0 }.filter { $0.def.action == .shift }.forEach { $0.shiftState = newShift }
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
        k.onSwipeDeleteWord = { [weak self] in self?.onSwipeDeleteWord?() }
        k.onShiftRelease = { [weak self] p in self?.shiftRelease(at: p) }
        return k
    }

    func restyle() {
        backgroundColor = palette.background.ui
        keyViews.flatMap { $0 }.forEach { $0.palette = palette; $0.accent = accent; $0.soundEnabled = soundEnabled; $0.longPressDelay = longPressDelay }
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
        let rowH = (rowsContainer.bounds.height - CGFloat(rows.count + 1) * rowSpacing + rowSpacing) / CGFloat(rows.count)
        for (r, row) in rows.enumerated() {
            let totalWeight = CGFloat(row.reduce(0) { $0 + $1.widthWeight })
            let tenKeyUnit = (w - 2 * inset - keySpacing * 9) / 10
            // Letter-only rows shorter than 10 keys keep the 10-key width and are centered; others fill the row.
            let shortLetterRow = row.count < 10 && row.allSatisfy { !$0.isModifier }
            let unit = shortLetterRow ? tenKeyUnit : (w - 2 * inset - keySpacing * CGFloat(row.count - 1)) / totalWeight
            let rowWidth = shortLetterRow ? unit * totalWeight + keySpacing * CGFloat(row.count - 1) : w - 2 * inset
            var x = (w - rowWidth) / 2
            let y = rowSpacing / 2 + CGFloat(r) * (rowH + rowSpacing)
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
        UIView.animate(withDuration: 0.12) { self.keyViews.flatMap { $0 }.filter { $0.def.action != .space }.forEach { $0.alpha = on ? 0.45 : 1 } }
    }
}
