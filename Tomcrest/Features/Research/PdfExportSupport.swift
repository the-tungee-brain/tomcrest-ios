import SwiftUI
import UIKit

enum PdfExportSupport {
    static func writeWheelBacktestPdf(_ result: WheelBacktestResult, query: WheelBacktestQuery) -> URL? {
        let title = "Wheel Backtest — \(result.symbol)"
        var lines: [String] = [
            title,
            "",
            "Lookback: \(result.lookbackYears) years",
            "Delta: \(String(format: "%.2f", query.targetDeltaMin))–\(String(format: "%.2f", query.targetDeltaMax))",
            "DTE: \(query.dteDays) days",
            "Period: \(DateFormatters.display(from: result.startDate)) → \(DateFormatters.display(from: result.endDate))",
            "",
            "Total return: \(CurrencyFormatter.percent(result.totalReturnPct))",
            "CAGR: \(CurrencyFormatter.percent(result.cagrPct ?? 0))",
            "Buy & hold: \(CurrencyFormatter.percent(result.buyAndHoldReturnPct))",
            "Premium collected: \(CurrencyFormatter.usd(result.totalPremiumCollectedUsd, fractionDigits: 0))",
            "Put assignments: \(result.putAssignments)",
            "Wheel cycles: \(result.completedWheelCycles)",
            "",
        ]

        if let annual = result.annualSummary, !annual.isEmpty {
            lines.append("Year-by-year")
            for row in annual {
                lines.append(
                    "\(row.year): \(CurrencyFormatter.percent(row.returnPct ?? 0)) · P/L \(CurrencyFormatter.usd(row.plUsd ?? 0, fractionDigits: 0))"
                )
            }
            lines.append("")
        }

        if let cycles = result.wheelCycles, !cycles.isEmpty {
            lines.append("Assigned cycles")
            for cycle in cycles {
                lines.append(
                    "Cycle \(cycle.cycle): put \(cycle.putStrike.map { CurrencyFormatter.usd($0) } ?? "—") → call \(cycle.callStrike.map { CurrencyFormatter.usd($0) } ?? "—")"
                )
            }
            lines.append("")
        }

        lines.append("Trade log")
        for trade in result.trades.prefix(80) {
            let cycle = trade.wheelCycle.map { "C\($0)" } ?? ""
            lines.append("\(DateFormatters.display(from: trade.date)) \(cycle) \(trade.action) \(trade.label ?? "")")
        }

        if let assumptions = result.assumptions, !assumptions.isEmpty {
            lines.append("")
            lines.append("Assumptions")
            assumptions.forEach { lines.append("• \($0)") }
        }

        return writePdf(title: title, lines: lines, filename: "wheel-\(result.symbol)-backtest.pdf")
    }

    static func writeDividendSnowballPdf(
        symbol: String,
        context: DividendHistoryContext,
        projectYears: Int,
        reinvest: Bool
    ) -> URL? {
        let title = "Dividend Snowball — \(symbol)"
        var lines: [String] = [
            title,
            "",
            "Projection: \(projectYears) years",
            "DRIP: \(reinvest ? "On" : "Off")",
            "Yield: \(context.dividendYieldPct.map { String(format: "%.2f%%", $0) } ?? "—")",
            "5Y CAGR: \(context.cagr5yPct.map { String(format: "%.2f%%", $0) } ?? "—")",
            "",
        ]

        if let scenario = context.scenario {
            lines.append("Scenario summary")
            lines.append("Total collected: \(CurrencyFormatter.usd(scenario.totalCollected, fractionDigits: 0))")
            lines.append("Latest annual income: \(CurrencyFormatter.usd(scenario.annualIncomeLatest, fractionDigits: 0))")
            lines.append("Starting annual income: \(CurrencyFormatter.usd(scenario.annualIncomeStart, fractionDigits: 0))")
            lines.append("")
        }

        lines.append("Annual income history")
        for row in context.annualIncome.prefix(12) {
            lines.append("\(row.year): \(CurrencyFormatter.usd(row.incomeOnShares, fractionDigits: 0))")
        }

        return writePdf(title: title, lines: lines, filename: "dividend-\(symbol)-snowball.pdf")
    }

    static func writeDividendBacktestPdf(
        symbol: String,
        context: DividendHistoryContext,
        query: DividendBacktestQuery
    ) -> URL? {
        guard let backtest = context.historicalBacktest else { return nil }
        let title = "Dividend Backtest — \(symbol.uppercased())"
        var lines: [String] = [
            title,
            "",
            "Window: \(backtest.startYear) → \(backtest.endYear)",
            "Shares: \(String(format: "%.2f", query.shares))",
            "DRIP: \(query.reinvestDividends ? "On" : "Off")",
            "Annual contribution: \(CurrencyFormatter.usd(query.annualContributionUsd, fractionDigits: 0))",
            "",
            "Total dividend income: \(CurrencyFormatter.usd(backtest.cashCollected, fractionDigits: 0))",
        ]

        if let drip = backtest.drip {
            lines.append("Portfolio value: \(CurrencyFormatter.usd(drip.portfolioValueLatest, fractionDigits: 0))")
            lines.append("Final shares: \(String(format: "%.2f", drip.finalShares))")
            lines.append("Reinvested: \(CurrencyFormatter.usd(drip.totalDividendsReinvested, fractionDigits: 0))")
            lines.append("")
        }

        if !backtest.yearlyBreakdown.isEmpty {
            lines.append("Year-by-year")
            for row in backtest.yearlyBreakdown {
                lines.append(
                    "\(row.year): DPS \(String(format: "$%.4f", row.dps)) · \(String(format: "%.2f", row.shares)) sh · \(CurrencyFormatter.usd(row.dividendIncome, fractionDigits: 0)) · \(String(format: "%.2f%%", row.dividendYieldPct)) yield"
                )
            }
        }

        if let dataAsOf = context.dataAsOf, !dataAsOf.isEmpty {
            lines.append("")
            lines.append("Data as of \(DateFormatters.display(from: dataAsOf))")
        }

        return writePdf(
            title: title,
            lines: lines,
            filename: "dividend-backtest-\(symbol.uppercased())-\(backtest.startYear)-\(backtest.endYear).pdf"
        )
    }

    private static func writePdf(title: String, lines: [String], filename: String) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let data = renderer.pdfData { context in
            context.beginPage()
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11),
                .foregroundColor: UIColor.label,
            ]
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 16),
                .foregroundColor: UIColor.label,
            ]
            var y: CGFloat = 40
            (title as NSString).draw(at: CGPoint(x: 40, y: y), withAttributes: titleAttrs)
            y += 28
            for line in lines {
                if y > pageRect.height - 40 {
                    context.beginPage()
                    y = 40
                }
                (line as NSString).draw(
                    in: CGRect(x: 40, y: y, width: pageRect.width - 80, height: 200),
                    withAttributes: attrs
                )
                y += line.isEmpty ? 8 : 16
            }
        }

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

struct PdfShareButton: View {
    let title: String
    let url: URL?

    var body: some View {
        if let url {
            ShareLink(item: url) {
                Label(title, systemImage: "square.and.arrow.up")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(AppSecondaryButtonStyle())
        }
    }
}
