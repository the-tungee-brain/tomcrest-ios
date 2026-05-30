import SwiftUI

/// Design tokens aligned with my-pocket `globals.css`.
enum Theme {
    static let background = Color(hex: 0x0C0D0F)
    static let foreground = Color(hex: 0xE4E6EB)
    static let secondary = Color(hex: 0x16181D)
    static let border = Color(hex: 0x2A2D35)
    static let accent = Color(hex: 0x2DD4BF)
    static let accentStrong = Color(hex: 0x5EEAD4)
    static let muted = Color(hex: 0x8B919E)
    static let mutedBackground = Color(hex: 0x1A1C22)
    static let success = Color(hex: 0x34D399)
    static let danger = Color(hex: 0xF87171)
    static let warning = Color(hex: 0xFBBF24)

    static let panelBackground = Color(hex: 0x16181D).opacity(0.92)
    static let panelBackgroundSubtle = Color(hex: 0x16181D).opacity(0.75)
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

struct AppPanelStyle: ViewModifier {
    var subtle = false

    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(subtle ? Theme.panelBackgroundSubtle : Theme.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.border.opacity(0.6), lineWidth: 1)
            }
    }
}

extension View {
    func appPanel(subtle: Bool = false) -> some View {
        modifier(AppPanelStyle(subtle: subtle))
    }
}
