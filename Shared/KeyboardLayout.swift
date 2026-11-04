import Foundation

public enum KeyAction: Equatable {
    case character(String)
    case shift
    case backspace
    case space
    case returnKey
    case switchToLetters
    case switchToNumbers
    case switchToSymbols
    case nextKeyboard   // globe
    case emoji
    case hideKeyboard
}

public struct KeyDef: Equatable {
    public let action: KeyAction
    public let label: String
    public let alternates: [String]
    /// Symbol entered by pulling the key downward (flick); shown as a small hint on the key.
    public let hint: String?
    /// Small indicator drawn at the key's leading edge (e.g. the "1 2 3 4" numeric-layout mark on the space/language key).
    public let badge: String?
    /// Fully rounded (capsule/circle) key shape.
    public let pill: Bool
    public let widthWeight: Double
    public init(_ action: KeyAction, label: String, alternates: [String] = [], hint: String? = nil, badge: String? = nil, pill: Bool = false, widthWeight: Double = 1) {
        self.action = action; self.label = label; self.alternates = alternates; self.hint = hint; self.badge = badge; self.pill = pill; self.widthWeight = widthWeight
    }
    public var isModifier: Bool {
        switch action { case .character, .space: return false; default: return true }
    }
}

public enum LayoutPage: String, Codable { case letters, numbers, symbols }

public enum LanguageLayout: String, Codable, CaseIterable, Identifiable {
    case englishQWERTY, spanishQWERTY, germanQWERTZ, frenchAZERTY
    public var id: String { rawValue }
    public var displayName: String {
        switch self {
        case .englishQWERTY: return "English (QWERTY)"
        case .spanishQWERTY: return "Español (QWERTY)"
        case .germanQWERTZ: return "Deutsch (QWERTZ)"
        case .frenchAZERTY: return "Français (AZERTY)"
        }
    }
    var letterRows: [[String]] {
        switch self {
        case .englishQWERTY, .spanishQWERTY:
            return [Array("qwertyuiop").map(String.init), Array("asdfghjkl").map(String.init), Array("zxcvbnm").map(String.init)]
        case .germanQWERTZ:
            return [Array("qwertzuiop").map(String.init), Array("asdfghjkl").map(String.init), Array("yxcvbnm").map(String.init)]
        case .frenchAZERTY:
            return [Array("azertyuiop").map(String.init), Array("qsdfghjklm").map(String.init), Array("wxcvbn").map(String.init)]
        }
    }
    var extraLetters: [String: [String]] {
        var base: [String: [String]] = [
            "a": ["à", "á", "â", "ä", "æ", "ã", "å", "ā"], "e": ["è", "é", "ê", "ë", "ē"],
            "i": ["î", "ï", "í", "ī", "ì"], "o": ["ô", "ö", "ò", "ó", "œ", "õ"],
            "u": ["û", "ü", "ù", "ú", "ū"], "c": ["ç", "ć", "č"], "n": ["ñ", "ń"],
            "s": ["ß", "ś", "š"], "y": ["ÿ", "ý"], "z": ["ž", "ź", "ż"],
        ]
        if self == .spanishQWERTY { base["n"] = ["ñ"]; base["a"] = ["á"]; base["e"] = ["é"]; base["i"] = ["í"]; base["o"] = ["ó"]; base["u"] = ["ú", "ü"] }
        if self == .germanQWERTZ { base["a"] = ["ä"]; base["o"] = ["ö"]; base["u"] = ["ü"]; base["s"] = ["ß"] }
        return base
    }
    /// Name shown on the space bar.
    public var spaceLabel: String {
        switch self { case .englishQWERTY: return "English"; case .spanishQWERTY: return "Español"; case .germanQWERTZ: return "Deutsch"; case .frenchAZERTY: return "Français" }
    }
    /// Locale used for spell checking / capitalization.
    public var localeIdentifier: String {
        switch self { case .englishQWERTY: return "en_US"; case .spanishQWERTY: return "es_ES"; case .germanQWERTZ: return "de_DE"; case .frenchAZERTY: return "fr_FR" }
    }
}

public enum KeyboardLayouts {
    static let numberAlternates: [String: [String]] = [
        "0": ["°", "∅"], "1": ["¹", "½"], "2": ["²"], "3": ["³"],
        "-": ["–", "—", "•"], "$": ["€", "£", "¥", "¢", "₹"], "₹": ["$", "€", "£", "¥", "¢"], "&": ["§"], "\"": ["“", "”", "„"],
        ".": ["…"], "?": ["¿"], "!": ["¡"], "'": ["‘", "’"],
    ]

    /// Flick-down symbols for letters (same as the symbols on the iOS-style numbers page).
    static let letterHints: [String: String] = ["a": "@", "s": "#", "d": "₹", "f": "%", "g": "&", "h": "-", "j": "+", "k": "(", "l": ")",
                                                "z": "*", "x": "\"", "c": "'", "v": ":", "b": ";", "n": "!", "m": "?"]

    /// Builds rows for a page. `shifted` uppercases letter keys. `showNumberRow` adds a 1–0 row above letters.
    public static func rows(page: LayoutPage, language: LanguageLayout, shifted: Bool,
                            showNumberRow: Bool, needsGlobe: Bool, returnLabel: String = "return",
                            flickHints: Bool = true) -> [[KeyDef]] {
        var rows: [[KeyDef]] = []
        switch page {
        case .letters:
            if showNumberRow {
                rows.append(Array("1234567890").map { KeyDef(.character(String($0)), label: String($0), alternates: numberAlternates[String($0)] ?? []) })
            }
            let letters = language.letterRows
            let extras = language.extraLetters
            func letterKey(_ s: String, topIndex: Int? = nil) -> KeyDef {
                let alts = (extras[s] ?? []).map { shifted ? $0.uppercased() : $0 }
                let t = shifted ? s.uppercased() : s
                var hint: String? = nil
                if flickHints { if let i = topIndex { hint = showNumberRow ? nil : String((i + 1) % 10) } else { hint = letterHints[s] } }
                return KeyDef(.character(t), label: t, alternates: alts, hint: hint)
            }
            rows.append(letters[0].enumerated().map { letterKey($0.element, topIndex: $0.offset) })
            rows.append(letters[1].map { letterKey($0) })
            rows.append([KeyDef(.shift, label: "⇧", widthWeight: 1.5)] + letters[2].map { letterKey($0) } + [KeyDef(.backspace, label: "⌫", widthWeight: 1.5)])
        case .numbers:
            rows.append(Array("1234567890").map { KeyDef(.character(String($0)), label: String($0), alternates: numberAlternates[String($0)] ?? []) })
            rows.append(["@", "#", "₹", "_", "&", "-", "+", "(", ")", "/"].map { KeyDef(.character($0), label: $0, alternates: numberAlternates[$0] ?? []) })
            rows.append([KeyDef(.switchToSymbols, label: "=\\<", widthWeight: 1.5)] + ["*", "\"", "'", ":", ";", "!", "?"].map { KeyDef(.character($0), label: $0, alternates: numberAlternates[$0] ?? []) } + [KeyDef(.backspace, label: "⌫", widthWeight: 1.5)])
        case .symbols:
            rows.append(["~", "`", "|", "•", "√", "π", "÷", "×", "¶", "∆"].map { KeyDef(.character($0), label: $0) })
            rows.append(["£", "¢", "€", "¥", "^", "°", "=", "{", "}", "\\"].map { KeyDef(.character($0), label: $0) })
            rows.append([KeyDef(.switchToNumbers, label: "123", widthWeight: 1.5)] + ["%", "©", "®", "™", "[", "]", "<"].map { KeyDef(.character($0), label: $0, alternates: numberAlternates[$0] ?? []) } + [KeyDef(.backspace, label: "⌫", widthWeight: 1.5)])
        }
        var bottom: [KeyDef] = []
        let spaceName = language.spaceLabel
        let ret = KeyDef(.returnKey, label: returnLabel, pill: true, widthWeight: 1.8)
        if page == .letters {
            bottom.append(KeyDef(.switchToNumbers, label: "123", widthWeight: 1.3))
            if needsGlobe { bottom.append(KeyDef(.nextKeyboard, label: "🌐", widthWeight: 1.0)) }
            bottom.append(KeyDef(.emoji, label: "☺︎", widthWeight: 0.85))
            let spaceWeight: Double = needsGlobe ? 4.6 : 5.6
            bottom.append(KeyDef(.space, label: spaceName, widthWeight: spaceWeight))
            // "." key: tap types a period; long-press shows "…  ,  ?  !  ⌄" —
            // the ⌄ sentinel is intercepted by InputController.insertAlternate to hide the keyboard.
            bottom.append(KeyDef(.character("."), label: ".", alternates: ["…", ",", "?", "!", "⌄"], widthWeight: 0.95))
        } else {
            // Number / symbol panel: ABC (round) · , · space-with-language-label (+ "1 2 3 4" badge) · . · enter
            bottom.append(KeyDef(.switchToLetters, label: "ABC", pill: true, widthWeight: 1.4))
            if needsGlobe { bottom.append(KeyDef(.nextKeyboard, label: "🌐", widthWeight: 0.9)) }
            bottom.append(KeyDef(.character(","), label: ",", widthWeight: 0.8))
            bottom.append(KeyDef(.space, label: spaceName, badge: "1 2\n3 4", widthWeight: needsGlobe ? 3.4 : 4.4))
            bottom.append(KeyDef(.character("."), label: ".", alternates: numberAlternates["."] ?? [], widthWeight: 0.8))
        }
        bottom.append(ret)
        rows.append(bottom)
        return rows
    }
}
