import Foundation

struct StockChartPayload: Decodable {
    let symbol: String
    let name: String
    let currency: String
    let data: [StockChartPoint]
}

struct StockChartPoint: Decodable, Identifiable {
    var id: String { date }
    let date: String
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Int
}

enum StockChartPeriod: String, CaseIterable, Identifiable {
    case oneMonth = "1mo"
    case threeMonths = "3mo"
    case sixMonths = "6mo"
    case oneYear = "1y"
    case twoYears = "2y"
    case fiveYears = "5y"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .oneYear: "1Y"
        case .twoYears: "2Y"
        case .fiveYears: "5Y"
        }
    }
}
