import Foundation

/// Plans the "swipe left from backspace" gesture: sliding left deletes whole words live, sliding back right
/// types them again, so the gesture can be cancelled. iOS keyboards can't select text, so this stands in for
/// Gboard's highlight-then-delete. Works purely on a snapshot of the text before the cursor taken at touch-down,
/// so it never depends on the host app refreshing `documentContextBeforeInput` between steps.
public struct SwipeDelete {
    private let text: [Character]
    /// Characters currently removed from the end of `text`.
    public private(set) var removed: Int
    /// `ends[k]` = characters removed after `k` words (`ends[0] == 0`).
    private var ends: [Int] = [0]

    /// - Parameters:
    ///   - context: text before the cursor as it was *before* the touch-down delete.
    ///   - alreadyRemoved: characters the touch-down delete already removed (0 or 1).
    public init(context: String, alreadyRemoved: Int) {
        text = Array(context); removed = min(alreadyRemoved, text.count)
    }

    /// Moves to "`words` words removed" and returns what to do: `deletes` backspaces, then type `insert`.
    public mutating func plan(words: Int) -> (deletes: Int, insert: String) {
        let target = removedCount(afterWords: max(0, words))
        defer { removed = target }
        if target > removed { return (target - removed, "") }
        if target < removed { return (0, String(text[(text.count - removed)..<(text.count - target)])) }
        return (0, "")
    }

    /// Characters removed once `k` words are gone: each word takes its trailing spaces plus the word
    /// (letters/digits) or, for punctuation, a run of punctuation.
    private mutating func removedCount(afterWords k: Int) -> Int {
        while ends.count <= k {
            let last = ends[ends.count - 1]
            if last >= text.count { return text.count }
            var i = text.count - last
            while i > 0, text[i - 1].isWhitespace { i -= 1 }
            if i > 0 {
                let word = InputController.isWordChar(text[i - 1])
                while i > 0, !text[i - 1].isWhitespace, InputController.isWordChar(text[i - 1]) == word { i -= 1 }
            }
            ends.append(text.count - i)
        }
        return ends[k]
    }
}
