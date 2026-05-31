import SwiftUI

/// Semantic design tokens — single source of truth for Tomcrest brand colors.
/// Web reference: `globals.css` (`--accent`, `--foreground`, panel surfaces).
enum Token {
    // MARK: Brand
    static let primary = Color(hex: 0x2dd4bf)
    static let primaryHighlight = Color(hex: 0x5eead4)
    static let primaryMuted = Color(hex: 0x14b8a6, opacity: 0.12)
    static let onPrimary = Color(hex: 0x0c0d0f)

    // MARK: Surfaces
    static let background = Color(hex: 0x0c0d0f)
    static let surfaceSecondary = Color(hex: 0x14161a)
    static let surfaceTertiary = Color(hex: 0x1a1d24)
    static let surfaceElevated = Color(hex: 0x181b22)
    static let surfaceFill = Color(hex: 0x1a1d24)
    static let surfaceFillSecondary = Color(hex: 0x181b22)

    // MARK: Text
    static let textPrimary = Color(hex: 0xe4e6eb)
    static let textSecondary = Color(hex: 0x7a7f8a)
    static let textTertiary = Color(hex: 0x6b7080)

    // MARK: Chrome
    static let border = Color(hex: 0xffffff, opacity: 0.12)
    static let panelBorder = Color(hex: 0x2dd4bf, opacity: 0.08)
    static let gridLine = Color(hex: 0xffffff, opacity: 0.06)

    // MARK: Semantic
    static let success = Color(hex: 0x34d399)
    static let warning = Color(hex: 0xfbbf24)
    static let error = Color(hex: 0xfb7185)
    static let danger = Color(hex: 0xe11d48)
}

/// Brand-facing alias for primary accent — use in marketing/auth surfaces.
enum BrandPrimary {
    static var color: Color { Token.primary }
    static var highlight: Color { Token.primaryHighlight }
    static var onColor: Color { Token.onPrimary }
}

/// Legacy name — prefer `Token` in new UI code.
enum AppColors {
    static var background: Color { Token.background }
    static var secondaryBackground: Color { Token.surfaceSecondary }
    static var tertiaryBackground: Color { Token.surfaceTertiary }
    static var groupedBackground: Color { Token.background }
    static var surfaceElevated: Color { Token.surfaceElevated }

    static var label: Color { Token.textPrimary }
    static var secondaryLabel: Color { Token.textSecondary }
    static var tertiaryLabel: Color { Token.textTertiary }

    static var separator: Color { Token.border }
    static var panelBorder: Color { Token.panelBorder }
    static var gridLine: Color { Token.gridLine }
    static var fill: Color { Token.surfaceFill }
    static var secondaryFill: Color { Token.surfaceFillSecondary }
    /// Chips / inset rows — translucent so app canvas shows through.
    static var insetSurface: Color { Token.surfaceFillSecondary.opacity(0.72) }

    static var accent: Color { Token.primary }
    static var accentHighlight: Color { Token.primaryHighlight }
    static var accentMuted: Color { Token.primaryMuted }
    static var onAccent: Color { Token.onPrimary }

    static var success: Color { Token.success }
    static var warning: Color { Token.warning }
    static var error: Color { Token.error }
    static var danger: Color { Token.danger }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
