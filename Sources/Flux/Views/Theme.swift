import SwiftUI

/// Flux's visual language: quiet black surfaces, native macOS typography, and
/// a single mint accent. Semantic system text styles keep the hierarchy feeling
/// at home on macOS and continue to respond to accessibility text-size preferences.
///
/// Everything visual routes through here so the look can be tuned in one place
/// (e.g. flipping to a light base later is a handful of edits).
enum Theme {
    // MARK: Palette

    static let background = Color.black
    static let surface = Color(hex: 0x0C0C0D)
    static let surfaceRaised = Color(hex: 0x141416)
    static let border = Color.white.opacity(0.09)

    static let text = Color.primary
    static let textDim = Color.secondary

    /// Mint green — the single accent.
    static let accent = Color(hex: 0xADEBB3)

    // MARK: Type — semantic San Francisco styles

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static var display: Font { .system(.largeTitle, design: .default, weight: .semibold) }
    static var metric: Font { .system(.title2, design: .default, weight: .medium).monospacedDigit() }
    static var sectionTitle: Font { .system(.headline, design: .default, weight: .semibold) }
    static var label: Font { .system(.caption, design: .default, weight: .semibold) }
    static var body: Font { .system(.body, design: .default, weight: .regular) }
    static var secondary: Font { .system(.caption, design: .default, weight: .regular) }
    static var mono: Font { .system(.callout, design: .default, weight: .regular).monospacedDigit() }
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
