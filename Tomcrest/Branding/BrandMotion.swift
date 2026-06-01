import SwiftUI

enum BrandMotion {
    static let breathe = Animation.easeInOut(duration: 2.4).repeatForever(autoreverses: true)
    static let drift = Animation.linear(duration: 10).repeatForever(autoreverses: false)
    static let taglineFade = Animation.easeInOut(duration: 0.45)
    static let shellCrossfade = Animation.easeInOut(duration: 0.35)

    static func breatheScale(at date: Date) -> CGFloat {
        let phase = date.timeIntervalSinceReferenceDate / 2.4
        let wave = sin(phase * .pi * 2)
        return 1 + (wave * 0.035)
    }

    static func parallaxOffset(at date: Date) -> CGSize {
        let t = date.timeIntervalSinceReferenceDate
        return CGSize(
            width: sin(t * 0.55) * 3,
            height: cos(t * 0.42) * 2
        )
    }

    static func linePhase(at date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 12) / 12)
    }
}
