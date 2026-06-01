import SwiftUI
import UniformTypeIdentifiers

// MARK: - Domain

struct WatchlistSymbol: Identifiable, Equatable, Hashable {
    let id: UUID
    var ticker: String
    var companyName: String
    var price: Double
    var dayChange: Double
    var dayChangePercent: Double
    var createdAt: Date? = nil
}

struct WatchlistFolder: Identifiable, Equatable {
    let id: UUID
    var name: String
    var iconName: String
    var symbols: [WatchlistSymbol]
    var swatchID: WatchlistSwatch.ID
    var accentHex: UInt32?
    var isPinned: Bool
    var isCollapsed: Bool
    var sortOrder: Int
    var createdAt: Date? = nil
}

// MARK: - Premium palette

struct WatchlistSwatch: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let composition: WatchlistFolderComposition
    let gradientTop: UInt32
    let gradientBottom: UInt32
    let accent: UInt32
    let borderOpacity: Double

    init(
        id: String,
        name: String,
        composition: WatchlistFolderComposition = .classic,
        gradientTop: UInt32,
        gradientBottom: UInt32,
        accent: UInt32,
        borderOpacity: Double
    ) {
        self.id = id
        self.name = name
        self.composition = composition
        self.gradientTop = gradientTop
        self.gradientBottom = gradientBottom
        self.accent = accent
        self.borderOpacity = borderOpacity
    }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: gradientTop, opacity: 0.88), Color(hex: gradientBottom, opacity: 0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var accentColor: Color { Color(hex: accent) }

    var isClassic: Bool { composition == .classic }
}

enum WatchlistPremiumPalette {
    static let classicSwatches: [WatchlistSwatch] = [
        WatchlistSwatch(id: "mauve", name: "Soft mauve", gradientTop: 0x3d2f42, gradientBottom: 0x2a2230, accent: 0xd4a5c8, borderOpacity: 0.18),
        WatchlistSwatch(id: "sage", name: "Sage mist", gradientTop: 0x2a3530, gradientBottom: 0x1e2824, accent: 0x9ecfb0, borderOpacity: 0.16),
        WatchlistSwatch(id: "lavender", name: "Lavender dusk", gradientTop: 0x2e2a40, gradientBottom: 0x221e30, accent: 0xb8a8e8, borderOpacity: 0.17),
        WatchlistSwatch(id: "teal", name: "Muted teal", gradientTop: 0x1e3336, gradientBottom: 0x152528, accent: 0x6ec4c8, borderOpacity: 0.15),
        WatchlistSwatch(id: "sand", name: "Warm sand", gradientTop: 0x3a3428, gradientBottom: 0x2a261e, accent: 0xe8c896, borderOpacity: 0.14),
        WatchlistSwatch(id: "rose", name: "Dusty rose", gradientTop: 0x3a2a30, gradientBottom: 0x2a1e24, accent: 0xe8a0b4, borderOpacity: 0.16),
        WatchlistSwatch(id: "slate", name: "Cool slate", gradientTop: 0x2a2e36, gradientBottom: 0x1e2128, accent: 0x94a8c4, borderOpacity: 0.12),
        WatchlistSwatch(id: "ocean", name: "Ocean haze", gradientTop: 0x243040, gradientBottom: 0x1a2430, accent: 0x7eb8d8, borderOpacity: 0.14),
    ]

    static let abstractSwatches: [WatchlistSwatch] = [
        // Orbs & light
        WatchlistSwatch(id: "orb-iris", name: "Iris orb", composition: .cornerOrb, gradientTop: 0x342848, gradientBottom: 0x1e1830, accent: 0xb8a0e8, borderOpacity: 0.15),
        WatchlistSwatch(id: "orb-mist", name: "Mist orb", composition: .cornerOrb, gradientTop: 0x283038, gradientBottom: 0x1a2028, accent: 0x98b8d0, borderOpacity: 0.13),
        WatchlistSwatch(id: "twin-rose", name: "Twin rose", composition: .twinOrbs, gradientTop: 0x382830, gradientBottom: 0x241820, accent: 0xe8a8b8, borderOpacity: 0.15),
        WatchlistSwatch(id: "twin-jade", name: "Twin jade", composition: .twinOrbs, gradientTop: 0x243028, gradientBottom: 0x182018, accent: 0x88c8a8, borderOpacity: 0.14),
        WatchlistSwatch(id: "sphere-noir", name: "Floating spheres", composition: .sphereCluster, gradientTop: 0x222428, gradientBottom: 0x141618, accent: 0xa8b0bc, borderOpacity: 0.12),
        WatchlistSwatch(id: "radial-dawn", name: "Radial dawn", composition: .radialBurst, gradientTop: 0x3a3028, gradientBottom: 0x241c18, accent: 0xe8c090, borderOpacity: 0.14),
        WatchlistSwatch(id: "halo-moon", name: "Halo moon", composition: .haloRing, gradientTop: 0x282c34, gradientBottom: 0x181c22, accent: 0xc0c8d8, borderOpacity: 0.13),
        // Lines & flow
        WatchlistSwatch(id: "flow-azure", name: "Azure flow", composition: .curvedFlow, gradientTop: 0x1e2c38, gradientBottom: 0x121820, accent: 0x78b8d8, borderOpacity: 0.14),
        WatchlistSwatch(id: "flow-plum", name: "Plum flow", composition: .curvedFlow, gradientTop: 0x302038, gradientBottom: 0x1c1424, accent: 0xc098d0, borderOpacity: 0.15),
        WatchlistSwatch(id: "ribbon-sand", name: "Sand ribbon", composition: .diagonalRibbon, gradientTop: 0x363028, gradientBottom: 0x242018, accent: 0xd8b880, borderOpacity: 0.13),
        WatchlistSwatch(id: "ribbon-noir", name: "Noir ribbon", composition: .diagonalRibbon, gradientTop: 0x222226, gradientBottom: 0x121214, accent: 0x9898a4, borderOpacity: 0.11),
        WatchlistSwatch(id: "orbital-gold", name: "Orbital gold", composition: .orbitalArc, gradientTop: 0x2a2820, gradientBottom: 0x181610, accent: 0xd0b060, borderOpacity: 0.14),
        WatchlistSwatch(id: "orbital-steel", name: "Orbital steel", composition: .orbitalArc, gradientTop: 0x242830, gradientBottom: 0x141820, accent: 0x90a8c0, borderOpacity: 0.13),
        WatchlistSwatch(id: "arcs-minimal", name: "Thin arcs", composition: .thinArcs, gradientTop: 0x2a2a30, gradientBottom: 0x18181c, accent: 0xa8a8b8, borderOpacity: 0.12),
        WatchlistSwatch(id: "liquid-teal", name: "Liquid ribbon", composition: .liquidRibbon, gradientTop: 0x1a3034, gradientBottom: 0x101c20, accent: 0x68c0c8, borderOpacity: 0.14),
        WatchlistSwatch(id: "streak-ice", name: "Ice streak", composition: .lightStreak, gradientTop: 0x283038, gradientBottom: 0x181e24, accent: 0xa0c8e0, borderOpacity: 0.13),
        WatchlistSwatch(id: "wave-midnight", name: "Midnight waves", composition: .waveBands, gradientTop: 0x1a2434, gradientBottom: 0x0e141c, accent: 0x6898c8, borderOpacity: 0.14),
        WatchlistSwatch(id: "metal-champagne", name: "Champagne lines", composition: .metallicLines, gradientTop: 0x2c2820, gradientBottom: 0x181410, accent: 0xc8a870, borderOpacity: 0.13),
        // Glass & depth
        WatchlistSwatch(id: "glass-pearl", name: "Frosted pearl", composition: .glassPanel, gradientTop: 0x343840, gradientBottom: 0x222428, accent: 0xd0d4dc, borderOpacity: 0.12),
        WatchlistSwatch(id: "glass-obsidian", name: "Obsidian glass", composition: .glassPanel, gradientTop: 0x1c1c20, gradientBottom: 0x0e0e10, accent: 0x888890, borderOpacity: 0.10),
        WatchlistSwatch(id: "layer-sage", name: "Layered sage", composition: .layeredRects, gradientTop: 0x283028, gradientBottom: 0x181c18, accent: 0x98c0a0, borderOpacity: 0.14),
        WatchlistSwatch(id: "layer-indigo", name: "Layered indigo", composition: .layeredRects, gradientTop: 0x242038, gradientBottom: 0x141020, accent: 0x9890d8, borderOpacity: 0.15),
        WatchlistSwatch(id: "stack-glass", name: "Stacked glass", composition: .stackedGlass, gradientTop: 0x2a2e34, gradientBottom: 0x161820, accent: 0xb0b8c4, borderOpacity: 0.12),
        WatchlistSwatch(id: "block-graphite", name: "Graphite blocks", composition: .diagonalBlocks, gradientTop: 0x2e2e32, gradientBottom: 0x1a1a1c, accent: 0x9898a0, borderOpacity: 0.11),
        WatchlistSwatch(id: "arch-stone", name: "Stone arch", composition: .architecturalBlock, gradientTop: 0x323028, gradientBottom: 0x201c18, accent: 0xb8a890, borderOpacity: 0.13),
        WatchlistSwatch(id: "vision-aqua", name: "Vision aqua", composition: .visionFloat, gradientTop: 0x1a2c30, gradientBottom: 0x0e181c, accent: 0x70c8d0, borderOpacity: 0.14),
        WatchlistSwatch(id: "vision-blush", name: "Vision blush", composition: .visionFloat, gradientTop: 0x342428, gradientBottom: 0x201418, accent: 0xe0a0b0, borderOpacity: 0.15),
        // Pattern & form
        WatchlistSwatch(id: "ring-slate", name: "Slate rings", composition: .concentricRings, gradientTop: 0x2a2e34, gradientBottom: 0x181c20, accent: 0x98a8b8, borderOpacity: 0.13),
        WatchlistSwatch(id: "ring-copper", name: "Copper rings", composition: .concentricRings, gradientTop: 0x342820, gradientBottom: 0x201810, accent: 0xc89060, borderOpacity: 0.14),
        WatchlistSwatch(id: "grid-fog", name: "Soft grid", composition: .softGrid, gradientTop: 0x2c2c30, gradientBottom: 0x18181a, accent: 0xa0a4ac, borderOpacity: 0.11),
        WatchlistSwatch(id: "blob-emerald", name: "Emerald blob", composition: .organicBlob, gradientTop: 0x1a3028, gradientBottom: 0x0e1c16, accent: 0x68c098, borderOpacity: 0.14),
        WatchlistSwatch(id: "blob-lilac", name: "Lilac blob", composition: .organicBlob, gradientTop: 0x302838, gradientBottom: 0x1c1424, accent: 0xb898d8, borderOpacity: 0.15),
        WatchlistSwatch(id: "mesh-coral", name: "Coral mesh", composition: .meshGradient, gradientTop: 0x382428, gradientBottom: 0x241418, accent: 0xe09098, borderOpacity: 0.14),
        WatchlistSwatch(id: "particle-noir", name: "Noir particles", composition: .particleField, gradientTop: 0x1e1e22, gradientBottom: 0x101012, accent: 0x808088, borderOpacity: 0.10),
    ]

    static let swatches: [WatchlistSwatch] = classicSwatches + abstractSwatches

    /// IDs accepted by the Tomcrest API — keep in sync with `app/constants/watchlist_swatches.py`.
    static let knownIDs: Set<WatchlistSwatch.ID> = Set(swatches.map(\.id))

    static func swatch(id: WatchlistSwatch.ID) -> WatchlistSwatch {
        swatches.first { $0.id == id } ?? swatches[0]
    }

    static func isKnown(id: WatchlistSwatch.ID) -> Bool {
        knownIDs.contains(id)
    }
}

// MARK: - Design variants

enum WatchlistDesignVariant: String, CaseIterable, Identifiable {
    case gallery = "Gallery"
    case ledger = "Ledger"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .gallery: "Premium cards · inline expand"
        case .ledger: "Grouped list · sticky sections"
        }
    }
}

// MARK: - Folder sort

enum WatchlistFolderSortMode: String, CaseIterable, Identifiable {
    case custom = "Custom order"
    case name = "Name"
    case dateAdded = "Date created"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .custom: "line.3.horizontal"
        case .name: "textformat.abc"
        case .dateAdded: "calendar"
        }
    }
}

// MARK: - Drag payload

struct WatchlistSymbolDragPayload: Codable, Transferable, Hashable {
    let symbolID: UUID
    let sourceFolderID: UUID

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .watchlistSymbolDrag)
    }
}

extension UTType {
    static let watchlistSymbolDrag = UTType(exportedAs: "com.tomcrest.watchlist-symbol-drag")
}

enum WatchlistProfitTone {
    static func color(for value: Double) -> Color {
        if value > 0 { return AppColors.success }
        if value < 0 { return AppColors.error }
        return AppColors.secondaryLabel
    }
}
