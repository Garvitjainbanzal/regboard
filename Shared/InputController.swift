import Foundation

/// The subset of UITextDocumentProxy the logic needs. The extension adapts the real proxy to this.
public protocol TextProxy: AnyObject {
    var documentContextBeforeInput: String? { get }
    var documentContextAfterInput: String? { get }
    func insertText(_ text: String)
    func deleteBackward()
    func adjustTextPosition(byCharacterOffset offset: Int)
}

public struct KeyboardTraits: Equatable {
    public var autocapitalization: AutoCapitalization.Mode = .sentences
    public var isSecure = false
    public var returnKeyLabel = "return"
    public init() {}
}

/// Platform-independent keyboard state machine. All text goes through `TextProxy`.
/// There is deliberately no prediction, autocorrection or learning: the keyboard only types what is pressed,
/// plus two optional, rule-based conveniences (double-space period, auto punctuation).
public final class InputController {
    public private(set) var page: LayoutPage = .letters
    public private(set) var shift: ShiftState = .once
    public var settings: KeyboardSettings
    public var traits = KeyboardTraits()
    /// Mirrors UIInputViewController.needsInputModeSwitchKey.
    public var needsGlobe = true
    public var onChange: (() -> Void)?
    public var onNextKeyboard: (() -> Void)?
    public var onEmoji: (() -> Void)?
    public var onHide: (() -> Void)?

    private let proxy: TextProxy
    private let now: () -> Date
    private var lastShiftTap: Date = .distantPast
    private var lastSpace: Date = .distantPast
    private var lastWasSpace = false

    public init(proxy: TextProxy, settings: KeyboardSettings = KeyboardSettings(), now: @escaping () -> Date = Date.init) {
        self.proxy = proxy; self.settings = settings; self.now = now
    }

    public func apply(settings s: KeyboardSettings) { settings = s; notify() }
    public func textContextChanged() { notify() }

    /// Resets state for a new text field.
    public func beginEditing() {
        page = .letters; shift = .off; lastWasSpace = false
        updateShiftFromContext(afterAction: .space)
        notify()
    }

    // MARK: Key handling
    public func handle(_ action: KeyAction) {
        let wasSpace = lastWasSpace
        lastWasSpace = false
        switch action {
        case .character(let s): typeCharacter(s)
        case .space: typeSpace(previousWasSpace: wasSpace)
        case .returnKey: proxy.insertText("\n")
        case .backspace: proxy.deleteBackward()
        case .shift:
            let t = now(); let dbl = t.timeIntervalSince(lastShiftTap) < 0.4
            lastShiftTap = t; shift = shift.afterTap(doubleTap: dbl)
        case .switchToLetters: page = .letters
        case .switchToNumbers: page = .numbers
        case .switchToSymbols: page = .symbols
        case .nextKeyboard: onNextKeyboard?()
        case .emoji: onEmoji?()
        case .hideKeyboard: onHide?()
        }
        updateShiftFromContext(afterAction: action)
        notify()
    }

    /// Inserts a long-press alternate / flick symbol, behaving like typing that character.
    /// The sentinel "⌄" is used by the "." key's long-press to trigger hideKeyboard.
    public func insertAlternate(_ s: String) {
        if s == "⌄" { onHide?(); return }
        handle(.character(s))
    }

    /// Drag on the space bar / trackpad: positive offset moves the cursor forward.
    public func moveCursor(by offset: Int) {
        guard offset != 0 else { return }
        proxy.adjustTextPosition(byCharacterOffset: offset)
        lastWasSpace = false
        notify()
    }

    /// Swipe-left on ⌫: removes trailing spaces, then one word (or one symbol).
    public func deleteWord() {
        lastWasSpace = false
        while proxy.documentContextBeforeInput?.last == " " { proxy.deleteBackward() }
        let ctx = proxy.documentContextBeforeInput ?? ""
        var n = 0
        for ch in ctx.reversed() { if Self.isWordChar(ch) { n += 1 } else { break } }
        if n == 0, !ctx.isEmpty { n = 1 }
        for _ in 0..<n { proxy.deleteBackward() }
        updateShiftFromContext(afterAction: .backspace); notify()
    }

    /// Repeating delete used by long-press.
    public func repeatDelete() { lastWasSpace = false; proxy.deleteBackward(); updateShiftFromContext(afterAction: .backspace); notify() }

    // MARK: Internals
    static func isWordChar(_ c: Character) -> Bool { c.isLetter || c.isNumber || c == "'" || c == "’" }

    private func typeCharacter(_ s: String) {
        if settings.autoPunctuation, !traits.isSecure, s.count == 1, let ch = s.first {
            let ctx = proxy.documentContextBeforeInput ?? ""
            if ".,!?;:".contains(ch), ctx.hasSuffix(" "), let before = ctx.dropLast().last, Self.isWordChar(before) || ")\"”]".contains(before) {
                proxy.deleteBackward()                      // "word ," -> "word,"
            } else if let last = ctx.last, ch.isLetter {
                // Space after sentence/clause punctuation when a letter follows directly: "hi,there" -> "hi, there".
                // "." only when the next letter is uppercase and the char before "." is a letter/digit, so "google.com" and "e.g" are left alone.
                if ",!?".contains(last) { proxy.insertText(" ") }
                else if last == ".", ch.isUppercase, let prev = ctx.dropLast().last, prev.isLetter || prev.isNumber { proxy.insertText(" ") }
            }
        }
        proxy.insertText(s)
        if s.count == 1, s.first!.isLetter { shift = shift.afterLetter() }
    }

    private func typeSpace(previousWasSpace: Bool) {
        let ctx = proxy.documentContextBeforeInput ?? ""
        let within = now().timeIntervalSince(lastSpace) < 0.5
        if settings.doubleSpacePeriod, previousWasSpace, within, !traits.isSecure,
           ctx.hasSuffix(" "), let before = ctx.dropLast().last, Self.isWordChar(before) || ")\"”]".contains(before) {
            proxy.deleteBackward(); proxy.insertText(". ")
            lastWasSpace = false
            // Explicitly update shift so auto-cap fires after the period we just inserted.
            updateShiftFromContext(afterAction: .space)
            return
        }
        proxy.insertText(" ")
        lastSpace = now(); lastWasSpace = true
    }

    private func updateShiftFromContext(afterAction action: KeyAction) {
        if shift == .capsLock { return }
        if case .shift = action { return }
        guard settings.autoCapitalize else { return }
        let want = AutoCapitalization.shouldCapitalize(contextBefore: proxy.documentContextBeforeInput, mode: traits.autocapitalization)
        switch action {
        case .space, .returnKey, .backspace, .character: shift = want ? .once : .off
        default: break
        }
    }

    private func notify() { onChange?() }

    public var layoutRows: [[KeyDef]] {
        KeyboardLayouts.rows(page: page, language: settings.language, shifted: shift.isUppercase,
                             showNumberRow: settings.showNumberRow, needsGlobe: needsGlobe, returnLabel: traits.returnKeyLabel,
                             flickHints: settings.flickSymbols)
    }
}
