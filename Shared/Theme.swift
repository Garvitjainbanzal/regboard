import Foundation

/// Platform-neutral color (sRGB 0...1). UI layers convert to UIColor.
public struct RGBA: Codable, Equatable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    public init(hex: UInt32) {
        self.init(Double((hex >> 16) & 0xFF) / 255, Double((hex >> 8) & 0xFF) / 255, Double(hex & 0xFF) / 255)
    }
}

public struct ThemePalette: Equatable {
    public let background, key, modifierKey, keyText, candidateText, popover, selection: RGBA
    /// The one and only theme.
    public static let dark = ThemePalette(background: RGBA(hex: 0x1E1F22), key: RGBA(hex: 0x3B3D42), modifierKey: RGBA(hex: 0x2A2C30),
                                          keyText: RGBA(hex: 0xF2F2F2), candidateText: RGBA(hex: 0xE0E0E0), popover: RGBA(hex: 0x4A4C52),
                                          selection: RGBA(hex: 0x6B6E76))
}
