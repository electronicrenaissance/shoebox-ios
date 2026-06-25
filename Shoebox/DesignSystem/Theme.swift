import SwiftUI

/// Shoebox design tokens, ported from the original web/mobile design system so
/// the native app shares the same warm-paper, ink, and forest-green palette.
/// See `docs/architecture/app-architecture.md` §Design system.
enum Theme {
    // MARK: Colors

    /// Warm off-white background (`#FAF8F4`).
    static let paper = Color(hex: 0xFAF8F4)
    /// Near-black foreground (`#1B1A17`).
    static let ink = Color(hex: 0x1B1A17)
    /// Secondary text (`#6B675E`).
    static let muted = Color(hex: 0x6B675E)
    /// Hairline borders / dividers (`#E8E4DC`).
    static let line = Color(hex: 0xE8E4DC)

    /// Primary brand green (`#15573B`).
    static let brand = Color(hex: 0x15573B)
    /// Darker brand for pressed/hover (`#0F4530`).
    static let brandDark = Color(hex: 0x0F4530)
    /// Tinted brand background for chips/badges (`#E6F0EA`).
    static let brandLight = Color(hex: 0xE6F0EA)

    // MARK: Typography

    /// Serif display face for headings, matching the web brand.
    static func serif(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    // MARK: Metrics

    static let cornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 16
}

extension Color {
    /// Initialize from a 24-bit `0xRRGGBB` literal.
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
