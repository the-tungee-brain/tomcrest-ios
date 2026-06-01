import SwiftUI

struct DividendBacktestSection: View {
    @Environment(AccountContext.self) private var account
    let context: DividendHistoryContext
    let marketSharePrice: Double?
    @Bindable var viewModel: SymbolDepthViewModel

    private var completedYears: [Int] {
        DividendBacktestSupport.completedYears(from: context)
    }

    var body: some View {
        if account.hasProFeature(.dividendSnowball) {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dividend backtest")
                        .font(.headline)
                        .foregroundStyle(AppColors.label)
                    Text(
                        "Replay actual dividend payments using your share count, optional DRIP, and annual contributions over a completed history window."
                    )
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineSpacing(2)
                }

                if completedYears.isEmpty {
                    AppEmptyMessage(message: "Not enough completed dividend history to run a backtest yet.")
                } else {
                    DividendBacktestControlsPanel(
                        context: context,
                        query: $viewModel.dividendBacktestQuery,
                        marketSharePrice: marketSharePrice,
                        completedYears: completedYears,
                        isLoading: viewModel.dividendBacktestLoading,
                        onRun: runBacktest
                    )

                    if let error = viewModel.tabErrors[.backtest] {
                        AppInlineBanner(message: error, tone: .error)
                    }

                    if viewModel.hasRunDividendBacktest, let backtest = context.historicalBacktest {
                        DividendBacktestResultsPanel(
                            backtest: backtest,
                            context: context,
                            query: viewModel.dividendBacktestQuery
                        )
                    } else if !viewModel.dividendBacktestLoading {
                        Text("Run a backtest to see results.")
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        } else {
            AppInlineBanner(
                message: "Upgrade to Pro for historical dividend backtest with DRIP and year-by-year breakdown.",
                tone: .neutral
            )
        }
    }

    private func runBacktest() {
        guard let startYear = DividendBacktestSupport.historyStartYear(
            completedYears: completedYears,
            lookbackYears: viewModel.dividendBacktestQuery.lookbackYears
        ) else { return }
        Task {
            await viewModel.loadDividendBacktest(
                historyStartYear: startYear,
                context: context,
                marketSharePrice: marketSharePrice
            )
        }
    }
}

private struct DividendBacktestControlsPanel: View {
    let context: DividendHistoryContext
    @Binding var query: DividendBacktestQuery
    let marketSharePrice: Double?
    let completedYears: [Int]
    let isLoading: Bool
    let onRun: () -> Void

    private var historyStartYear: Int? {
        DividendBacktestSupport.historyStartYear(
            completedYears: completedYears,
            lookbackYears: query.lookbackYears
        )
    }

    private var endYear: Int? {
        completedYears.last
    }

    private var startSharePrice: Double? {
        guard let historyStartYear, let endYear else { return nil }
        return DividendBacktestSupport.resolveStartSharePrice(
            context: context,
            marketSharePrice: marketSharePrice,
            startYear: historyStartYear,
            endYear: endYear
        )
    }

    private var canRunBacktest: Bool {
        DividendBacktestSupport.canRunBacktest(query: query, startSharePrice: startSharePrice)
    }

    private var windowLabel: String {
        guard let endYear = completedYears.last,
              let startYear = DividendBacktestSupport.historyStartYear(
                completedYears: completedYears,
                lookbackYears: query.lookbackYears
              ) else {
            return "—"
        }
        let span = endYear - startYear + 1
        return "\(startYear) → \(endYear) · \(span) \(span == 1 ? "year" : "years")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BacktestControlsShell(title: "Starting position") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter investment or shares — the other is calculated from the share price at the start of your history window.")
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineSpacing(2)

                    if let historyStartYear, let startSharePrice {
                        Text("\(historyStartYear) modeled price · \(CurrencyFormatter.usd(startSharePrice, fractionDigits: 2))/sh")
                            .font(AppTypography.monoCaption2)
                            .foregroundStyle(AppColors.tertiaryLabel)
                    }

                    DividendBacktestPositionFields(
                        investmentUsd: $query.investmentUsd,
                        shares: $query.shares,
                        startSharePrice: startSharePrice
                    )

                    BacktestDecimalField(
                        label: "Annual contribution",
                        placeholder: "0",
                        prefix: "$",
                        value: $query.annualContributionUsd,
                        allowsEmpty: true,
                        fractionDigits: 0
                    )

                    BacktestOptionToggle(
                        title: "Reinvest dividends (DRIP)",
                        footnote: "Use dividend payouts to buy more shares during the backtest.",
                        isOn: $query.reinvestDividends
                    )
                }
            }

            BacktestControlsShell(title: "History window") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(windowLabel)
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(AppColors.label)

                    BacktestChipRow(
                        options: DividendBacktestSupport.lookbackPresets.compactMap { years in
                            guard years <= DividendBacktestSupport.maxLookbackYears(completedYears: completedYears) else {
                                return nil
                            }
                            return (years, "\(years)y")
                        },
                        selection: $query.lookbackYears
                    )

                    BacktestRunButton(isLoading: isLoading, action: onRun)
                        .panelFooter
                        .opacity(canRunBacktest ? 1 : 0.45)
                        .allowsHitTesting(canRunBacktest && !isLoading)
                }
            }
        }
        .onChange(of: query.lookbackYears) { _, _ in
            resyncPositionFields()
        }
    }

    private func resyncPositionFields() {
        guard let startSharePrice, startSharePrice > 0 else { return }
        if query.investmentUsd > 0 {
            let synced = DividendBacktestSupport.syncFromInvestment(query.investmentUsd, startSharePrice: startSharePrice)
            query.investmentUsd = synced.investmentUsd
            query.shares = synced.shares
        } else if query.shares > 0 {
            let synced = DividendBacktestSupport.syncFromShares(query.shares, startSharePrice: startSharePrice)
            query.investmentUsd = synced.investmentUsd
            query.shares = synced.shares
        }
    }
}

private struct DividendBacktestPositionFields: View {
    @Binding var investmentUsd: Double
    @Binding var shares: Double
    let startSharePrice: Double?

    @State private var lastEdited: Field = .investment

    private enum Field {
        case investment
        case shares
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            BacktestDecimalField(
                label: "Investment",
                placeholder: "10,000",
                prefix: "$",
                value: $investmentUsd,
                allowsEmpty: true,
                fractionDigits: 0,
                onCommit: { value in
                    lastEdited = .investment
                    guard let startSharePrice, startSharePrice > 0 else { return }
                    if value > 0 {
                        let synced = DividendBacktestSupport.syncFromInvestment(value, startSharePrice: startSharePrice)
                        investmentUsd = synced.investmentUsd
                        shares = synced.shares
                    } else {
                        shares = 0
                    }
                }
            )
            BacktestDecimalField(
                label: "Shares",
                placeholder: "100",
                suffix: "sh",
                value: $shares,
                allowsEmpty: true,
                fractionDigits: 2,
                onCommit: { value in
                    lastEdited = .shares
                    guard let startSharePrice, startSharePrice > 0 else { return }
                    if value > 0 {
                        let synced = DividendBacktestSupport.syncFromShares(value, startSharePrice: startSharePrice)
                        investmentUsd = synced.investmentUsd
                        shares = synced.shares
                    } else {
                        investmentUsd = 0
                    }
                }
            )
        }
        .onChange(of: startSharePrice) { _, _ in
            switch lastEdited {
            case .investment:
                guard investmentUsd > 0 else { return }
                let synced = DividendBacktestSupport.syncFromInvestment(investmentUsd, startSharePrice: startSharePrice)
                investmentUsd = synced.investmentUsd
                shares = synced.shares
            case .shares:
                guard shares > 0 else { return }
                let synced = DividendBacktestSupport.syncFromShares(shares, startSharePrice: startSharePrice)
                investmentUsd = synced.investmentUsd
                shares = synced.shares
            }
        }
    }
}

private struct DividendBacktestResultsPanel: View {
    let backtest: DividendHistoricalBacktest
    let context: DividendHistoryContext
    let query: DividendBacktestQuery

    private var endYearIncome: Double? {
        if let drip = backtest.drip {
            return drip.annualIncomeLatestDrip
        }
        return backtest.yearlyBreakdown.last?.dividendIncome
    }

    private var windowLabel: String {
        let years = backtest.endYear - backtest.startYear + 1
        return "\(backtest.startYear) → \(backtest.endYear) · \(years) \(years == 1 ? "year" : "years")"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Results")
                        .font(.headline)
                        .foregroundStyle(AppColors.label)
                    Text(windowLabel)
                        .font(AppTypography.monoCaption)
                        .foregroundStyle(AppColors.secondaryLabel)
                    Text(query.reinvestDividends ? "DRIP on" : "DRIP off")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.accentHighlight)
                }
                Spacer(minLength: 0)
                PdfShareButton(
                    title: "PDF",
                    url: PdfExportSupport.writeDividendBacktestPdf(
                        symbol: context.ticker,
                        context: context,
                        query: query
                    )
                )
            }

            HStack(alignment: .top, spacing: 10) {
                DividendBacktestHeroMetric(
                    title: "Total dividend income",
                    value: CurrencyFormatter.usd(backtest.cashCollected, fractionDigits: 0),
                    footnote: query.reinvestDividends
                        ? "All dividend cash over the window with DRIP"
                        : "Sum of calendar-year dividend income"
                )
                DividendBacktestHeroMetric(
                    title: "Annual income · \(backtest.endYear)",
                    value: endYearIncome.map { CurrencyFormatter.usd($0, fractionDigits: 0) } ?? "—",
                    footnote: endYearIncomeFootnote
                )
            }

            if let drip = backtest.drip {
                AppMetricPanel(items: dripMetricItems(drip)) {
                    Text("With DRIP")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .textCase(.uppercase)
                }
            }

            if !backtest.yearlyBreakdown.isEmpty {
                AppScreenSection(title: "Annual income", footnote: "Tap or drag bars to inspect a year") {
                    InteractiveDividendBacktestYearChart(rows: backtest.yearlyBreakdown)
                        .appPanel(subtle: true)
                }

                AppScreenSection(title: "Year-by-year", footnote: "\(backtest.yearlyBreakdown.count) years") {
                    DividendBacktestYearTable(
                        rows: backtest.yearlyBreakdown,
                        usesDrip: query.reinvestDividends,
                        usesHistoricalPrices: backtest.drip?.usesHistoricalSharePrices == true
                    )
                }
            }

            Text(methodologyNote)
                .font(.caption2)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.insetSurface)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColors.separator, lineWidth: 1)
                }
        }
    }

    private var endYearIncomeFootnote: String {
        if query.reinvestDividends, let drip = backtest.drip {
            let dps = backtest.yearlyBreakdown.last?.dps ?? 0
            return "\(String(format: "%.2f", drip.finalShares)) sh × \(String(format: "$%.4f", dps)) DPS"
        }
        let shares = backtest.initialShares ?? query.shares
        let dps = backtest.yearlyBreakdown.last?.dps ?? 0
        return "\(String(format: "%.2f", shares)) sh × \(String(format: "$%.4f", dps)) DPS"
    }

    private func dripMetricItems(_ drip: DividendAdvancedSnowballScenario) -> [(label: String, value: String)] {
        [
            ("Portfolio", CurrencyFormatter.usd(drip.portfolioValueLatest, fractionDigits: 0)),
            ("Shares", String(format: "%.2f", drip.finalShares)),
            ("Reinvested", CurrencyFormatter.usd(drip.totalDividendsReinvested, fractionDigits: 0)),
        ]
    }

    private var methodologyNote: String {
        var parts: [String] = [
            "Backtest replays recorded dividends from \(backtest.startYear) through \(backtest.endYear)."
        ]
        if query.annualContributionUsd > 0 {
            parts.append(
                "Includes \(CurrencyFormatter.usd(query.annualContributionUsd, fractionDigits: 0)) of new cash at the start of each year."
            )
        }
        if query.reinvestDividends, let drip = backtest.drip {
            if drip.usesHistoricalSharePrices == true {
                parts.append("DRIP reinvests at each year's actual year-end close.")
            } else {
                parts.append("DRIP assumes \(String(format: "%.1f", drip.priceCagrPct))% annual price growth at modeled year-end prices.")
            }
        } else if query.reinvestDividends {
            parts.append("DRIP is enabled in your settings but share-price modeling was unavailable.")
        } else {
            parts.append("DRIP is off — totals exclude reinvestment.")
        }
        parts.append("Past dividends do not guarantee future payouts.")
        return parts.joined(separator: " ")
    }
}

private struct DividendBacktestHeroMetric: View {
    let title: String
    let value: String
    let footnote: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            Text(value)
                .font(AppTypography.monoTitle3)
                .foregroundStyle(AppColors.label)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(footnote)
                .font(.caption2)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(AppColors.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }
}

private struct DividendBacktestYearTable: View {
    let rows: [DividendBacktestYearRow]
    let usesDrip: Bool
    let usesHistoricalPrices: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                tableHeader("Year", width: 44, alignment: .leading)
                tableHeader("DPS", alignment: .trailing)
                tableHeader("Shares", alignment: .trailing)
                tableHeader("Income", alignment: .trailing)
                tableHeader("Yield", width: 52, alignment: .trailing)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.surfaceElevated.opacity(0.55))

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 8) {
                    Text(String(row.year))
                        .font(AppTypography.monoCaptionSemibold)
                        .frame(width: 44, alignment: .leading)
                    Text(String(format: "$%.4f", row.dps))
                        .font(AppTypography.monoCaption2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(String(format: "%.2f", row.shares))
                        .font(AppTypography.monoCaption2)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(CurrencyFormatter.usd(row.dividendIncome, fractionDigits: 0))
                        .font(AppTypography.monoCaptionSemibold)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    Text(String(format: "%.2f%%", row.dividendYieldPct))
                        .font(AppTypography.monoCaption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .frame(width: 52, alignment: .trailing)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .foregroundStyle(AppColors.label)

                if index < rows.count - 1 {
                    Divider().overlay(AppColors.separator).padding(.leading, 12)
                }
            }

            Text(tableFootnote)
                .font(.caption2)
                .foregroundStyle(AppColors.tertiaryLabel)
                .lineSpacing(2)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.insetSurface.opacity(0.65))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }

    private var tableFootnote: String {
        if usesDrip {
            return usesHistoricalPrices
                ? "Annual income is DPS × shares at year-end after contributions and DRIP. Yield uses that year's actual close."
                : "Annual income is DPS × shares at year-end after contributions and DRIP. Yield uses annual DPS ÷ modeled share price."
        }
        return "Annual income is calendar-year DPS × your starting share count. Yield uses annual DPS ÷ share price that year."
    }

    private func tableHeader(
        _ title: String,
        width: CGFloat? = nil,
        alignment: Alignment = .center
    ) -> some View {
        Group {
            if let width {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)
                    .frame(width: width, alignment: alignment)
            } else {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: alignment)
            }
        }
    }
}
