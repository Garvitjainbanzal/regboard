import Foundation

public enum Handedness: String, Codable, CaseIterable, Identifiable {
    case off, left, right
    public var id: String { rawValue }
    public var displayName: String { switch self { case .off: return "Off"; case .left: return "Left hand"; case .right: return "Right hand" } }
}

public struct KeyboardSettings: Codable, Equatable {
    public var themeMode: ThemeMode = .system
    public var accentID: String = "blue"
    public var language: LanguageLayout = .englishQWERTY
    public var showNumberRow = true
    public var heightScale: Double = 1.0          // 0.7 ... 1.4
    public var oneHanded: Handedness = .off
    public var hapticsEnabled = true              // only effective with Full Access
    public var soundEnabled = true
    public var autoCapitalize = true
    public var doubleSpacePeriod = true           // "  " -> ". "
    public var autoPunctuation = true             // smart spacing around , . ! ?
    public var flickSymbols = true                // pull a key downward for its hinted symbol
    public var longPressDelay: Double = 0.35
    public var dynamicTapZones = true             // invisible tap zones adapt to the next likely letter
    public init() {}

    // Custom decoding so settings saved by older versions (without newer keys) still load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = KeyboardSettings()
        themeMode = try c.decodeIfPresent(ThemeMode.self, forKey: .themeMode) ?? d.themeMode
        accentID = try c.decodeIfPresent(String.self, forKey: .accentID) ?? d.accentID
        language = try c.decodeIfPresent(LanguageLayout.self, forKey: .language) ?? d.language
        showNumberRow = try c.decodeIfPresent(Bool.self, forKey: .showNumberRow) ?? d.showNumberRow
        heightScale = try c.decodeIfPresent(Double.self, forKey: .heightScale) ?? d.heightScale
        oneHanded = try c.decodeIfPresent(Handedness.self, forKey: .oneHanded) ?? d.oneHanded
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? d.hapticsEnabled
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? d.soundEnabled
        autoCapitalize = try c.decodeIfPresent(Bool.self, forKey: .autoCapitalize) ?? d.autoCapitalize
        doubleSpacePeriod = try c.decodeIfPresent(Bool.self, forKey: .doubleSpacePeriod) ?? d.doubleSpacePeriod
        autoPunctuation = try c.decodeIfPresent(Bool.self, forKey: .autoPunctuation) ?? d.autoPunctuation
        flickSymbols = try c.decodeIfPresent(Bool.self, forKey: .flickSymbols) ?? d.flickSymbols
        longPressDelay = try c.decodeIfPresent(Double.self, forKey: .longPressDelay) ?? d.longPressDelay
        dynamicTapZones = try c.decodeIfPresent(Bool.self, forKey: .dynamicTapZones) ?? d.dynamicTapZones
    }
    public static let heightRange: ClosedRange<Double> = 0.7...1.4
    public mutating func clamp() { heightScale = min(max(heightScale, Self.heightRange.lowerBound), Self.heightRange.upperBound) }
}

/// Persists settings in a UserDefaults suite. With an App Group the suite is shared by app and extension;
/// without Full Access the extension can't see the app's values and falls back to defaults.
public final class SettingsStore {
    public static let appGroupID = "group.com.regboard.regboard"
    private static let key = "keyboardSettings.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults) { self.defaults = defaults }
    public convenience init() {
        self.init(defaults: UserDefaults(suiteName: SettingsStore.appGroupID) ?? .standard)
    }

    public func load() -> KeyboardSettings {
        guard let data = defaults.data(forKey: Self.key), var s = try? JSONDecoder().decode(KeyboardSettings.self, from: data) else { return KeyboardSettings() }
        s.clamp()
        return s
    }
    public func save(_ settings: KeyboardSettings) {
        var s = settings; s.clamp()
        if let data = try? JSONEncoder().encode(s) { defaults.set(data, forKey: Self.key) }
    }
}
