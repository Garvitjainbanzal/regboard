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
    /// Offset from the key centre in units of the key's own width / height (0.5 = on the edge).
    func offset(_ px: Double, _ py: Double) -> (dx: Double, dy: Double) {
        ((px - (x + width / 2)) / max(width, 1), (py - (y + height / 2)) / max(height, 1))
    }
}

/// Dynamic tap zones. For a touch, every nearby key gets
///
///     score(k) = -d(k)^2 / (2 sigma^2)  +  lambda * ln P_language(k)
///
/// where d is the distance from the key centre in key-size units (the spatial term, a Gaussian log-likelihood) and
/// P_language is the chance the letter comes next given the word typed so far. The highest score wins, which is the same
/// as growing the invisible hit area of likely keys and shrinking their neighbours', while the visible keys never change.
/// The middle of a key always belongs to that key, and gaps between keys are never dead.
public enum TapZoneEngine {
    /// Spatial variance in key-size units^2. Smaller = trust the finger position more.
    public static let sigmaSquared = 0.2
    /// How strongly language context moves the zone borders (lambda).
    public static let languageWeight = 0.7
    /// Probabilities are clamped to this floor, which caps how far a very unlikely key's zone can shrink.
    public static let probabilityFloor = 0.03
    /// Probability given to non-letter keys (digits, punctuation) when competing in a gap.
    public static let neutralProbability = 0.05
    /// A touch within this fraction of key size (each side of the centre) always hits that key.
    public static let safeCore = 0.3
    /// Keys farther than this (in key-size units) from the touch do not compete; touching beyond it hits nothing.
    public static let maxReach = 1.5

    /// Index into `keys` of the key the touch at (x, y) should press, or nil if it hits nothing.
    /// - Parameter probabilities: P(next letter) for lowercase letters, or nil for no language context (pure proximity).
    /// - Modifier / space keys are only pressed by touches that land directly on them.
    /// - A touch on a character key may be handed to a neighbouring character key that is much more likely next.
    public static func resolve(x: Double, y: Double, keys: [TapZoneKey], probabilities: [Character: Double]?, enabled: Bool = true) -> Int? {
        let exact = keys.firstIndex { $0.contains(x, y) }
        if let e = exact, !keys[e].isTarget { return e }
        guard enabled else { return exact }
        if let e = exact {
            let o = keys[e].offset(x, y)
            if abs(o.dx) <= safeCore && abs(o.dy) <= safeCore { return e }
        }

        var best: Int? = nil, bestScore = -Double.greatestFiniteMagnitude
        for (i, k) in keys.enumerated() {
            // Touch is on a character key: only character keys compete. In a gap: everything competes.
            if exact != nil && !k.isTarget { continue }
            let o = k.offset(x, y)
            let d2 = o.dx * o.dx + o.dy * o.dy
            if d2.squareRoot() > maxReach { continue }
            var score = -d2 / (2 * sigmaSquared)
            if let probs = probabilities {
                let p = k.letter.map { probs[$0] ?? 0 } ?? neutralProbability
                score += languageWeight * log(max(p, probabilityFloor))
            }
            if score > bestScore { bestScore = score; best = i }
        }
        return best ?? exact
    }
}
