import SwiftUI

/// Primary metric surface — flat panel matching web `surface-card`.
struct AppHeroPanelStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppColors.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.panelBorder, lineWidth: 1)
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
                    .stroke(AppColors.panelBorder, lineWidth: 1)
            }
    }
}

// MARK: - App canvas (web `.app-canvas` grid + top glow)

struct AppCanvasBackground: View {
    private let gridSpacing: CGFloat = 24

    var body: some View {
        ZStack {
            AppColors.background

            Canvas { context, size in
                var path = Path()
                stride(from: CGFloat.zero, through: size.width, by: gridSpacing).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: CGFloat.zero, through: size.height, by: gridSpacing).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(AppColors.gridLine), lineWidth: 1)
            }

            RadialGradient(
                colors: [
                    AppColors.accent.opacity(0.12),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.5, y: -0.15),
                startRadius: 0,
                endRadius: 420
            )
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

    /// Web `.app-canvas` — dark teal base, subtle grid, top accent glow.
    func appCanvasBackground() -> some View {
        background {
            AppCanvasBackground()
                .ignoresSafeArea()
        }
    }

    /// Pinned horizontal tab strip — secondary surface + separator (Research symbol screen).
    func appTabBarStrip() -> some View {
        padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, 8)
            .background(AppColors.secondaryBackground.opacity(0.95))
            .overlay(alignment: .bottom) {
                Divider().overlay(AppColors.separator)
            }
    }

    /// Main tab bar — secondary surface, visible separator, accent selection.
    func appMainTabBarChrome() -> some View {
        toolbarBackground(Token.surfaceSecondary.opacity(0.95), for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
    }
}
