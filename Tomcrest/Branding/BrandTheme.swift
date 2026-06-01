import SwiftUI

struct BrandTheme {
    let colorScheme: ColorScheme

    var background: Color {
        colorScheme == .dark ? Token.background : Color(hex: 0xf3f5f7)
    }

    var backgroundGlow: Color {
        colorScheme == .dark ? Token.primary.opacity(0.14) : Token.primary.opacity(0.10)
    }

    var textPrimary: Color {
        colorScheme == .dark ? Token.textPrimary : Color(hex: 0x12141a)
    }

    var textSecondary: Color {
        colorScheme == .dark ? Token.textSecondary : Color(hex: 0x5c6370)
    }

    var textTertiary: Color {
        colorScheme == .dark ? Token.textTertiary : Color(hex: 0x8a919c)
    }

    var accent: Color { Token.primary }
    var accentHighlight: Color { Token.primaryHighlight }
    var linePrimary: Color { accent.opacity(colorScheme == .dark ? 0.42 : 0.34) }
    var lineSecondary: Color { accent.opacity(colorScheme == .dark ? 0.16 : 0.12) }
    var logoShadow: Color { accent.opacity(colorScheme == .dark ? 0.28 : 0.18) }

    static let taglines = [
        "Morning clarity for your portfolio.",
        "Research with structure, not noise.",
        "Options income, mapped to your risk.",
        "Your playbook, one tap away.",
    ]

    static let appName = "Tomcrest"
}
