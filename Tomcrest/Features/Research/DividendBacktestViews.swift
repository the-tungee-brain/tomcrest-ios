import SwiftUI

struct DividendBacktestSection: View {
    @Environment(AccountContext.self) private var account
    let context: DividendHistoryContext
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
                        query: $viewModel.dividendBacktestQuery,
                        completedYears: completedYears,
                        isLoading: viewModel.dividendBacktestLoading,
                        onRun: runBacktest
                    )

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
            await viewModel.loadDividendBacktest(historyStartYear: startYear)
        }
    }
}

private struct DividendBacktestControlsPanel: View {
    @Binding var query: DividendBacktestQuery
    let completedYears: [Int]
    let isLoading: Bool
    let onRun: () -> Void

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
                    Text("Enter investment or shares — we'll use both when you provide them.")
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineSpacing(2)

                    HStack(alignment: .top, spacing: 10) {
                        BacktestDecimalField(
                            label: "Investment",
                            placeholder: "10,000",
                            prefix: "$",
                            value: $query.investmentUsd,
                            allowsEmpty: true,
                            fractionDigits: 0
                        )
                        BacktestDecimalField(
                            label: "Shares",
                            placeholder: "100",
                            suffix: "sh",
                            value: $query.shares,
                            fractionDigits: 2
                        )
                    }

                    BacktestDecimalField(
                        label: "Annual contribution",
                        placeholder: "0",
                        prefix: "$",
                        value: $query.annualContributionUsd,
                        allowsEmpty: true,
                        fractionDigits: 0
                    )

                    Toggle("Reinvest dividends (DRIP)", isOn: $query.reinvestDividends)
                        .font(.caption)
                        .tint(AppColors.accentHighlight)
                }
            }

            BacktestControlsShell(title: "History window") {
                VStack(alignment: .leading, spacing: 10) {
                    Text(windowLabel)
                        .font(.caption.monospacedDigit())
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
                }
            }

            BacktestRunButton(isLoading: isLoading, action: onRun)
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

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                backtestMetric(
                    title: "Total dividend income",
                    value: CurrencyFormatter.usd(backtest.cashCollected, fractionDigits: 0),
                    footnote: query.reinvestDividends
                        ? "All dividend cash over the window with DRIP"
                        : "Sum of calendar-year dividend income"
                )
                backtestMetric(
                    title: "Annual income · \(backtest.endYear)",
                    value: endYearIncome.map { CurrencyFormatter.usd($0, fractionDigits: 0) } ?? "—",
                    footnote: query.reinvestDividends ? "After DRIP at year-end" : "Starting share count × DPS"
                )
            }

            if let drip = backtest.drip {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    backtestMetric(
                        title: "Portfolio value",
                        value: CurrencyFormatter.usd(drip.portfolioValueLatest, fractionDigits: 0),
                        footnote: drip.usesHistoricalSharePrices == true ? "Actual year-end prices" : "Modeled prices"
                    )
                    backtestMetric(
                        title: "Shares after DRIP",
                        value: String(format: "%.2f", drip.finalShares),
                        footnote: "Started with \(String(format: "%.2f", drip.initialShares))"
                    )
                    backtestMetric(
                        title: "Reinvested",
                        value: CurrencyFormatter.usd(drip.totalDividendsReinvested, fractionDigits: 0),
                        footnote: drip.totalAnnualContributionsUsd > 0
                            ? "\(CurrencyFormatter.usd(drip.totalAnnualContributionsUsd, fractionDigits: 0)) new cash"
                            : "Dividend cash reinvested"
                    )
                }
            }

            if !backtest.yearlyBreakdown.isEmpty {
                AppScreenSection(title: "Year-by-year", footnote: "\(backtest.yearlyBreakdown.count) years") {
                    AppGroupedList {
                        ForEach(Array(backtest.yearlyBreakdown.enumerated()), id: \.element.id) { index, row in
                            HStack(alignment: .top, spacing: 8) {
                                Text(String(row.year))
                                    .font(.caption.weight(.semibold))
                                    .frame(width: 40, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("DPS \(String(format: "$%.4f", row.dps)) · \(String(format: "%.2f", row.shares)) sh")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(AppColors.secondaryLabel)
                                    Text(CurrencyFormatter.usd(row.dividendIncome, fractionDigits: 0))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppColors.label)
                                }
                                Spacer(minLength: 0)
                                Text(String(format: "%.2f%%", row.dividendYieldPct))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(AppColors.tertiaryLabel)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            if index < backtest.yearlyBreakdown.count - 1 {
                                AppGroupedDivider()
                            }
                        }
                    }
                }
            }

            PdfShareButton(
                title: "Download PDF",
                url: PdfExportSupport.writeDividendBacktestPdf(
                    symbol: context.ticker,
                    context: context,
                    query: query
                )
            )
        }
    }

    private func backtestMetric(title: String, value: String, footnote: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            Text(value)
                .font(.body.weight(.semibold).monospacedDigit())
                .foregroundStyle(AppColors.label)
            Text(footnote)
                .font(.caption2)
                .foregroundStyle(AppColors.secondaryLabel)
                .lineSpacing(2)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
