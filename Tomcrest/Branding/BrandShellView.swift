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
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .tracking(0.3)

                    BrandTaglineRotator(phrases: BrandTheme.taglines, theme: theme)
                }

                if let tip = BrandTips.tipOfTheDay() {
                    Text(tip)
                        .font(.caption)
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
                .frame(width: 72, height: 72)
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
