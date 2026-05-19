import SwiftUI

// Mirrors @multica/ui/styles/tokens.css.
// OKLCH values are converted once to sRGB; light/dark variants
// flip the lightness curve to match the webapp.
enum MulticaTheme {
    static let radius: CGFloat = 10            // var(--radius) = 0.625rem
    static let radiusSm: CGFloat = 6
    static let radiusLg: CGFloat = 14

    // Brand: oklch(0.55 0.16 255) light, oklch(0.65 0.16 255) dark
    static let brand = Color(
        light: Color(red: 0.20, green: 0.40, blue: 0.88),
        dark:  Color(red: 0.39, green: 0.54, blue: 0.95)
    )
    // Success: oklch(0.55 0.16 145) light, oklch(0.65 0.15 145) dark
    static let success = Color(
        light: Color(red: 0.05, green: 0.55, blue: 0.30),
        dark:  Color(red: 0.18, green: 0.70, blue: 0.46)
    )
    // Warning: oklch(0.75 0.16 85) light, oklch(0.70 0.16 85) dark
    static let warning = Color(
        light: Color(red: 0.85, green: 0.62, blue: 0.06),
        dark:  Color(red: 0.86, green: 0.62, blue: 0.16)
    )
    // Info: oklch(0.55 0.18 250)
    static let info = Color(
        light: Color(red: 0.18, green: 0.40, blue: 0.88),
        dark:  Color(red: 0.36, green: 0.55, blue: 0.96)
    )
    // Destructive: oklch(0.577 0.245 27.325)
    static let danger = Color(
        light: Color(red: 0.87, green: 0.18, blue: 0.16),
        dark:  Color(red: 0.91, green: 0.40, blue: 0.32)
    )

    // Surface tones
    static let surface = Color(
        light: Color(red: 0.985, green: 0.985, blue: 0.985),
        dark:  Color(red: 0.13, green: 0.13, blue: 0.15)
    )
    static let muted = Color(
        light: Color(red: 0.95, green: 0.95, blue: 0.96),
        dark:  Color(red: 0.18, green: 0.18, blue: 0.20)
    )
    static let mutedForeground = Color(
        light: Color(red: 0.46, green: 0.46, blue: 0.48),
        dark:  Color(red: 0.66, green: 0.66, blue: 0.69)
    )
    static let border = Color(
        light: Color(red: 0.90, green: 0.90, blue: 0.92),
        dark:  Color(red: 1.0, green: 1.0, blue: 1.0).opacity(0.12)
    )
}

extension Color {
    /// Dynamic color that picks `light` in light mode and `dark` in dark mode.
    init(light: Color, dark: Color) {
        self = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

extension Font {
    static let mulHeadline = Font.system(size: 17, weight: .semibold, design: .default)
    static let mulTitle = Font.system(size: 22, weight: .semibold, design: .default)
    static let mulBody = Font.system(size: 15, weight: .regular)
    static let mulCaption = Font.system(size: 12, weight: .medium)
    static let mulCaptionMono = Font.system(size: 11, design: .monospaced).weight(.medium)
    static let mulMetric = Font.system(size: 28, weight: .semibold, design: .rounded)
}
