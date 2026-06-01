//
//  GlowingIndicator.swift
//  RHLinePlot
//
//  Created by Wirawit Rueopas on 4/9/20.
//  Copyright © 2020 Wirawit Rueopas. All rights reserved.
//

import SwiftUI

/// Default indicator with glowing effect. Used to show latest value in a line plot.
public struct GlowingIndicator: View {

    @Environment(\.rhLinePlotConfig) private var rhLinePlotConfig

    public init() {}

    private var dotSize: CGFloat { rhLinePlotConfig.glowingIndicatorWidth }
    private var maxScale: CGFloat { rhLinePlotConfig.glowingIndicatorBackgroundScaleEffect }
    private var pulseDuration: Double { rhLinePlotConfig.glowingIndicatorGlowAnimationDuration }
    private var pulseDelay: Double { rhLinePlotConfig.glowingIndicatorDelayBetweenGlow }

    /// Clip pulse expansion so it never affects chart layout.
    private var containerSize: CGFloat { dotSize * maxScale }

    /// Peak opacity at the start of each pulse (ring is hidden between pulses).
    private var peakOpacity: Double { 0.62 }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            let pulse = pulseMetrics(at: context.date)

            ZStack {
                Circle()
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(pulse.scale)
                    .opacity(pulse.opacity)
                    .blur(radius: pulse.opacity > 0.01 ? 0.6 : 0)

                Circle()
                    .frame(width: dotSize, height: dotSize)
            }
            .frame(width: containerSize, height: containerSize)
            .compositingGroup()
        }
    }

    private func pulseMetrics(at date: Date) -> (scale: CGFloat, opacity: Double) {
        let cycle = pulseDelay + pulseDuration
        let elapsed = date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: max(cycle, 0.01))

        // Hidden between pulses — only the expanding ring is visible.
        if elapsed < pulseDelay {
            return (1, 0)
        }

        let progress = min(1, (elapsed - pulseDelay) / max(pulseDuration, 0.01))
        let eased = 1 - pow(1 - progress, 2.2)

        return (
            scale: 1 + (maxScale - 1) * eased,
            opacity: peakOpacity * (1 - eased)
        )
    }
}


struct GlowingIndicator_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            GlowingIndicator()
                .environment(\.rhLinePlotConfig, RHLinePlotConfig.default)
        }.previewLayout(.fixed(width: 200, height: 200))
    }
}
