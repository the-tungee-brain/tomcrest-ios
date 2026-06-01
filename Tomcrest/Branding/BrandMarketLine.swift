import SwiftUI

struct BrandMarketLine: View {
    let theme: BrandTheme

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let phase = BrandMotion.linePhase(at: timeline.date)
                drawLine(in: &context, size: size, phase: phase, opacity: 0.95, width: 2.2, lift: 0)
                drawLine(in: &context, size: size, phase: phase + 0.18, opacity: 0.35, width: 1.4, lift: 18)
            }
        }
        .allowsHitTesting(false)
    }

    private func drawLine(
        in context: inout GraphicsContext,
        size: CGSize,
        phase: CGFloat,
        opacity: Double,
        width: CGFloat,
        lift: CGFloat
    ) {
        var path = Path()
        let baseline = size.height * 0.58 + lift
        let drift = phase * size.width * 0.35

        path.move(to: CGPoint(x: -size.width * 0.15 + drift, y: baseline + 26))

        let points: [CGPoint] = [
            CGPoint(x: size.width * 0.08 + drift, y: baseline + 8),
            CGPoint(x: size.width * 0.22 + drift, y: baseline - 18),
            CGPoint(x: size.width * 0.38 + drift, y: baseline - 6),
            CGPoint(x: size.width * 0.52 + drift, y: baseline - 28),
            CGPoint(x: size.width * 0.68 + drift, y: baseline - 12),
            CGPoint(x: size.width * 0.84 + drift, y: baseline - 34),
            CGPoint(x: size.width * 1.08 + drift, y: baseline - 16),
        ]

        for point in points {
            path.addLine(to: point)
        }

        context.stroke(
            path,
            with: .color(theme.linePrimary.opacity(opacity)),
            style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
        )
    }
}
