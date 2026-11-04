import Foundation

/// Language side of dynamic tap zones: P(next letter | the word typed so far).
/// Blends a common-word prefix match ("hel" -> p, l, d ...) with letter-pair and word-start frequencies.
/// Static data only: nothing is learned from, or stored about, what the user types.
public enum NextLetterModel {
    /// Weight of the word-list estimate when the typed prefix matches at least one listed word.
    static let wordWeight = 0.65

    /// Approximate first-letter frequencies of English words (used at the start of a word).
    private static let wordStart: [Character: Double] = [
        "t": 0.16, "a": 0.11, "o": 0.075, "i": 0.07, "s": 0.065, "w": 0.055, "c": 0.05, "b": 0.045, "p": 0.04, "h": 0.04,
        "f": 0.04, "m": 0.03, "d": 0.03, "r": 0.028, "e": 0.027, "l": 0.025, "n": 0.022, "g": 0.02, "u": 0.012, "y": 0.011,
        "v": 0.009, "j": 0.006, "k": 0.006, "q": 0.002, "z": 0.0005, "x": 0.0005,
    ]

    private static let words: [(chars: [Character], weight: Double)] = CommonWords.list.enumerated().map { i, w in
        (Array(w), 1.0 / Double(i + 10))     // Zipf-like: earlier = more frequent
    }

    /// Probabilities (sum ~ 1) over lowercase letters for the next keystroke, given the letters of the current word so far.
    /// `prefix` is the current word's letters (case-insensitive); empty means a new word is starting.
    public static func distribution(prefix: String) -> [Character: Double] {
        let p = Array(prefix.lowercased())
        guard let last = p.last else { return wordStart }
        let bigram = p.count >= 1 ? (BigramModel.distribution(after: last) ?? [:]) : [:]

        var byWords: [Character: Double] = [:]
        var total = 0.0
        for w in words where w.chars.count > p.count && w.chars.starts(with: p) {
            byWords[w.chars[p.count], default: 0] += w.weight; total += w.weight
        }
        guard total > 0 else { return bigram.isEmpty ? wordStart : bigram }
        var out: [Character: Double] = [:]
        for (c, v) in byWords { out[c, default: 0] += wordWeight * v / total }
        let rest = bigram.isEmpty ? 0 : 1 - wordWeight
        for (c, v) in bigram { out[c, default: 0] += rest * v }
        return out
    }
}
