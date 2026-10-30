import Foundation

/// Platform-neutral color (sRGB 0...1). UI layers convert to UIColor.
public struct RGBA: Codable, Equatable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    public init(hex: UInt32) {
        self.init(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
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
        .init(id: "blue", name: "Blue", color: RGBA(hex: 0x1A73E8)),
        .init(id: "teal", name: "Teal", color: RGBA(hex: 0x00897B)),
        .init(id: "green", name: "Green", color: RGBA(hex: 0x2E7D32)),
        .init(id: "orange", name: "Orange", color: RGBA(hex: 0xE65100)),
        .init(id: "pink", name: "Pink", color: RGBA(hex: 0xC2185B)),
        .init(id: "purple", name: "Purple", color: RGBA(hex: 0x6A1B9A)),
    ]
    public static func named(_ id: String) -> AccentColor { all.first { $0.id == id } ?? all[0] }
}

public struct ThemePalette: Equatable {
    public let background, key, modifierKey, keyText, candidateText, popover: RGBA
    public static let light = ThemePalette(background: RGBA(hex: 0xD1D5DB), key: RGBA(hex: 0xFFFFFF), modifierKey: RGBA(hex: 0xAEB4BE),
                                           keyText: RGBA(hex: 0x111111), candidateText: RGBA(hex: 0x222222), popover: RGBA(hex: 0xFFFFFF))
    public static let dark = ThemePalette(background: RGBA(hex: 0x1E1F22), key: RGBA(hex: 0x3B3D42), modifierKey: RGBA(hex: 0x2A2C30),
                                          keyText: RGBA(hex: 0xF2F2F2), candidateText: RGBA(hex: 0xE0E0E0), popover: RGBA(hex: 0x4A4C52))
    public static func palette(mode: ThemeMode, systemIsDark: Bool) -> ThemePalette {
        switch mode { case .light: return .light; case .dark: return .dark; case .system: return systemIsDark ? .dark : .light }
    }
}
