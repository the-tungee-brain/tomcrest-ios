import SwiftUI

/// Primary metric surface — flat, no gradient or heavy shadow (dark-first finance UI).
struct AppHeroPanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.separator, lineWidth: 1)
            }
    }
}

struct AppPanelStyle: ViewModifier {
    var subtle = false

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(subtle ? AppColors.tertiaryBackground : AppColors.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.separator, lineWidth: 1)
            }
    }
}

extension View {
    func appHeroPanel() -> some View {
        modifier(AppHeroPanelStyle())
    }

    func appPanel(subtle: Bool = false) -> some View {
        modifier(AppPanelStyle(subtle: subtle))
    }

    /// Pinned horizontal tab strip — secondary surface + separator (Research symbol screen).
    func appTabBarStrip() -> some View {
        padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, 8)
            .background(AppColors.secondaryBackground)
            .overlay(alignment: .bottom) {
                Divider().overlay(AppColors.separator)
            }
    }

    /// Main tab bar — secondary surface, visible separator, accent selection.
    func appMainTabBarChrome() -> some View {
        toolbarBackground(AppColors.secondaryBackground, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .tint(AppColors.accent)
    }
}
