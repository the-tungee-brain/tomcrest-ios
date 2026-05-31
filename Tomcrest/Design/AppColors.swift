import SwiftUI

/// Dark-first semantic tokens — resolves correctly in light mode too when appearance changes.
enum AppColors {
    // MARK: Surfaces
    static let background = Color(uiColor: .systemBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)
    static let groupedBackground = Color(uiColor: .systemGroupedBackground)

    // MARK: Text
    static let label = Color(uiColor: .label)
    static let secondaryLabel = Color(uiColor: .secondaryLabel)
    static let tertiaryLabel = Color(uiColor: .tertiaryLabel)

    // MARK: Chrome
    static let separator = Color(uiColor: .separator)
    static let fill = Color(uiColor: .systemFill)
    static let secondaryFill = Color(uiColor: .secondarySystemFill)

    // MARK: Accents — systemBlue adapts for dark-first + acceptable light contrast
    static let accent = Color(uiColor: .systemBlue)
    /// Slightly lifted blue for tags/avatars on dark backgrounds; still readable in light mode.
    static let accentHighlight = Color(uiColor: .systemBlue).opacity(0.92)

    // MARK: Semantic states — system colors adapt in light and dark
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
    static let error = Color(uiColor: .systemRed)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
