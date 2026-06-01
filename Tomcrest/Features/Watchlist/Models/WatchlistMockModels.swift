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
    let gradientTop: UInt32
    let gradientBottom: UInt32
    let accent: UInt32
    let borderOpacity: Double

    var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: gradientTop, opacity: 0.88), Color(hex: gradientBottom, opacity: 0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var accentColor: Color { Color(hex: accent) }
}

enum WatchlistPremiumPalette {
    static let swatches: [WatchlistSwatch] = [
        WatchlistSwatch(id: "mauve", name: "Soft mauve", gradientTop: 0x3d2f42, gradientBottom: 0x2a2230, accent: 0xd4a5c8, borderOpacity: 0.18),
        WatchlistSwatch(id: "sage", name: "Sage mist", gradientTop: 0x2a3530, gradientBottom: 0x1e2824, accent: 0x9ecfb0, borderOpacity: 0.16),
        WatchlistSwatch(id: "lavender", name: "Lavender dusk", gradientTop: 0x2e2a40, gradientBottom: 0x221e30, accent: 0xb8a8e8, borderOpacity: 0.17),
        WatchlistSwatch(id: "teal", name: "Muted teal", gradientTop: 0x1e3336, gradientBottom: 0x152528, accent: 0x6ec4c8, borderOpacity: 0.15),
        WatchlistSwatch(id: "sand", name: "Warm sand", gradientTop: 0x3a3428, gradientBottom: 0x2a261e, accent: 0xe8c896, borderOpacity: 0.14),
        WatchlistSwatch(id: "rose", name: "Dusty rose", gradientTop: 0x3a2a30, gradientBottom: 0x2a1e24, accent: 0xe8a0b4, borderOpacity: 0.16),
        WatchlistSwatch(id: "slate", name: "Cool slate", gradientTop: 0x2a2e36, gradientBottom: 0x1e2128, accent: 0x94a8c4, borderOpacity: 0.12),
        WatchlistSwatch(id: "ocean", name: "Ocean haze", gradientTop: 0x243040, gradientBottom: 0x1a2430, accent: 0x7eb8d8, borderOpacity: 0.14),
    ]

    static func swatch(id: WatchlistSwatch.ID) -> WatchlistSwatch {
        swatches.first { $0.id == id } ?? swatches[0]
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
