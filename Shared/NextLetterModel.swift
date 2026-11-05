import Foundation

/// Language side of dynamic tap zones: P(next letter | the word typed so far).
/// Blends a prefix match against ~12k English words plus common Hinglish ("nah" -> i) with letter-pair and word-start frequencies.
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

    /// Parsed once, sorted alphabetically (the data is already sorted) so prefixes are found by binary search.
    private static let entries: [(word: [Character], weight: Double)] = CommonWords.data
        .split(whereSeparator: \.isWhitespace)
        .compactMap { tok in
            guard let colon = tok.lastIndex(of: ":"), let w = Double(tok[tok.index(after: colon)...]) else { return nil }
            return (Array(tok[..<colon]), w)
        }

    /// Index of the first entry whose word is >= `prefix` (alphabetical, ASCII).
    private static func lowerBound(_ prefix: [Character]) -> Int {
        var lo = 0, hi = entries.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if entries[mid].word.lexicographicallyPrecedes(prefix) { lo = mid + 1 } else { hi = mid }
        }
        return lo
    }

    /// Probabilities (sum ~ 1) over lowercase letters for the next keystroke, given the letters of the current word so far.
    /// `prefix` is the current word's letters (case-insensitive); empty means a new word is starting.
    public static func distribution(prefix: String) -> [Character: Double] {
        let p = Array(prefix.lowercased())
        guard let last = p.last else { return wordStart }
        let bigram = p.count >= 1 ? (BigramModel.distribution(after: last) ?? [:]) : [:]

        var byWords: [Character: Double] = [:]
        var total = 0.0
        var i = lowerBound(p)
        while i < entries.count, entries[i].word.starts(with: p) {
            let e = entries[i]; i += 1
            guard e.word.count > p.count else { continue }
            byWords[e.word[p.count], default: 0] += e.weight; total += e.weight
        }
        guard total > 0 else { return bigram.isEmpty ? wordStart : bigram }
        var out: [Character: Double] = [:]
        for (c, v) in byWords { out[c, default: 0] += wordWeight * v / total }
        let rest = bigram.isEmpty ? 0 : 1 - wordWeight
        for (c, v) in bigram { out[c, default: 0] += rest * v }
        return out
    }
}
