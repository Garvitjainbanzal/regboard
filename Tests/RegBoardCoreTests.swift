import XCTest
#if canImport(RegBoardCore)
@testable import RegBoardCore
#else
@testable import RegBoard
#endif

final class MockProxy: TextProxy {
    var text = ""
    var cursorMoves: [Int] = []
    var documentContextBeforeInput: String? { text.isEmpty ? nil : text }
    var documentContextAfterInput: String? { nil }
    func insertText(_ t: String) { text += t }
    func deleteBackward() { if !text.isEmpty { text.removeLast() } }
    func adjustTextPosition(byCharacterOffset o: Int) { cursorMoves.append(o) }
}

private func freshDefaults(_ name: String = UUID().uuidString) -> UserDefaults {
    let d = UserDefaults(suiteName: name)!; d.removePersistentDomain(forName: name); return d
}

final class InputControllerTests: XCTestCase {
    var proxy: MockProxy!, ctl: InputController!, clock: Date!

    override func setUp() {
        proxy = MockProxy(); clock = Date(timeIntervalSince1970: 1000)
        ctl = InputController(proxy: proxy, now: { [unowned self] in self.clock })
        ctl.traits.autocapitalization = .none
        ctl.beginEditing()
    }
    func type(_ s: String) { for c in s { ctl.handle(c == " " ? .space : .character(String(c))) } }
    func set(_ f: (inout KeyboardSettings) -> Void) { var s = ctl.settings; f(&s); ctl.apply(settings: s) }
    func tick(_ t: TimeInterval) { clock = clock.addingTimeInterval(t) }

    // Shift
    func testStartsCapitalizedWhenAutocapOn() {
        ctl.traits.autocapitalization = .sentences; ctl.beginEditing()
        XCTAssertEqual(ctl.shift, .once); type("h"); XCTAssertEqual(ctl.shift, .off)
        XCTAssertEqual(ctl.layoutRows[1][0].label, "q")
    }
    func testShiftTapAndCapsLock() {
        ctl.handle(.shift); XCTAssertEqual(ctl.shift, .once)
        tick(1); ctl.handle(.shift); XCTAssertEqual(ctl.shift, .off)
        tick(1); ctl.handle(.shift); tick(0.1); ctl.handle(.shift); XCTAssertEqual(ctl.shift, .capsLock)
        type("ab"); XCTAssertEqual(ctl.shift, .capsLock)
        tick(2); ctl.handle(.shift); XCTAssertEqual(ctl.shift, .off)
    }
    func testOneShotShiftConsumed() { ctl.handle(.shift); XCTAssertEqual(ctl.shift, .once); type("a"); XCTAssertEqual(ctl.shift, .off) }
    func testSentenceAutocapAfterPeriodSpace() {
        ctl.traits.autocapitalization = .sentences; ctl.beginEditing()
        type("ok. "); XCTAssertEqual(ctl.shift, .once); type("x"); XCTAssertEqual(ctl.shift, .off)
    }
    func testAutocapDisabledInSettings() {
        ctl.traits.autocapitalization = .sentences; set { $0.autoCapitalize = false }; ctl.beginEditing(); XCTAssertEqual(ctl.shift, .off)
    }

    // Basic editing
    func testBackspaceReturnAndPages() {
        type("ab"); ctl.handle(.backspace); XCTAssertEqual(proxy.text, "a")
        ctl.handle(.returnKey); XCTAssertEqual(proxy.text, "a\n")
        ctl.handle(.switchToNumbers); XCTAssertEqual(ctl.page, .numbers)
        ctl.handle(.switchToSymbols); XCTAssertEqual(ctl.page, .symbols)
        ctl.handle(.switchToLetters); XCTAssertEqual(ctl.page, .letters)
    }
    func testNoAutocorrectOrPrediction() { type("teh "); XCTAssertEqual(proxy.text, "teh ") }
    func testCursorMoveAndRepeatDelete() {
        ctl.moveCursor(by: -3); XCTAssertEqual(proxy.cursorMoves, [-3]); ctl.moveCursor(by: 0); XCTAssertEqual(proxy.cursorMoves.count, 1)
        type("abc"); ctl.repeatDelete(); ctl.repeatDelete(); XCTAssertEqual(proxy.text, "a")
    }
    func testDeleteWord() {
        type("hello big world"); ctl.deleteWord(); XCTAssertEqual(proxy.text, "hello big "); ctl.deleteWord(); XCTAssertEqual(proxy.text, "hello ")
        proxy.text = "hi!"; ctl.deleteWord(); XCTAssertEqual(proxy.text, "hi")
    }
    func testHideKeyboardCallback() { var hidden = false; ctl.onHide = { hidden = true }; ctl.handle(.hideKeyboard); XCTAssertTrue(hidden); XCTAssertTrue(proxy.text.isEmpty) }
    func testHideViaInsertAlternateSentinel() {
        var hidden = false; ctl.onHide = { hidden = true }
        ctl.insertAlternate("⌄")
        XCTAssertTrue(hidden)
        XCTAssertTrue(proxy.text.isEmpty, "Sentinel should not be typed as a character")
    }

    // 1. Double-space full stop (toggle)
    func testDoubleSpacePeriodOn() {
        type("hello"); ctl.handle(.space); tick(0.2); ctl.handle(.space); XCTAssertEqual(proxy.text, "hello. ")
    }
    func testDoubleSpacePeriodSlowSecondTapIsPlainSpace() {
        type("hello"); ctl.handle(.space); tick(1); ctl.handle(.space); XCTAssertEqual(proxy.text, "hello  ")
    }
    func testDoubleSpacePeriodOff() {
        set { $0.doubleSpacePeriod = false }
        type("hello"); ctl.handle(.space); tick(0.2); ctl.handle(.space); XCTAssertEqual(proxy.text, "hello  ")
    }
    func testDoubleSpaceNotAfterPunctuationOrEmpty() {
        type("hi."); ctl.handle(.space); tick(0.1); ctl.handle(.space); XCTAssertEqual(proxy.text, "hi.  ")
        proxy.text = ""; ctl.handle(.space); tick(0.1); ctl.handle(.space); XCTAssertEqual(proxy.text, "  ")
    }
    func testDoubleSpaceDisabledInSecureField() {
        ctl.traits.isSecure = true; type("hello"); ctl.handle(.space); tick(0.1); ctl.handle(.space); XCTAssertEqual(proxy.text, "hello  ")
    }

    // 2. Auto punctuation (toggle)
    func testAutoPunctuationRemovesSpaceBeforeMarks() {
        type("hello ,"); XCTAssertEqual(proxy.text, "hello,")
        type(" world !"); XCTAssertEqual(proxy.text, "hello, world!")
    }
    func testAutoPunctuationAddsSpaceAfterCommaAndQuestion() {
        type("hi,there"); XCTAssertEqual(proxy.text, "hi, there")
        proxy.text = ""; type("why?no"); XCTAssertEqual(proxy.text, "why? no")
    }
    func testAutoPunctuationPeriodRules() {
        type("end.Next"); XCTAssertEqual(proxy.text, "end. Next")       // capital follows
        proxy.text = ""; type("google.com"); XCTAssertEqual(proxy.text, "google.com")  // lowercase: untouched
        proxy.text = ""; type("3.5"); XCTAssertEqual(proxy.text, "3.5")
        proxy.text = ""; type("1,000"); XCTAssertEqual(proxy.text, "1,000")
        proxy.text = ""; type(":)"); XCTAssertEqual(proxy.text, ":)")
    }
    func testAutoPunctuationOff() {
        set { $0.autoPunctuation = false }
        type("hello ,"); XCTAssertEqual(proxy.text, "hello ,")
        proxy.text = ""; type("hi,there"); XCTAssertEqual(proxy.text, "hi,there")
    }
    func testAutoPunctuationOffInSecureField() {
        ctl.traits.isSecure = true; type("a ,b"); XCTAssertEqual(proxy.text, "a ,b")
    }
    func testBothTogglesIndependent() {
        set { $0.doubleSpacePeriod = false; $0.autoPunctuation = true }
        type("hello"); ctl.handle(.space); tick(0.1); ctl.handle(.space); XCTAssertEqual(proxy.text, "hello  ")
        proxy.text = ""; set { $0.doubleSpacePeriod = true; $0.autoPunctuation = false }
        type("hi ,"); XCTAssertEqual(proxy.text, "hi ,")
    }
}

final class LayoutTests: XCTestCase {
    func rows(_ page: LayoutPage = .letters, _ lang: LanguageLayout = .englishQWERTY, shifted: Bool = false, numRow: Bool = true, globe: Bool = true, hints: Bool = true) -> [[KeyDef]] {
        KeyboardLayouts.rows(page: page, language: lang, shifted: shifted, showNumberRow: numRow, needsGlobe: globe, flickHints: hints)
    }
    func testQWERTYRows() {
        let r = rows()
        XCTAssertEqual(r.count, 5); XCTAssertEqual(r[1].count, 10); XCTAssertEqual(r[2].count, 9); XCTAssertEqual(r[3].count, 9)
        XCTAssertEqual(r.last!.first!.action, .switchToNumbers)
        // Hide keyboard is now accessed via long-press on "." (sentinel "⌄" alternate), not a dedicated key.
        XCTAssertFalse(r.last!.contains { $0.action == .hideKeyboard })
        XCTAssertTrue(r.last!.first { if case .character(".") = $0.action { return true }; return false }?.alternates.contains("⌄") == true)
        XCTAssertEqual(r.last!.first { $0.action == .space }?.label, "English")
    }
    func testNumberRowToggleAndGlobe() {
        let r = rows(numRow: false, globe: false)
        XCTAssertEqual(r.count, 4); XCTAssertFalse(r.last!.contains { $0.action == .nextKeyboard })
    }
    func testShiftedLabelsAndAlternates() {
        let e = rows(shifted: true, numRow: false)[0][2]; XCTAssertEqual(e.label, "E"); XCTAssertTrue(e.alternates.contains("É"))
    }
    func testFlickHints() {
        let r = rows(numRow: true)
        XCTAssertEqual(r[2][0].hint, "@")                          // a
        XCTAssertNil(r[1][0].hint)                                 // q has no hint while number row is visible
        XCTAssertEqual(rows(numRow: false)[0][0].hint, "1")        // q -> 1
        XCTAssertEqual(rows(numRow: false)[0][9].hint, "0")        // p -> 0
        XCTAssertNil(rows(hints: false)[2][0].hint)
    }
    func testLanguageVariants() {
        XCTAssertEqual(rows(.letters, .germanQWERTZ, numRow: false)[0][5].label, "z")
        let fr = rows(.letters, .frenchAZERTY, numRow: false); XCTAssertEqual(fr[0][0].label, "a"); XCTAssertEqual(fr[1].count, 10)
        XCTAssertEqual(rows(.letters, .spanishQWERTY, numRow: false)[2].first { $0.label == "n" }?.alternates, ["ñ"])
    }
    func labels(_ row: [KeyDef]) -> [String] { row.map(\.label) }
    func testNumberPanelMatchesSpec() {
        let n = rows(.numbers, globe: false)
        XCTAssertEqual(n.count, 4)
        XCTAssertEqual(labels(n[0]), ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"])
        XCTAssertEqual(labels(n[1]), ["@", "#", "₹", "_", "&", "-", "+", "(", ")", "/"])
        XCTAssertEqual(labels(n[2]), ["=\\<", "*", "\"", "'", ":", ";", "!", "?", "⌫"])
        XCTAssertEqual(n[2].first?.action, .switchToSymbols); XCTAssertEqual(n[2].last?.action, .backspace)
        XCTAssertEqual(n[3].map(\.action), [.switchToLetters, .character(","), .space, .character("."), .returnKey])
        XCTAssertEqual(n[3][0].label, "ABC"); XCTAssertFalse(n[3][0].pill)
        XCTAssertEqual(n[3][2].label, "English"); XCTAssertNotNil(n[3][2].badge)
        XCTAssertTrue(n[3][4].pill)
        XCTAssertGreaterThan(n[3][2].widthWeight, n[3][1].widthWeight * 3)
    }
    func testNumberPanelWithGlobeAndLanguageLabel() {
        let n = rows(.numbers, .germanQWERTZ, globe: true)
        XCTAssertEqual(n[3].map(\.action), [.switchToLetters, .nextKeyboard, .character(","), .space, .character("."), .returnKey])
        XCTAssertEqual(n[3][3].label, "Deutsch")
    }
    func testSymbolPageAndRupeeAlternates() {
        let s = rows(.symbols)
        XCTAssertEqual(s[0].count, 10); XCTAssertEqual(s[1].count, 10); XCTAssertTrue(s[2].contains { $0.action == .switchToNumbers })
        XCTAssertEqual(s.last!.first?.action, .switchToLetters)
        XCTAssertTrue(rows(.numbers)[1][2].alternates.contains("$"))
    }
}

final class SettingsTests: XCTestCase {
    func testDefaults() {
        let s = KeyboardSettings()
        XCTAssertTrue(s.doubleSpacePeriod); XCTAssertTrue(s.autoPunctuation); XCTAssertEqual(s.oneHanded, .off); XCTAssertTrue(s.showNumberRow)
    }
    func testRoundTripAndClamp() {
        let d = freshDefaults(); let s = SettingsStore(defaults: d)
        XCTAssertEqual(s.load(), KeyboardSettings())
        var v = KeyboardSettings(); v.language = .germanQWERTZ; v.heightScale = 5
        v.doubleSpacePeriod = false; v.autoPunctuation = false; v.oneHanded = .right; v.showNumberRow = false
        s.save(v)
        let r = SettingsStore(defaults: d).load()
        XCTAssertEqual(r.language, .germanQWERTZ); XCTAssertEqual(r.heightScale, 1.4)
        XCTAssertFalse(r.doubleSpacePeriod); XCTAssertFalse(r.autoPunctuation); XCTAssertEqual(r.oneHanded, .right); XCTAssertFalse(r.showNumberRow)
        v.heightScale = 0.1; s.save(v); XCTAssertEqual(s.load().heightScale, 0.7)
    }
    func testCorruptDataFallsBack() {
        let d = freshDefaults(); d.set(Data([1, 2, 3]), forKey: "keyboardSettings.v1")
        XCTAssertEqual(SettingsStore(defaults: d).load(), KeyboardSettings())
    }
    func testAutoCapRules() {
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(contextBefore: nil, mode: .sentences))
        XCTAssertFalse(AutoCapitalization.shouldCapitalize(contextBefore: "Hi.", mode: .sentences))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(contextBefore: "Hi. ", mode: .sentences))
        XCTAssertFalse(AutoCapitalization.shouldCapitalize(contextBefore: "Hi, ", mode: .sentences))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(contextBefore: "a ", mode: .words))
        XCTAssertTrue(AutoCapitalization.shouldCapitalize(contextBefore: "a", mode: .allCharacters))
    }
    func testRecentEmoji() {
        let r = RecentEmojiStore(defaults: freshDefaults(), limit: 2)
        r.record("😀"); r.record("😂"); r.record("😀"); r.record("🔥")
        XCTAssertEqual(r.recents, ["🔥", "😀"]); r.clear(); XCTAssertTrue(r.recents.isEmpty)
    }
}

final class TapZoneTests: XCTestCase {
    // Two adjacent 30pt-wide letter keys with a 6pt gap: "h" at x 0..30, "n" at x 36..66; plus a space-like modifier below.
    // "Safe core" (middle 60%) of "h" is x 6..24, of "n" x 42..60.
    private func keys() -> [TapZoneKey] {
        [TapZoneKey(x: 0, y: 0, width: 30, height: 40, letter: "h"),
         TapZoneKey(x: 36, y: 0, width: 30, height: 40, letter: "n"),
         TapZoneKey(x: 0, y: 52, width: 66, height: 40, letter: nil, isTarget: false)]
    }
    private let hLikely: [Character: Double] = ["h": 0.4, "n": 0.03]
    private let nLikely: [Character: Double] = ["h": 0.03, "n": 0.4]

    func testDirectHitCentre() {
        XCTAssertEqual(TapZoneEngine.resolve(x: 15, y: 20, keys: keys(), probabilities: hLikely), 0)
        XCTAssertEqual(TapZoneEngine.resolve(x: 51, y: 20, keys: keys(), probabilities: hLikely), 1)
    }
    func testGapIsNeverDead() {
        XCTAssertNotNil(TapZoneEngine.resolve(x: 33, y: 20, keys: keys(), probabilities: nil))
    }
    func testLikelyKeyWinsTheGap() {
        XCTAssertEqual(TapZoneEngine.resolve(x: 33, y: 20, keys: keys(), probabilities: hLikely), 0)
        XCTAssertEqual(TapZoneEngine.resolve(x: 33, y: 20, keys: keys(), probabilities: nLikely), 1)
    }
    func testLikelyKeyGrowsIntoNeighbour() {
        // x=39 is on the visible edge of "n". If "h" is far likelier the zone has grown over it; if "n" is, it hasn't.
        XCTAssertEqual(TapZoneEngine.resolve(x: 39, y: 20, keys: keys(), probabilities: hLikely), 0)
        XCTAssertEqual(TapZoneEngine.resolve(x: 39, y: 20, keys: keys(), probabilities: nLikely), 1)
    }
    func testCoreOfKeyNeverStolen() {
        XCTAssertEqual(TapZoneEngine.resolve(x: 45, y: 20, keys: keys(), probabilities: hLikely), 1)
        XCTAssertEqual(TapZoneEngine.resolve(x: 15, y: 20, keys: keys(), probabilities: nLikely), 0)
    }
    func testLikelyKeyGrowsVertically() {
        // "d" on the home row with "e" directly above: a touch near the top of "d" goes to "e" when "e" is likely.
        let rows = [TapZoneKey(x: 0, y: 0, width: 30, height: 40, letter: "e"),
                    TapZoneKey(x: 0, y: 48, width: 30, height: 40, letter: "d")]
        XCTAssertEqual(TapZoneEngine.resolve(x: 15, y: 52, keys: rows, probabilities: ["e": 0.4, "d": 0.03]), 0)
        XCTAssertEqual(TapZoneEngine.resolve(x: 15, y: 52, keys: rows, probabilities: ["e": 0.03, "d": 0.4]), 1)
    }
    func testModifierIsOnlyHitDirectly() {
        XCTAssertEqual(TapZoneEngine.resolve(x: 33, y: 70, keys: keys(), probabilities: hLikely), 2)
    }
    func testGapNextToModifierGoesToModifier() {
        // 6pt above the space-like key and 3pt from both letters: the modifier is the closest key.
        XCTAssertEqual(TapZoneEngine.resolve(x: 33, y: 46, keys: keys(), probabilities: hLikely), 2)
    }
    func testMissedLetterIsNotSwallowedByModifier() {
        // Margin just left of "h" with a Shift-like key farther away: the letter must win, even if its probability is tiny.
        let ks = [TapZoneKey(x: 0, y: 0, width: 30, height: 40, letter: "h"),
                  TapZoneKey(x: -40, y: 44, width: 30, height: 40, letter: nil, isTarget: false)]
        XCTAssertEqual(TapZoneEngine.resolve(x: -3, y: 30, keys: ks, probabilities: ["h": 0.001]), 0)
        XCTAssertEqual(TapZoneEngine.resolve(x: -3, y: 30, keys: ks, probabilities: nil), 0)
    }
    func testFarAwayHitsNothing() {
        XCTAssertNil(TapZoneEngine.resolve(x: 300, y: 300, keys: keys(), probabilities: hLikely))
    }
    func testDisabledIsExactOnly() {
        XCTAssertNil(TapZoneEngine.resolve(x: 33, y: 20, keys: keys(), probabilities: hLikely, enabled: false))
        XCTAssertEqual(TapZoneEngine.resolve(x: 29, y: 20, keys: keys(), probabilities: nLikely, enabled: false), 0)
    }
    func testNextLetterModel() {
        let start = NextLetterModel.distribution(prefix: "")
        XCTAssertEqual(start.values.reduce(0, +), 1, accuracy: 0.05)
        let hel = NextLetterModel.distribution(prefix: "hel")      // help, hello, held
        XCTAssertGreaterThan(hel["p"] ?? 0, hel["z"] ?? 0); XCTAssertGreaterThan(hel["l"] ?? 0, hel["z"] ?? 0)
        let th = NextLetterModel.distribution(prefix: "Th")        // case-insensitive
        XCTAssertGreaterThan(th["e"] ?? 0, th["z"] ?? 0)
        XCTAssertGreaterThan(NextLetterModel.distribution(prefix: "q")["u"] ?? 0, 0.9)
        let bata = NextLetterModel.distribution(prefix: "bata")    // Hinglish: batao / bataya / batana
        XCTAssertGreaterThan(bata["o"] ?? 0, bata["p"] ?? 0)
        let nah = NextLetterModel.distribution(prefix: "nah")      // Hinglish: nahi / nahin
        XCTAssertGreaterThan(nah["i"] ?? 0, nah["z"] ?? 0); XCTAssertGreaterThan(nah["i"] ?? 0, 0.3)
        XCTAssertFalse(NextLetterModel.distribution(prefix: "zzq").isEmpty)   // unknown prefix falls back to letter pairs
    }
    func testOldSettingsStillDecode() throws {
        let json = #"{"accentID":"blue","showNumberRow":false}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(KeyboardSettings.self, from: json)
        XCTAssertFalse(s.showNumberRow); XCTAssertTrue(s.dynamicTapZones)
    }

    // MARK: Swipe-delete
    /// Applies a plan to a string the way the keyboard does: backspaces, then typed text.
    private func apply(_ plan: (deletes: Int, insert: String), to text: inout String) {
        text.removeLast(plan.deletes); text += plan.insert
    }
    func testSwipeDeleteRemovesWholeWordsAndRestores() {
        let original = "hello big world"
        var text = String(original.dropLast())            // touch-down already deleted "d"
        var sd = SwipeDelete(context: original, alreadyRemoved: 1)
        apply(sd.plan(words: 1), to: &text); XCTAssertEqual(text, "hello big ")
        apply(sd.plan(words: 2), to: &text); XCTAssertEqual(text, "hello ")
        apply(sd.plan(words: 3), to: &text); XCTAssertEqual(text, "")
        apply(sd.plan(words: 9), to: &text); XCTAssertEqual(text, "")          // past the start is a no-op
        apply(sd.plan(words: 1), to: &text); XCTAssertEqual(text, "hello big ")  // sliding back brings words back
        apply(sd.plan(words: 0), to: &text); XCTAssertEqual(text, original)       // cancel restores everything
    }
    func testSwipeDeleteTakesTrailingSpacesAndPunctuation() {
        var text = "Hi there!  "
        var sd = SwipeDelete(context: "Hi there!  ", alreadyRemoved: 0)
        apply(sd.plan(words: 1), to: &text); XCTAssertEqual(text, "Hi there")
        apply(sd.plan(words: 2), to: &text); XCTAssertEqual(text, "Hi ")
        var empty = SwipeDelete(context: "", alreadyRemoved: 0)
        XCTAssertEqual(empty.plan(words: 3).deletes, 0)
    }
}
