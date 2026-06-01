import Foundation

struct BrandTipsCatalog: Decodable {
    let tips: [String]
}

enum BrandTips {
    private static let fallback = [
        "Pull to refresh Portfolio for the latest morning brief.",
        "Use the assistant chip on any symbol for a focused follow-up.",
        "Backtests replay history — they are guides, not guarantees.",
    ]

    static func tipOfTheDay(date: Date = .now) -> String? {
        let tips = loadTips()
        guard !tips.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        return tips[day % tips.count]
    }

    private static func loadTips() -> [String] {
        guard let url = Bundle.main.url(forResource: "BrandTips", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let catalog = try? JSONDecoder().decode(BrandTipsCatalog.self, from: data),
              !catalog.tips.isEmpty else {
            return fallback
        }
        return catalog.tips
    }
}
