import Foundation

struct WatchlistWorkspaceResponse: Decodable {
    let folders: [WatchlistFolderDTO]
    let workspaceVersion: Int?

    init(folders: [WatchlistFolderDTO] = [], workspaceVersion: Int? = nil) {
        self.folders = folders
        self.workspaceVersion = workspaceVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        folders = try container.decodeIfPresent([WatchlistFolderDTO].self, forKey: .folders) ?? []
        workspaceVersion = try container.decodeIfPresent(Int.self, forKey: .workspaceVersion)
    }

    private enum CodingKeys: String, CodingKey {
        case folders
        case workspaceVersion
    }
}

struct WatchlistFolderDTO: Decodable {
    let id: String
    let name: String
    let iconName: String
    let swatchID: String
    let accentHex: Int?
    let isPinned: Bool
    let isCollapsed: Bool
    let sortOrder: Int
    let createdAt: String?
    let symbols: [WatchlistSymbolDTO]
}

struct WatchlistSymbolDTO: Decodable {
    let id: String
    let ticker: String
    let sortOrder: Int
    let companyName: String
    let price: Double?
    let dayChange: Double?
    let dayChangePercent: Double?
    let createdAt: String?
}

struct WatchlistWorkspaceSyncRequest: Encodable {
    let folders: [WatchlistFolderSyncPayload]
    let baseVersion: Int?
}

struct WatchlistFolderSyncPayload: Encodable {
    let id: String
    let name: String
    let iconName: String
    let swatchID: String
    let accentHex: Int?
    let isPinned: Bool
    let isCollapsed: Bool
    let sortOrder: Int
    let symbols: [WatchlistSymbolSyncPayload]
}

struct WatchlistSymbolSyncPayload: Encodable {
    let id: String
    let ticker: String
    let sortOrder: Int
}

enum WatchlistAPIMapping {
    static func folders(from response: WatchlistWorkspaceResponse) -> [WatchlistFolder] {
        response.folders.compactMap(mapFolder)
    }

    static func mapFolder(_ dto: WatchlistFolderDTO) -> WatchlistFolder? {
        guard let id = UUID(uuidString: dto.id) else { return nil }
        return WatchlistFolder(
            id: id,
            name: dto.name,
            iconName: dto.iconName,
            symbols: dto.symbols.compactMap(mapSymbol),
            swatchID: WatchlistPremiumPalette.isKnown(id: dto.swatchID) ? dto.swatchID : WatchlistPremiumPalette.swatches[0].id,
            accentHex: dto.accentHex.map { UInt32($0) },
            isPinned: dto.isPinned,
            isCollapsed: dto.isCollapsed,
            sortOrder: dto.sortOrder,
            createdAt: dto.createdAt.flatMap(DateFormatters.parse)
        )
    }

    static func mapSymbol(_ dto: WatchlistSymbolDTO) -> WatchlistSymbol? {
        guard let id = UUID(uuidString: dto.id) else { return nil }
        return WatchlistSymbol(
            id: id,
            ticker: dto.ticker,
            companyName: dto.companyName,
            createdAt: dto.createdAt.flatMap(DateFormatters.parse)
        )
    }

    static func quotes(from response: WatchlistWorkspaceResponse) -> [UUID: WatchlistQuote] {
        var quotes: [UUID: WatchlistQuote] = [:]
        for dto in response.folders.flatMap(\.symbols) {
            guard let id = UUID(uuidString: dto.id) else { continue }
            quotes[id] = WatchlistQuote(
                price: dto.price ?? 0,
                dayChange: dto.dayChange ?? 0,
                dayChangePercent: dto.dayChangePercent ?? 0
            )
        }
        return quotes
    }

    static func syncRequest(from folders: [WatchlistFolder], baseVersion: Int? = nil) -> WatchlistWorkspaceSyncRequest {
        let ordered = folders.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned && !rhs.isPinned }
            return lhs.sortOrder < rhs.sortOrder
        }

        return WatchlistWorkspaceSyncRequest(
            folders: ordered.enumerated().map { folderIndex, folder in
                WatchlistFolderSyncPayload(
                    id: folder.id.uuidString,
                    name: folder.name,
                    iconName: folder.iconName,
                    swatchID: folder.swatchID,
                    accentHex: folder.accentHex.map { Int($0) },
                    isPinned: folder.isPinned,
                    isCollapsed: folder.isCollapsed,
                    sortOrder: folderIndex,
                    symbols: folder.symbols.enumerated().map { symbolIndex, symbol in
                        WatchlistSymbolSyncPayload(
                            id: symbol.id.uuidString,
                            ticker: symbol.ticker,
                            sortOrder: symbolIndex
                        )
                    }
                )
            },
            baseVersion: baseVersion
        )
    }
}
