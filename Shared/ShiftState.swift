import Foundation

public enum ShiftState: Equatable {
    case off, once, capsLock

    public var isUppercase: Bool { self != .off }

    /// Behaviour of a tap on the shift key. A double tap within the window turns on caps lock.
    public func afterTap(doubleTap: Bool) -> ShiftState {
        switch self {
        case .off: return doubleTap ? .capsLock : .once
        case .once: return doubleTap ? .capsLock : .off
        case .capsLock: return .off
        }
    }

    /// State after a letter was typed: one-shot shift is consumed, caps lock persists.
    public func afterLetter() -> ShiftState { self == .once ? .off : self }
}

public enum AutoCapitalization {
    /// Decides whether the next character should start capitalized.
    /// `mode` mirrors UITextAutocapitalizationType: none, words, sentences, allCharacters.
    public enum Mode { case none, words, sentences, allCharacters }

    public static func shouldCapitalize(contextBefore: String?, mode: Mode) -> Bool {
        switch mode {
        case .none: return false
        case .allCharacters: return true
        case .words:
            guard let c = contextBefore, let last = c.last else { return true }
            return last.isWhitespace
        case .sentences:
            guard let c = contextBefore, !c.isEmpty else { return true }
            let trimmed = c.reversed().drop(while: { $0 == " " || $0 == "\u{00A0}" })
            // Needs at least one space (or newline) after the terminator.
            guard let last = trimmed.first else { return true }
            if last == "\n" { return true }
            let hadSpace = c.last == " " || c.last == "\u{00A0}"
            return hadSpace && ".!?".contains(last)
        }
    }
}
