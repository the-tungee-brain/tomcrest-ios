import CoreGraphics
import Foundation

struct StockChartPayload: Decodable {
    let symbol: String
    let name: String
    let currency: String
    let data: [StockChartPoint]
    let previousClose: Double?
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
    case oneDay = "1d"
    case oneWeek = "5d"
    case oneMonth = "1mo"
    case threeMonths = "3mo"
    case sixMonths = "6mo"
    case oneYear = "1y"
    case twoYears = "2y"
    case fiveYears = "5y"

    var id: String { rawValue }

    /// yfinance interval paired with each period (see `/get-stock-data`).
    var interval: String {
        switch self {
        case .oneDay: "1m"
        case .oneWeek: "15m"
        default: "1d"
        }
    }

    var label: String {
        switch self {
        case .oneDay: "1D"
        case .oneWeek: "1W"
        case .oneMonth: "1M"
        case .threeMonths: "3M"
        case .sixMonths: "6M"
        case .oneYear: "1Y"
        case .twoYears: "2Y"
        case .fiveYears: "5Y"
        }
    }

    var isRobinhoodIntradaySession: Bool {
        self == .oneDay
    }
}

// MARK: - Robinhood-style 1D session (4:00 AM – 8:00 PM Pacific)

enum IntradayChartTimeline {
    static let pacific = TimeZone(identifier: "America/Los_Angeles")!
    static let sessionStartHour = 4
    static let sessionEndHour = 20
    static let sessionDurationMinutes = (sessionEndHour - sessionStartHour) * 60
    /// Plot buckets — keeps scrubbing responsive vs. one point per minute.
    static let bucketMinutes = 5
    static let sessionBucketCount = sessionDurationMinutes / bucketMinutes

    struct PreparedChart {
        let points: [StockChartPoint]
        let values: [CGFloat]
        let occupyingRelativeWidth: CGFloat
    }

    static func prepare(
        rawPoints: [StockChartPoint],
        previousClose: Double?,
        now: Date = Date()
    ) -> PreparedChart {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pacific

        let parsed: [(date: Date, point: StockChartPoint)] = rawPoints.compactMap { point in
            guard let date = DateFormatters.parse(point.date) else { return nil }
            return (date, point)
        }.sorted { $0.date < $1.date }

        let referenceDate = parsed.last?.date ?? now
        let sessionDay = calendar.startOfDay(for: referenceDate)

        guard
            let sessionStart = calendar.date(
                bySettingHour: sessionStartHour,
                minute: 0,
                second: 0,
                of: sessionDay
            ),
            let sessionEnd = calendar.date(
                bySettingHour: sessionEndHour,
                minute: 0,
                second: 0,
                of: sessionDay
            )
        else {
            return fallback(from: rawPoints)
        }

        let priorClose = previousClose ?? parsed.first?.point.close ?? 0
        var pointsByBucket: [Int: StockChartPoint] = [:]

        for item in parsed {
            guard item.date >= sessionStart, item.date <= sessionEnd else { continue }
            let minute = Int(item.date.timeIntervalSince(sessionStart) / 60)
            guard minute >= 0, minute < sessionDurationMinutes else { continue }
            let bucket = minute / bucketMinutes
            pointsByBucket[bucket] = item.point
        }

        let plotEnd = min(max(now, sessionStart), sessionEnd)
        let elapsedMinutes = max(
            bucketMinutes,
            min(
                sessionDurationMinutes,
                Int(plotEnd.timeIntervalSince(sessionStart) / 60) + 1
            )
        )
        let elapsedBuckets = max(
            2,
            min(sessionBucketCount, (elapsedMinutes + bucketMinutes - 1) / bucketMinutes)
        )

        var values: [CGFloat] = []
        var displayPoints: [StockChartPoint] = []
        var lastClose = priorClose

        let iso = ISO8601DateFormatter()
        iso.timeZone = pacific
        iso.formatOptions = [.withInternetDateTime]

        for bucket in 0..<elapsedBuckets {
            let slotDate = sessionStart.addingTimeInterval(
                TimeInterval(bucket * bucketMinutes * 60)
            )
            if let point = pointsByBucket[bucket] {
                lastClose = point.close
                displayPoints.append(point)
            } else {
                displayPoints.append(
                    StockChartPoint(
                        date: iso.string(from: slotDate),
                        open: lastClose,
                        high: lastClose,
                        low: lastClose,
                        close: lastClose,
                        volume: 0
                    )
                )
            }
            values.append(CGFloat(lastClose))
        }

        let occupying = CGFloat(elapsedMinutes) / CGFloat(sessionDurationMinutes)

        return PreparedChart(
            points: displayPoints,
            values: values,
            occupyingRelativeWidth: min(max(occupying, 0.02), 1)
        )
    }

    private static func fallback(from rawPoints: [StockChartPoint]) -> PreparedChart {
        PreparedChart(
            points: rawPoints,
            values: rawPoints.map { CGFloat($0.close) },
            occupyingRelativeWidth: 1
        )
    }
}
