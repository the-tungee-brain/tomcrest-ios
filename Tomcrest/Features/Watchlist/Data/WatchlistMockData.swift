import Foundation

enum WatchlistMockData {
    static func seedFolders() -> [WatchlistFolder] {
        [
            WatchlistFolder(
                id: UUID(uuidString: "A1000001-0000-4000-8000-000000000001")!,
                name: "Tech growth",
                iconName: "chart.line.uptrend.xyaxis",
                symbols: [
                    symbol("NVDA", "NVIDIA"),
                    symbol("AAPL", "Apple"),
                    symbol("MSFT", "Microsoft"),
                    symbol("AMD", "Advanced Micro Devices"),
                ],
                swatchID: "lavender",
                accentHex: nil,
                isPinned: true,
                isCollapsed: false,
                sortOrder: 0
            ),
            WatchlistFolder(
                id: UUID(uuidString: "A1000002-0000-4000-8000-000000000002")!,
                name: "Dividend income",
                iconName: "banknote.fill",
                symbols: [
                    symbol("SCHD", "Schwab US Dividend"),
                    symbol("JNJ", "Johnson & Johnson"),
                    symbol("KO", "Coca-Cola"),
                ],
                swatchID: "sage",
                accentHex: nil,
                isPinned: true,
                isCollapsed: false,
                sortOrder: 1
            ),
            WatchlistFolder(
                id: UUID(uuidString: "A1000003-0000-4000-8000-000000000003")!,
                name: "Index ETFs",
                iconName: "chart.pie.fill",
                symbols: [
                    symbol("SPY", "SPDR S&P 500"),
                    symbol("QQQ", "Invesco QQQ"),
                    symbol("VTI", "Vanguard Total Stock"),
                ],
                swatchID: "teal",
                accentHex: nil,
                isPinned: false,
                isCollapsed: false,
                sortOrder: 2
            ),
            WatchlistFolder(
                id: UUID(uuidString: "A1000004-0000-4000-8000-000000000004")!,
                name: "Watch later",
                iconName: "eye.fill",
                symbols: [
                    symbol("PLTR", "Palantir"),
                    symbol("COIN", "Coinbase"),
                ],
                swatchID: "rose",
                accentHex: nil,
                isPinned: false,
                isCollapsed: true,
                sortOrder: 3
            ),
        ]
    }

    private static func symbol(_ ticker: String, _ company: String) -> WatchlistSymbol {
        WatchlistSymbol(
            id: UUID(),
            ticker: ticker,
            companyName: company
        )
    }
}
