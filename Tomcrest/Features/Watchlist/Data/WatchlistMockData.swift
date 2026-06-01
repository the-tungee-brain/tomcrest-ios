import Foundation

enum WatchlistMockData {
    static func seedFolders() -> [WatchlistFolder] {
        [
            WatchlistFolder(
                id: UUID(uuidString: "A1000001-0000-4000-8000-000000000001")!,
                name: "Tech growth",
                iconName: "chart.line.uptrend.xyaxis",
                symbols: [
                    symbol("NVDA", "NVIDIA", 892.40, 18.20, 2.08),
                    symbol("AAPL", "Apple", 189.30, -1.42, -0.74),
                    symbol("MSFT", "Microsoft", 415.60, 3.85, 0.94),
                    symbol("AMD", "Advanced Micro Devices", 162.15, 4.22, 2.67),
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
                    symbol("SCHD", "Schwab US Dividend", 78.42, 0.18, 0.23),
                    symbol("JNJ", "Johnson & Johnson", 156.80, -0.55, -0.35),
                    symbol("KO", "Coca-Cola", 60.12, 0.08, 0.13),
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
                    symbol("SPY", "SPDR S&P 500", 512.30, 2.10, 0.41),
                    symbol("QQQ", "Invesco QQQ", 438.90, 3.44, 0.79),
                    symbol("VTI", "Vanguard Total Stock", 268.15, 1.02, 0.38),
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
                    symbol("PLTR", "Palantir", 24.88, -0.62, -2.43),
                    symbol("COIN", "Coinbase", 198.40, 6.20, 3.22),
                ],
                swatchID: "rose",
                accentHex: nil,
                isPinned: false,
                isCollapsed: true,
                sortOrder: 3
            ),
        ]
    }

    private static func symbol(
        _ ticker: String,
        _ company: String,
        _ price: Double,
        _ change: Double,
        _ changePct: Double
    ) -> WatchlistSymbol {
        WatchlistSymbol(
            id: UUID(),
            ticker: ticker,
            companyName: company,
            price: price,
            dayChange: change,
            dayChangePercent: changePct
        )
    }
}
