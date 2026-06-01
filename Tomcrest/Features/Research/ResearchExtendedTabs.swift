import SwiftUI

struct SymbolFinancialsTab: View {
    @Environment(AccountContext.self) private var account
    let viewModel: SymbolDepthViewModel

    @State private var useQuarterly = false

    var body: some View {
        ResearchDepthTabShell(tab: .financials, viewModel: viewModel) {
            if let block = viewModel.fundamentals {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    if account.hasProFeature(.financialStrength), let strength = block.strength {
                        AppScreenSection(title: "Financial strength", footnote: strength.rating.capitalized) {
                            FinancialStrengthCard(strength: strength)
                        }
                    } else if block.strength == nil {
                        AppInlineBanner(
                            message: "Upgrade to Pro for AI financial strength analysis.",
                            tone: .neutral
                        )
                    }

                    let snapshot = useQuarterly ? block.quarterlyFinancials : block.annualFinancials
                    if let snapshot {
                        AppScreenSection(
                            title: "Statements",
                            footnote: useQuarterly ? "Quarterly" : "Annual"
                        ) {
                            Picker("Period", selection: $useQuarterly) {
                                Text("Annual").tag(false)
                                Text("Quarterly").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .padding(.bottom, 8)

                            FinancialStatementsSection(snapshot: snapshot)
                        }
                    }

                    if !block.metrics.isEmpty {
                        AppScreenSection(title: "Key metrics") {
                            GroupedKeyMetricsSection(metrics: block.metrics)
                        }
                    }

                    AppScreenSection(title: "SEC filings") {
                        SecFilingsSectionView(filings: viewModel.secFilings)
                    }

                    AppScreenSection(title: "Financial trends (SEC)") {
                        SecFinancialTrendSectionView(financials: viewModel.secFinancials)
                    }

                    AppScreenSection(title: "Ratios (SEC)") {
                        SecRatiosSectionView(ratios: viewModel.secRatios)
                    }
                }
            }
        }
    }
}

struct FinancialStrengthCard: View {
    let strength: FinancialStrength

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(strength.headline)
                .font(AppTypography.cardTitle)
                .foregroundStyle(AppColors.label)
            Text("Score \(strength.score)/100")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)
            if !strength.strengths.isEmpty {
                ForEach(strength.strengths.prefix(3), id: \.self) { item in
                    Text("• \(item)")
                        .font(.caption)
                        .foregroundStyle(AppColors.label)
                }
            }
            if !strength.risks.isEmpty {
                ForEach(strength.risks.prefix(3), id: \.self) { item in
                    Text("• \(item)")
                        .font(.caption)
                        .foregroundStyle(AppColors.warning)
                }
            }
        }
        .appPanel(subtle: true)
    }
}

struct FinancialStatementsSection: View {
    let snapshot: FinancialStatementsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            statementBlock("Income statement", snapshot.incomeStatement)
            statementBlock("Balance sheet", snapshot.balanceSheet)
            statementBlock("Cash flow", snapshot.cashFlow)
        }
    }

    @ViewBuilder
    private func statementBlock(_ title: String, _ items: [FinancialLineItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)
                ForEach(items.prefix(6)) { item in
                    HStack {
                        Text(item.label)
                            .font(.caption)
                            .foregroundStyle(AppColors.secondaryLabel)
                        Spacer()
                        if let latest = latestValue(item) {
                            Text(CurrencyFormatter.compactUSD(latest))
                                .font(AppTypography.monoCaption)
                                .foregroundStyle(AppColors.label)
                        }
                    }
                }
            }
            .padding(12)
            .background(AppColors.secondaryBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func latestValue(_ item: FinancialLineItem) -> Double? {
        for period in snapshot.periods {
            if let value = item.values[period] { return value }
        }
        return item.values.values.first
    }
}

struct SymbolCompositionTab: View {
    let viewModel: SymbolDepthViewModel

    var body: some View {
        ResearchDepthTabShell(tab: .composition, viewModel: viewModel) {
            if let holdings = viewModel.etfHoldings {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    AppScreenSection(title: "Fund overview") {
                        AppMetricStrip(items: [
                            ("Holdings", "\(holdings.totalHoldings)"),
                            ("AUM", holdings.aum ?? "—"),
                            ("Yield", holdings.dividendYield ?? "—"),
                            ("Expense", holdings.expenseRatio ?? "—"),
                        ])
                        .appPanel(subtle: true)
                    }

                    if !holdings.sectorBreakdown.isEmpty {
                        AppScreenSection(title: "Sector breakdown") {
                            VStack(spacing: 8) {
                                ForEach(holdings.sectorBreakdown.sorted(by: { $0.value > $1.value }).prefix(8), id: \.key) { sector, weight in
                                    HStack {
                                        Text(PortfolioBriefText.formatSectorLabel(sector))
                                            .font(.caption)
                                        Spacer()
                                        Text(CurrencyFormatter.compactPercent(weight))
                                            .font(AppTypography.monoCaption)
                                    }
                                }
                            }
                        }
                    }

                    if !holdings.holdings.isEmpty {
                        AppScreenSection(title: "Top holdings") {
                            etfHoldingsList(holdings.holdings)
                        }
                    }

                    if !holdings.strongestHoldings.isEmpty {
                        AppScreenSection(title: "Strongest holdings", footnote: "Piotroski / Altman") {
                            etfHoldingsList(holdings.strongestHoldings)
                        }
                    }

                    if !holdings.weakestHoldings.isEmpty {
                        AppScreenSection(title: "Weakest holdings") {
                            etfHoldingsList(holdings.weakestHoldings)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func etfHoldingsList(_ items: [EtfHoldingItem]) -> some View {
        AppGroupedList {
            ForEach(Array(items.prefix(12).enumerated()), id: \.element.id) { index, item in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.ticker ?? "—")
                            .font(AppTypography.monoCaptionSemibold)
                        Spacer()
                        Text(CurrencyFormatter.compactPercent(item.weightPct))
                            .font(AppTypography.monoCaption)
                    }
                    Text(item.name)
                        .font(.caption2)
                        .foregroundStyle(AppColors.secondaryLabel)
                        .lineLimit(2)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                if index < min(items.count, 12) - 1 {
                    AppGroupedDivider()
                }
            }
        }
    }
}

struct DividendSnowballCard: View {
    @Environment(AccountContext.self) private var account
    let context: DividendHistoryContext
    @Bindable var viewModel: SymbolDepthViewModel

    @State private var projectYears = 10.0
    @State private var reinvest = true
    @State private var annualContribution = 0.0

    var body: some View {
        if account.hasProFeature(.dividendSnowball) {
            AppScreenSection(title: "Income snowball", footnote: "Pro projection") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Reinvest dividends (DRIP)", isOn: $reinvest)
                        .font(.caption)
                    HStack {
                        Text("Horizon")
                            .font(.caption)
                        Slider(value: $projectYears, in: 5 ... 30, step: 1)
                        Text("\(Int(projectYears))y")
                            .font(AppTypography.monoCaption)
                    }
                    HStack {
                        Text("Annual contribution")
                            .font(.caption)
                        Spacer()
                        Text(CurrencyFormatter.usd(annualContribution, fractionDigits: 0))
                            .font(AppTypography.monoCaption)
                    }
                    Slider(value: $annualContribution, in: 0 ... 50_000, step: 500)

                    if let scenario = context.scenario {
                        snowballMetrics(scenario)
                    }

                    Button("Apply scenario") {
                        Task {
                            await viewModel.loadDividendSnowball(
                                projectYears: Int(projectYears),
                                reinvestDividends: reinvest,
                                annualContributionUsd: annualContribution
                            )
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                    .buttonStyle(.plain)

                    PdfShareButton(
                        title: "Download PDF",
                        url: PdfExportSupport.writeDividendSnowballPdf(
                            symbol: context.ticker,
                            context: context,
                            projectYears: Int(projectYears),
                            reinvest: reinvest
                        )
                    )
                }
                .appPanel(subtle: true)
            }
        }
    }

    @ViewBuilder
    private func snowballMetrics(_ scenario: DividendSnowballScenario) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            snowballChip("Latest income", CurrencyFormatter.usd(scenario.annualIncomeLatest, fractionDigits: 0))
            snowballChip("Start income", CurrencyFormatter.usd(scenario.annualIncomeStart, fractionDigits: 0))
            snowballChip("Total collected", CurrencyFormatter.usd(scenario.totalCollected, fractionDigits: 0))
            if let advanced = scenario.advanced {
                snowballChip("Portfolio value", CurrencyFormatter.usd(advanced.portfolioValueLatest, fractionDigits: 0))
            }
        }
    }

    private func snowballChip(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            Text(value)
                .font(AppTypography.monoCaptionSemibold)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private extension CurrencyFormatter {
    static func compactUSD(_ value: Double) -> String {
        if abs(value) >= 1_000_000_000 {
            return String(format: "$%.1fB", value / 1_000_000_000)
        }
        if abs(value) >= 1_000_000 {
            return String(format: "$%.1fM", value / 1_000_000)
        }
        if abs(value) >= 1_000 {
            return String(format: "$%.0fK", value / 1_000)
        }
        return usd(value, fractionDigits: 0)
    }
}
