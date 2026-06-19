import SwiftUI

/// Flux's visual language: a deep-black dark surface, near-white text, and mint
/// green accents, set in the system font (San Francisco) at deliberately light
/// weights for a modern, airy feel.
///
/// Everything visual routes through here so the look can be tuned in one place
/// (e.g. flipping to a light base later is a handful of edits).
enum Theme {
    // MARK: Palette

    /// Very deep black — the window background.
    static let background = Color(hex: 0x0A0A0B)
    /// Slightly lifted surface for cards.
    static let surface = Color(hex: 0x141416)
    /// Hairline separators / card borders.
    static let border = Color.white.opacity(0.08)

    static let text = Color(hex: 0xF4F4F5)
    static let textDim = Color.white.opacity(0.5)

    /// Mint green — the single accent.
    static let accent = Color(hex: 0xADEBB3)

    // MARK: Type — system font (San Francisco), kept light

    static func font(_ size: CGFloat, _ weight: Font.Weight = .light) -> Font {
        .system(size: size, weight: weight)
    }

    /// Big, airy headline (e.g. the window title).
    static var display: Font { font(30, .thin) }
    /// Large metric numbers — super light for that modern look.
    static var metric: Font { font(26, .ultraLight) }
    /// Card / section labels.
    static var label: Font { font(12, .medium) }
    static var body: Font { font(14, .light) }
    static var mono: Font { font(13, .regular).monospacedDigit() }
}

extension Color {
    /// Build a color from a 0xRRGGBB literal.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
