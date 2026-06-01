import SwiftUI

// MARK: - Public surface

struct WatchlistFolderCompositionRenderer: View {
    let swatch: WatchlistSwatch
    var accent: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                baseAtmosphere
                compositionLayer(size: proxy.size)
                WatchlistFolderAtmosphereGrain(isLight: colorScheme == .light)
                frostedVeil
            }
        }
    }

    private var baseAtmosphere: some View {
        ZStack {
            swatch.gradient

            RadialGradient(
                colors: [accent.opacity(intensity(0.20, light: 0.10)), .clear],
                center: .topTrailing,
                startRadius: 6,
                endRadius: 220
            )

            LinearGradient(
                colors: [Color.white.opacity(intensity(0.06, light: 0.14)), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.45)
            )

            LinearGradient(
                colors: [.clear, Color.black.opacity(intensity(0.10, light: 0.04))],
                startPoint: UnitPoint(x: 0.5, y: 0.55),
                endPoint: .bottom
            )
        }
    }

    private var frostedVeil: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(intensity(0.035, light: 0.08)),
                .clear,
                Color.black.opacity(intensity(0.04, light: 0.02)),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .blendMode(.overlay)
    }

    @ViewBuilder
    private func compositionLayer(size: CGSize) -> some View {
        let palette = WatchlistFolderCompositionPalette(swatch: swatch, accent: accent, size: size, isLight: colorScheme == .light)

        switch swatch.composition {
        case .classic:
            EmptyView()
        case .cornerOrb:
            WatchlistFolderCornerOrbLayer(palette: palette)
        case .twinOrbs:
            WatchlistFolderTwinOrbsLayer(palette: palette)
        case .concentricRings:
            WatchlistFolderConcentricRingsLayer(palette: palette)
        case .curvedFlow:
            WatchlistFolderCurvedFlowLayer(palette: palette)
        case .diagonalRibbon:
            WatchlistFolderDiagonalRibbonLayer(palette: palette)
        case .glassPanel:
            WatchlistFolderGlassPanelLayer(palette: palette)
        case .layeredRects:
            WatchlistFolderLayeredRectsLayer(palette: palette)
        case .orbitalArc:
            WatchlistFolderOrbitalArcLayer(palette: palette)
        case .metallicLines:
            WatchlistFolderMetallicLinesLayer(palette: palette)
        case .visionFloat:
            WatchlistFolderVisionFloatLayer(palette: palette)
        case .softGrid:
            WatchlistFolderSoftGridLayer(palette: palette)
        case .organicBlob:
            WatchlistFolderOrganicBlobLayer(palette: palette)
        case .radialBurst:
            WatchlistFolderRadialBurstLayer(palette: palette)
        case .lightStreak:
            WatchlistFolderLightStreakLayer(palette: palette)
        case .architecturalBlock:
            WatchlistFolderArchitecturalBlockLayer(palette: palette)
        case .meshGradient:
            WatchlistFolderMeshGradientLayer(palette: palette)
        case .particleField:
            WatchlistFolderParticleFieldLayer(palette: palette)
        case .waveBands:
            WatchlistFolderWaveBandsLayer(palette: palette)
        case .sphereCluster:
            WatchlistFolderSphereClusterLayer(palette: palette)
        case .thinArcs:
            WatchlistFolderThinArcsLayer(palette: palette)
        case .stackedGlass:
            WatchlistFolderStackedGlassLayer(palette: palette)
        case .diagonalBlocks:
            WatchlistFolderDiagonalBlocksLayer(palette: palette)
        case .haloRing:
            WatchlistFolderHaloRingLayer(palette: palette)
        case .liquidRibbon:
            WatchlistFolderLiquidRibbonLayer(palette: palette)
        }
    }

    private func intensity(_ dark: Double, light: Double) -> Double {
        colorScheme == .light ? light : dark
    }
}

struct WatchlistSwatchPreviewFill: View {
    let swatch: WatchlistSwatch
    var useLitePreview = true

    var body: some View {
        if useLitePreview {
            WatchlistSwatchLitePreview(swatch: swatch)
        } else {
            WatchlistFolderCompositionRenderer(swatch: swatch, accent: swatch.accentColor)
        }
    }
}

struct WatchlistSwatchLitePreview: View {
    let swatch: WatchlistSwatch

    var body: some View {
        ZStack {
            swatch.gradient

            RadialGradient(
                colors: [swatch.accentColor.opacity(0.28), .clear],
                center: .topTrailing,
                startRadius: 4,
                endRadius: 72
            )

            LinearGradient(
                colors: [Color.white.opacity(0.08), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
    }
}

// MARK: - Shared palette & helpers

struct WatchlistFolderCompositionPalette {
    let swatch: WatchlistSwatch
    let accent: Color
    let size: CGSize
    let isLight: Bool

    var base: Color { Color(hex: swatch.gradientBottom) }
    var glow: Color { accent.opacity(isLight ? 0.22 : 0.32) }
    var softGlow: Color { accent.opacity(isLight ? 0.12 : 0.18) }
    var line: Color { accent.opacity(isLight ? 0.20 : 0.28) }
    var whisper: Color { Color.white.opacity(isLight ? 0.18 : 0.08) }

    func intensity(_ dark: Double, light: Double) -> Double {
        isLight ? light : dark
    }
}

enum WatchlistFolderCompositionDrawing {
    static func softCircle(color: Color, diameter: CGFloat, blur: CGFloat = 28) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color, color.opacity(0.35), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: diameter * 0.52
                )
            )
            .frame(width: diameter, height: diameter)
            .blur(radius: blur)
    }

    static func glassCard(in rect: CGRect, corner: CGFloat, tint: Color, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .fill(tint.opacity(opacity))
            .background {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.35))
            }
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

private struct WatchlistFolderAtmosphereGrain: View {
    let isLight: Bool

    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 3
            let cols = min(Int(size.width / step) + 1, 90)
            let rows = min(Int(size.height / step) + 1, 60)

            for row in 0..<rows {
                for col in 0..<cols {
                    let hash = (row &* 928_371) ^ (col &* 689_287)
                    guard hash % 6 == 0 else { continue }
                    let alpha = (isLight ? 0.012 : 0.018) + Double(hash % 4) * 0.004
                    let rect = CGRect(x: CGFloat(col) * step, y: CGFloat(row) * step, width: 1, height: 1)
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(Color.white.opacity(alpha))
                    )
                }
            }
        }
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

// MARK: - Composition layers

private struct WatchlistFolderCornerOrbLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        WatchlistFolderCompositionDrawing.softCircle(
            color: palette.glow,
            diameter: palette.size.width * 0.72,
            blur: 34
        )
        .offset(x: palette.size.width * 0.22, y: -palette.size.height * 0.18)
    }
}

private struct WatchlistFolderTwinOrbsLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        ZStack {
            WatchlistFolderCompositionDrawing.softCircle(color: palette.softGlow, diameter: palette.size.width * 0.46, blur: 24)
                .offset(x: -palette.size.width * 0.18, y: -palette.size.height * 0.12)
            WatchlistFolderCompositionDrawing.softCircle(color: palette.glow, diameter: palette.size.width * 0.38, blur: 22)
                .offset(x: palette.size.width * 0.20, y: palette.size.height * 0.08)
        }
    }
}

private struct WatchlistFolderConcentricRingsLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.62, y: size.height * 0.42)
            let radii: [CGFloat] = [36, 58, 82, 108]
            for (index, radius) in radii.enumerated() {
                let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                let alpha = palette.intensity(0.16, light: 0.10) - Double(index) * 0.025
                context.stroke(ring, with: .color(palette.accent.opacity(alpha)), lineWidth: 0.8)
            }
        }
        .blur(radius: 0.4)
    }
}

private struct WatchlistFolderCurvedFlowLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        Canvas { context, size in
            var path = Path()
            path.move(to: CGPoint(x: -20, y: size.height * 0.72))
            path.addCurve(
                to: CGPoint(x: size.width + 20, y: size.height * 0.18),
                control1: CGPoint(x: size.width * 0.25, y: size.height * 0.95),
                control2: CGPoint(x: size.width * 0.55, y: size.height * 0.05)
            )
            context.stroke(path, with: .color(palette.line.opacity(0.55)), style: StrokeStyle(lineWidth: 1, lineCap: .round))

            var path2 = Path()
            path2.move(to: CGPoint(x: -10, y: size.height * 0.88))
            path2.addCurve(
                to: CGPoint(x: size.width + 10, y: size.height * 0.32),
                control1: CGPoint(x: size.width * 0.35, y: size.height * 1.05),
                control2: CGPoint(x: size.width * 0.65, y: size.height * 0.18)
            )
            context.stroke(path2, with: .color(palette.whisper), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
        }
        .blur(radius: 0.6)
    }
}

private struct WatchlistFolderDiagonalRibbonLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        Canvas { context, size in
            let bandWidth = size.width * 0.42
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: -bandWidth * 0.2, y: size.height * 1.05))
            ribbon.addQuadCurve(
                to: CGPoint(x: size.width * 1.1, y: -size.height * 0.08),
                control: CGPoint(x: size.width * 0.45, y: size.height * 0.42)
            )
            ribbon.addLine(to: CGPoint(x: size.width * 1.1 + bandWidth * 0.18, y: size.height * 0.08))
            ribbon.addQuadCurve(
                to: CGPoint(x: -bandWidth * 0.05, y: size.height * 1.15),
                control: CGPoint(x: size.width * 0.52, y: size.height * 0.58)
            )
            ribbon.closeSubpath()
            context.fill(ribbon, with: .color(palette.softGlow.opacity(0.55)))
            context.stroke(ribbon, with: .color(palette.line.opacity(0.25)), lineWidth: 0.8)
        }
        .blur(radius: 1.2)
    }
}

private struct WatchlistFolderGlassPanelLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        ZStack {
            WatchlistFolderCompositionDrawing.glassCard(
                in: CGRect(x: palette.size.width * 0.38, y: palette.size.height * 0.18, width: palette.size.width * 0.52, height: palette.size.height * 0.48),
                corner: 22,
                tint: palette.whisper,
                opacity: palette.intensity(0.14, light: 0.22)
            )
            .blur(radius: 0.5)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(palette.whisper.opacity(0.35), lineWidth: 0.8)
                .frame(width: palette.size.width * 0.52, height: palette.size.height * 0.48)
                .offset(x: palette.size.width * 0.14, y: -palette.size.height * 0.08)
        }
    }
}

private struct WatchlistFolderLayeredRectsLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.softGlow.opacity(0.35))
                .frame(width: palette.size.width * 0.46, height: palette.size.height * 0.34)
                .offset(x: -palette.size.width * 0.12, y: palette.size.height * 0.10)
                .blur(radius: 8)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(palette.glow.opacity(0.28))
                .frame(width: palette.size.width * 0.40, height: palette.size.height * 0.30)
                .offset(x: palette.size.width * 0.16, y: -palette.size.height * 0.06)
                .blur(radius: 6)
        }
    }
}

private struct WatchlistFolderOrbitalArcLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width * 0.18, y: size.height * 0.82)
            let radius: CGFloat = size.width * 0.78
            var arc = Path()
            arc.addArc(center: center, radius: radius, startAngle: .degrees(-58), endAngle: .degrees(18), clockwise: false)
            context.stroke(arc, with: .color(palette.line.opacity(0.65)), style: StrokeStyle(lineWidth: 1, lineCap: .round))

            var inner = Path()
            inner.addArc(center: center, radius: radius * 0.82, startAngle: .degrees(-48), endAngle: .degrees(8), clockwise: false)
            context.stroke(inner, with: .color(palette.whisper), style: StrokeStyle(lineWidth: 0.5, lineCap: .round))
        }
        .blur(radius: 0.5)
    }
}

private struct WatchlistFolderMetallicLinesLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        Canvas { context, size in
            for index in 0..<4 {
                let y = size.height * (0.28 + CGFloat(index) * 0.14)
                var line = Path()
                line.move(to: CGPoint(x: size.width * 0.08, y: y))
                line.addLine(to: CGPoint(x: size.width * 0.92, y: y - 10))
                let alpha = palette.intensity(0.22, light: 0.14) - Double(index) * 0.03
                context.stroke(line, with: .color(palette.accent.opacity(alpha)), style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
            }
        }
    }
}

private struct WatchlistFolderVisionFloatLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(palette.glow.opacity(0.16))
                .frame(width: palette.size.width * 0.56, height: palette.size.height * 0.22)
                .rotationEffect(.degrees(-8))
                .offset(x: palette.size.width * 0.08, y: -palette.size.height * 0.14)
                .blur(radius: 14)

            Ellipse()
                .fill(palette.softGlow.opacity(0.45))
                .frame(width: palette.size.width * 0.34, height: palette.size.height * 0.18)
                .offset(x: -palette.size.width * 0.14, y: palette.size.height * 0.16)
                .blur(radius: 18)
        }
    }
}

private struct WatchlistFolderSoftGridLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 18
            var lines = Path()
            var x: CGFloat = 0
            while x <= size.width {
                lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x, y: size.height))
                x += spacing
            }
            var y: CGFloat = 0
            while y <= size.height {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
                y += spacing
            }
            context.stroke(lines, with: .color(palette.whisper.opacity(0.45)), lineWidth: 0.35)
        }
        .blur(radius: 0.8)
    }
}

private struct WatchlistFolderOrganicBlobLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        ZStack {
            blob(offset: CGSize(width: palette.size.width * 0.18, height: -palette.size.height * 0.08), scale: 1.0)
            blob(offset: CGSize(width: -palette.size.width * 0.20, height: palette.size.height * 0.14), scale: 0.72)
        }
    }

    private func blob(offset: CGSize, scale: CGFloat) -> some View {
        Ellipse()
            .fill(
                RadialGradient(
                    colors: [palette.glow.opacity(0.55), palette.softGlow.opacity(0.2), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: palette.size.width * 0.28 * scale
                )
            )
            .frame(width: palette.size.width * 0.56 * scale, height: palette.size.height * 0.42 * scale)
            .offset(offset)
            .blur(radius: 20)
    }
}

private struct WatchlistFolderRadialBurstLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        RadialGradient(
            colors: [palette.glow.opacity(0.42), palette.softGlow.opacity(0.16), .clear],
            center: UnitPoint(x: 0.28, y: 0.32),
            startRadius: 0,
            endRadius: palette.size.width * 0.72
        )
        .blur(radius: 6)
    }
}

private struct WatchlistFolderLightStreakLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        LinearGradient(
            colors: [.clear, palette.glow.opacity(0.35), palette.whisper, .clear],
            startPoint: UnitPoint(x: 0.1, y: 0.85),
            endPoint: UnitPoint(x: 0.95, y: 0.05)
        )
        .blur(radius: 10)
        .opacity(0.85)
    }
}

private struct WatchlistFolderArchitecturalBlockLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(palette.softGlow.opacity(0.40))
                .frame(width: palette.size.width * 0.28, height: palette.size.height * 0.42)
                .offset(x: palette.size.width * 0.08, y: -palette.size.height * 0.08)

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(palette.line.opacity(0.35), lineWidth: 0.8)
                .frame(width: palette.size.width * 0.22, height: palette.size.height * 0.28)
                .offset(x: palette.size.width * 0.34, y: -palette.size.height * 0.16)
        }
        .blur(radius: 0.6)
    }
}

private struct WatchlistFolderMeshGradientLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        ZStack {
            WatchlistFolderCompositionDrawing.softCircle(color: palette.glow, diameter: palette.size.width * 0.44, blur: 26)
                .offset(x: -palette.size.width * 0.16, y: -palette.size.height * 0.10)
            WatchlistFolderCompositionDrawing.softCircle(color: palette.base.opacity(0.8), diameter: palette.size.width * 0.36, blur: 22)
                .offset(x: palette.size.width * 0.20, y: palette.size.height * 0.12)
            WatchlistFolderCompositionDrawing.softCircle(color: palette.softGlow, diameter: palette.size.width * 0.30, blur: 20)
                .offset(x: palette.size.width * 0.02, y: palette.size.height * 0.22)
        }
    }
}

private struct WatchlistFolderParticleFieldLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        Canvas { context, size in
            let points = 28
            for index in 0..<points {
                let hash = index &* 265_443
                let x = CGFloat(hash % 10_000) / 10_000 * size.width
                let y = CGFloat((hash / 10_000) % 10_000) / 10_000 * size.height
                let radius = 0.8 + CGFloat(hash % 3) * 0.4
                let alpha = palette.intensity(0.10, light: 0.06) + Double(hash % 5) * 0.015
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: radius, height: radius)),
                    with: .color(palette.accent.opacity(alpha))
                )
            }
        }
        .blur(radius: 0.4)
    }
}

private struct WatchlistFolderWaveBandsLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        Canvas { context, size in
            for index in 0..<3 {
                let baseY = size.height * (0.42 + CGFloat(index) * 0.12)
                var wave = Path()
                wave.move(to: CGPoint(x: 0, y: baseY))
                wave.addCurve(
                    to: CGPoint(x: size.width, y: baseY - 8),
                    control1: CGPoint(x: size.width * 0.33, y: baseY + 16),
                    control2: CGPoint(x: size.width * 0.66, y: baseY - 16)
                )
                context.stroke(
                    wave,
                    with: .color(palette.line.opacity(0.35 - Double(index) * 0.08)),
                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round)
                )
            }
        }
        .blur(radius: 0.8)
    }
}

private struct WatchlistFolderSphereClusterLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        ZStack {
            sphere(d: palette.size.width * 0.18, x: -0.18, y: -0.10)
            sphere(d: palette.size.width * 0.14, x: 0.16, y: 0.04)
            sphere(d: palette.size.width * 0.11, x: -0.04, y: 0.18)
        }
    }

    private func sphere(d: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [palette.whisper, palette.glow.opacity(0.5), .clear],
                    center: UnitPoint(x: 0.35, y: 0.30),
                    startRadius: 0,
                    endRadius: d * 0.55
                )
            )
            .frame(width: d, height: d)
            .offset(x: palette.size.width * x, y: palette.size.height * y)
            .blur(radius: 4)
    }
}

private struct WatchlistFolderThinArcsLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        Canvas { context, size in
            let centers: [CGPoint] = [
                CGPoint(x: size.width * 0.72, y: size.height * 0.28),
                CGPoint(x: size.width * 0.30, y: size.height * 0.68),
            ]
            for (index, center) in centers.enumerated() {
                let radius = size.width * (0.28 + CGFloat(index) * 0.08)
                var arc = Path()
                arc.addArc(center: center, radius: radius, startAngle: .degrees(-130), endAngle: .degrees(-20), clockwise: false)
                context.stroke(arc, with: .color(palette.line.opacity(0.45)), style: StrokeStyle(lineWidth: 0.7, lineCap: .round))
            }
        }
    }
}

private struct WatchlistFolderStackedGlassLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        ZStack {
            glassSlab(x: 0.06, y: -0.10, rotation: -6, opacity: 0.10)
            glassSlab(x: 0.14, y: 0.02, rotation: 4, opacity: 0.14)
            glassSlab(x: -0.04, y: 0.12, rotation: -2, opacity: 0.11)
        }
    }

    private func glassSlab(x: CGFloat, y: CGFloat, rotation: Double, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(palette.whisper.opacity(opacity))
            .frame(width: palette.size.width * 0.48, height: palette.size.height * 0.18)
            .rotationEffect(.degrees(rotation))
            .offset(x: palette.size.width * x, y: palette.size.height * y)
            .blur(radius: 1)
    }
}

private struct WatchlistFolderDiagonalBlocksLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        ZStack {
            block(w: 0.34, h: 0.52, x: -0.16, y: 0.08, opacity: 0.18)
            block(w: 0.28, h: 0.40, x: 0.18, y: -0.10, opacity: 0.24)
        }
    }

    private func block(w: CGFloat, h: CGFloat, x: CGFloat, y: CGFloat, opacity: Double) -> some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(palette.glow.opacity(opacity))
            .frame(width: palette.size.width * w, height: palette.size.height * h)
            .rotationEffect(.degrees(12))
            .offset(x: palette.size.width * x, y: palette.size.height * y)
            .blur(radius: 8)
    }
}

private struct WatchlistFolderHaloRingLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        Circle()
            .strokeBorder(
                LinearGradient(
                    colors: [palette.glow.opacity(0.55), palette.softGlow.opacity(0.12), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1.2
            )
            .frame(width: palette.size.width * 0.58, height: palette.size.width * 0.58)
            .offset(x: palette.size.width * 0.12, y: -palette.size.height * 0.06)
            .blur(radius: 0.8)
    }
}

private struct WatchlistFolderLiquidRibbonLayer: View {
    let palette: WatchlistFolderCompositionPalette

    var body: some View {
        Canvas { context, size in
            var ribbon = Path()
            ribbon.move(to: CGPoint(x: -20, y: size.height * 0.55))
            ribbon.addCurve(
                to: CGPoint(x: size.width * 0.55, y: size.height * 0.22),
                control1: CGPoint(x: size.width * 0.12, y: size.height * 0.72),
                control2: CGPoint(x: size.width * 0.28, y: size.height * 0.08)
            )
            ribbon.addCurve(
                to: CGPoint(x: size.width + 20, y: size.height * 0.48),
                control1: CGPoint(x: size.width * 0.72, y: size.height * 0.34),
                control2: CGPoint(x: size.width * 0.88, y: size.height * 0.62)
            )
            context.stroke(ribbon, with: .color(palette.line.opacity(0.55)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
            context.stroke(ribbon, with: .color(palette.whisper.opacity(0.8)), style: StrokeStyle(lineWidth: 3.0, lineCap: .round))
        }
        .blur(radius: 1.0)
    }
}
