import SwiftUI

struct BrandShellView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let theme = BrandTheme(colorScheme: colorScheme)

        ZStack {
            theme.background
                .ignoresSafeArea()

            RadialGradient(
                colors: [theme.backgroundGlow, .clear],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 0,
                endRadius: 320
            )
            .ignoresSafeArea()

            BrandMarketLine(theme: theme)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, -24)
                .opacity(0.9)

            VStack(spacing: 18) {
                Spacer()

                BrandLogoMark(theme: theme)

                VStack(spacing: 10) {
                    Text(BrandTheme.appName)
                        .font(AppTypography.brandTitle)
                        .foregroundStyle(theme.textPrimary)
                        .tracking(-0.8)

                    BrandTaglineRotator(phrases: BrandTheme.taglines, theme: theme)
                }

                if let tip = BrandTips.tipOfTheDay() {
                    Text(tip)
                        .font(AppTypography.caption)
                        .foregroundStyle(theme.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .frame(maxWidth: 300)
                        .padding(.top, 8)
                }

                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }
}

private struct BrandLogoMark: View {
    let theme: BrandTheme

    var body: some View {
        TimelineView(.animation) { timeline in
            let scale = BrandMotion.breatheScale(at: timeline.date)
            let offset = BrandMotion.parallaxOffset(at: timeline.date)

            Image("BrandLogo")
                .resizable()
                .scaledToFit()
                .frame(width: BrandTheme.logoSize, height: BrandTheme.logoSize)
                .clipShape(
                    RoundedRectangle(cornerRadius: BrandTheme.logoCornerRadius, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: BrandTheme.logoCornerRadius, style: .continuous)
                        .stroke(theme.accent.opacity(0.12), lineWidth: 1)
                }
                .shadow(color: theme.logoShadow, radius: 18, y: 8)
                .scaleEffect(scale)
                .offset(offset)
        }
    }
}

#Preview {
    BrandShellView()
        .preferredColorScheme(.dark)
}
