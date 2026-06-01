import SwiftUI

/// Abstract visual language for folder backgrounds — subtle, icon-safe, Apple-quality.
enum WatchlistFolderComposition: String, Hashable, CaseIterable {
    case classic
    case cornerOrb
    case twinOrbs
    case concentricRings
    case curvedFlow
    case diagonalRibbon
    case glassPanel
    case layeredRects
    case orbitalArc
    case metallicLines
    case visionFloat
    case softGrid
    case organicBlob
    case radialBurst
    case lightStreak
    case architecturalBlock
    case meshGradient
    case particleField
    case waveBands
    case sphereCluster
    case thinArcs
    case stackedGlass
    case diagonalBlocks
    case haloRing
    case liquidRibbon
}

extension WatchlistFolderComposition {
    var pickerSection: WatchlistFolderCompositionSection {
        switch self {
        case .classic:
            return .classic
        case .cornerOrb, .twinOrbs, .sphereCluster, .radialBurst, .haloRing:
            return .luminous
        case .curvedFlow, .diagonalRibbon, .orbitalArc, .thinArcs, .liquidRibbon, .lightStreak, .waveBands, .metallicLines:
            return .linear
        case .glassPanel, .layeredRects, .stackedGlass, .diagonalBlocks, .architecturalBlock, .visionFloat:
            return .material
        case .concentricRings, .softGrid, .organicBlob, .meshGradient, .particleField:
            return .pattern
        }
    }
}

enum WatchlistFolderCompositionSection: String, CaseIterable {
    case classic = "Classic tones"
    case luminous = "Orbs & light"
    case linear = "Lines & flow"
    case material = "Glass & depth"
    case pattern = "Pattern & form"

    var swatches: [WatchlistSwatch] {
        WatchlistPremiumPalette.swatches.filter { $0.composition.pickerSection == self }
    }
}
