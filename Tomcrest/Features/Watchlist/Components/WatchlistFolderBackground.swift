import SwiftUI

struct WatchlistFolderBackground: View {
    let swatch: WatchlistSwatch
    var accentOverride: Color?

    private var accent: Color { accentOverride ?? swatch.accentColor }

    var body: some View {
        ZStack {
            swatch.gradient

            RadialGradient(
                colors: [accent.opacity(0.22), Color.clear],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 180
            )

            LinearGradient(
                colors: [Color.white.opacity(0.06), Color.clear],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

struct WatchlistFolderCardChrome: ViewModifier {
    let swatch: WatchlistSwatch
    var accent: Color
    var isTargeted: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                WatchlistFolderBackground(swatch: swatch, accentOverride: accent)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        accent.opacity(isTargeted ? 0.55 : swatch.borderOpacity + 0.08),
                        lineWidth: isTargeted ? 1.5 : 1
                    )
            }
            .shadow(color: Color.black.opacity(0.28), radius: isTargeted ? 18 : 12, y: isTargeted ? 10 : 6)
            .scaleEffect(isTargeted ? 1.015 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isTargeted)
    }
}

extension View {
    func watchlistFolderChrome(swatch: WatchlistSwatch, accent: Color, isTargeted: Bool = false) -> some View {
        modifier(WatchlistFolderCardChrome(swatch: swatch, accent: accent, isTargeted: isTargeted))
    }
}
