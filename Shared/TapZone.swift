import Foundation

/// One key as seen by the tap-zone engine (plain numbers so it is testable without UIKit).
public struct TapZoneKey: Equatable {
    public var x: Double, y: Double, width: Double, height: Double
    /// Lowercase letter for letter keys, nil otherwise.
    public var letter: Character?
    /// Character keys (letters, digits, punctuation) may be re-targeted; modifiers and space are only hit directly.
    public var isTarget: Bool
    public init(x: Double, y: Double, width: Double, height: Double, letter: Character? = nil, isTarget: Bool = true) {
        self.x = x; self.y = y; self.width = width; self.height = height; self.letter = letter; self.isTarget = isTarget
    }
    func contains(_ px: Double, _ py: Double) -> Bool { px >= x && px < x + width && py >= y && py < y + height }
    /// Distance from the key centre in units of half-key-size (1.0 = on the key's edge along that axis).
    func normalizedDistance(_ px: Double, _ py: Double) -> Double {
        let dx = (px - (x + width / 2)) / max(width / 2, 1)
        let dy = (py - (y + height / 2)) / max(height / 2, 1)
        return (dx * dx + dy * dy).squareRoot()
    }
}

/// Dynamic tap zones: the invisible hit area of each key grows or shrinks with how likely that letter is to come next,
/// and gaps between keys are never dead. Visible keys do not change.
public enum TapZoneEngine {
    /// Touches farther than this (boosted, normalised) from every key hit nothing.
    public static let maxReach: Double = 1.6

    /// Index into `keys` of the key the touch at (x, y) should press, or nil if it hits nothing.
    /// - Modifier / space keys are only pressed by touches that land directly on them or in a gap next to them.
    /// - A touch on a character key may be redirected to a neighbouring character key that is much more likely next.
    public static func resolve(x: Double, y: Double, keys: [TapZoneKey], previous: Character?, enabled: Bool = true) -> Int? {
        let exact = keys.firstIndex { $0.contains(x, y) }
        if let e = exact, !keys[e].isTarget { return e }
        guard enabled else { return exact }

        var best: Int? = nil, bestScore = Double.greatestFiniteMagnitude
        for (i, k) in keys.enumerated() {
            // Touch is on a character key: only character keys compete. In a gap: everything competes.
            if exact != nil && !k.isTarget { continue }
            var boost = 1.0
            if let l = k.letter { boost = BigramModel.boost(after: previous, candidate: l) }
            let score = k.normalizedDistance(x, y) / boost
            if score < bestScore { bestScore = score; best = i }
        }
        if let b = best, bestScore <= maxReach { return b }
        return exact
    }
}
