import Foundation

/// Platform-neutral color (sRGB 0...1). UI layers convert to UIColor / SwiftUI Color.
public struct RGBA: Codable, Equatable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(
            Double((hex >> 16) & 0xFF) / 255,
            Double((hex >> 8)  & 0xFF) / 255,
            Double( hex        & 0xFF) / 255,
            alpha
        )
    }
}

public enum ThemeMode: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    public var id: String { rawValue }
}

public struct AccentColor: Codable, Equatable, Identifiable {
    public let id: String
    public let name: String
    public let color: RGBA
    public static let all: [AccentColor] = [
        .init(id: "blue",   name: "Blue",   color: RGBA(hex: 0x1A73E8)),
        .init(id: "teal",   name: "Teal",   color: RGBA(hex: 0x00897B)),
        .init(id: "green",  name: "Green",  color: RGBA(hex: 0x2E7D32)),
        .init(id: "orange", name: "Orange", color: RGBA(hex: 0xE65100)),
        .init(id: "pink",   name: "Pink",   color: RGBA(hex: 0xC2185B)),
        .init(id: "purple", name: "Purple", color: RGBA(hex: 0x6A1B9A)),
    ]
    public static func named(_ id: String) -> AccentColor {
        all.first { $0.id == id } ?? all[0]
    }
}

/// Colors matched to the iOS system keyboard measured from device screenshots.
///
/// Dark mode (from reference image):
///   background  #1C1C1E  — UIColor.systemBackground in dark trait
///   letter key  #2C2C2E  — slightly lighter than background
///   modifier    #3A3A3C  — shift / backspace / 123 / return
///   key text    #FFFFFF
///
/// Light mode (standard iOS light keyboard):
///   background  #CDD0D6
///   letter key  #FFFFFF
///   modifier    #ADB5BD
///   key text    #000000
public struct ThemePalette: Equatable {
    public let background: RGBA
    public let key: RGBA          // letter / character keys
    public let modifierKey: RGBA  // shift, backspace, 123, return, globe
    public let keyText: RGBA
    public let candidateText: RGBA
    public let popover: RGBA      // key-press preview popup

    // ── Dark palette — matches iOS 16/17 dark-mode system keyboard ──────────
    public static let dark = ThemePalette(
        background:    RGBA(hex: 0x1C1C1E),
        key:           RGBA(hex: 0x2C2C2E),
        modifierKey:   RGBA(hex: 0x3A3A3C),
        keyText:       RGBA(hex: 0xFFFFFF),
        candidateText: RGBA(hex: 0xEBEBF5),
        popover:       RGBA(hex: 0x48484A)
    )

    // ── Light palette — matches iOS 16/17 light-mode system keyboard ─────────
    public static let light = ThemePalette(
        background:    RGBA(hex: 0xCDD0D6),
        key:           RGBA(hex: 0xFFFFFF),
        modifierKey:   RGBA(hex: 0xADB5BD),
        keyText:       RGBA(hex: 0x000000),
        candidateText: RGBA(hex: 0x3C3C43),
        popover:       RGBA(hex: 0xFFFFFF)
    )

    public static func palette(mode: ThemeMode, systemIsDark: Bool) -> ThemePalette {
        switch mode {
        case .light:  return .light
        case .dark:   return .dark
        case .system: return systemIsDark ? .dark : .light
        }
    }
}
