import SwiftUI

struct WatchlistFolderBackground: View {
    let swatch: WatchlistSwatch
    var accentOverride: Color?
    var accentHex: UInt32?

    @Environment(\.colorScheme) private var colorScheme

    private var accent: Color { accentOverride ?? swatch.accentColor }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            if let image = WatchlistFolderCompositionCache.render(
                swatch: swatch,
                accent: accent,
                accentHex: accentHex,
                size: size,
                colorScheme: colorScheme
            ) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                WatchlistFolderCompositionRenderer(swatch: swatch, accent: accent)
            }
        }
    }
}

struct WatchlistFolderCardChrome: ViewModifier {
    let swatch: WatchlistSwatch
    var accent: Color
    var accentHex: UInt32?
    var isTargeted: Bool = false

    func body(content: Content) -> some View {
        content
            .background {
                WatchlistFolderBackground(swatch: swatch, accentOverride: accent, accentHex: accentHex)
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        accent.opacity(isTargeted ? 0.55 : swatch.borderOpacity + 0.08),
                        lineWidth: isTargeted ? 1.5 : 1
                    )
            }
            .shadow(color: Color.black.opacity(0.22), radius: isTargeted ? 16 : 10, y: isTargeted ? 8 : 5)
            .scaleEffect(isTargeted ? 1.015 : 1)
            .animation(.spring(response: 0.32, dampingFraction: 0.78), value: isTargeted)
    }
}

extension View {
    func watchlistFolderChrome(
        swatch: WatchlistSwatch,
        accent: Color,
        accentHex: UInt32? = nil,
        isTargeted: Bool = false
    ) -> some View {
        modifier(WatchlistFolderCardChrome(swatch: swatch, accent: accent, accentHex: accentHex, isTargeted: isTargeted))
    }
}

struct WatchlistFolderExpandableContent<Content: View>: View {
    let isCollapsed: Bool
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 10)
            .padding(.bottom, isCollapsed ? 0 : 12)
            .frame(maxHeight: isCollapsed ? 0 : nil, alignment: .top)
            .clipped()
            .allowsHitTesting(!isCollapsed)
    }
}
