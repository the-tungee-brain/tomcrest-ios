import SwiftUI

// MARK: - Grouped holdings

struct SymbolHoldingSummary: Identifiable {
    let symbol: String
    let marketValue: Double
    let openProfitLoss: Double
    let dayProfitLoss: Double
    let weightPct: Double
    let alertCount: Int

    var id: String { symbol }
}

enum PortfolioHoldingsSupport {
    static func buildSummaries(
        positions: [Position],
        alerts: [ProactiveAlert]
    ) -> [SymbolHoldingSummary] {
        let alertsBySymbol = Dictionary(grouping: alerts.compactMap { alert -> (String, ProactiveAlert)? in
            guard let symbol = alert.symbol?.uppercased(), !symbol.isEmpty else { return nil }
            return (symbol, alert)
        }) { $0.0 }

        var grouped: [String: (value: Double, openPL: Double, dayPL: Double, weight: Double)] = [:]

        for position in positions {
            let symbol = position.displaySymbol.uppercased()
            var entry = grouped[symbol] ?? (0, 0, 0, 0)
            entry.value += position.marketValue
            entry.openPL += position.openProfitLoss ?? 0
            entry.dayPL += position.currentDayProfitLoss
            entry.weight += position.portfolioWeightPct ?? 0
            grouped[symbol] = entry
        }

        return grouped.map { symbol, totals in
            SymbolHoldingSummary(
                symbol: symbol,
                marketValue: totals.value,
                openProfitLoss: totals.openPL,
                dayProfitLoss: totals.dayPL,
                weightPct: totals.weight,
                alertCount: alertsBySymbol[symbol]?.count ?? 0
            )
        }
        .sorted { $0.weightPct > $1.weightPct }
    }
}

enum PortfolioHoldingsSort: String, CaseIterable, Identifiable {
    case weight
    case value
    case openPL
    case dayPL
    case alerts

    var id: String { rawValue }

    var label: String {
        switch self {
        case .weight: "Weight"
        case .value: "Value"
        case .openPL: "Open P/L"
        case .dayPL: "Today"
        case .alerts: "Alerts"
        }
    }
}

struct PortfolioHoldingsTable: View {
    let summaries: [SymbolHoldingSummary]
    let alerts: [ProactiveAlert]
    var onSymbolTap: ((String) -> Void)?

    @State private var sort: PortfolioHoldingsSort = .weight
    @State private var alertsOnly = false

    private var displayed: [SymbolHoldingSummary] {
        var rows = summaries
        if alertsOnly {
            rows = rows.filter { $0.alertCount > 0 }
        }
        switch sort {
        case .weight: rows.sort { $0.weightPct > $1.weightPct }
        case .value: rows.sort { $0.marketValue > $1.marketValue }
        case .openPL: rows.sort { $0.openProfitLoss > $1.openProfitLoss }
        case .dayPL: rows.sort { $0.dayProfitLoss > $1.dayProfitLoss }
        case .alerts: rows.sort { $0.alertCount > $1.alertCount }
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(PortfolioHoldingsSort.allCases) { option in
                        Button {
                            sort = option
                        } label: {
                            Text(option.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(sort == option ? Token.onPrimary : Token.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(sort == option ? Token.primary : Token.surfaceFillSecondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        alertsOnly.toggle()
                    } label: {
                        Text("Alerts only")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(alertsOnly ? Token.onPrimary : Token.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(alertsOnly ? Token.primary : Token.surfaceFillSecondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }

            if displayed.isEmpty {
                AppEmptyMessage(message: "No holdings match this filter.")
            } else {
                AppGroupedList {
                    ForEach(Array(displayed.enumerated()), id: \.element.id) { index, summary in
                        Button {
                            onSymbolTap?(summary.symbol)
                        } label: {
                            PortfolioHoldingsRow(summary: summary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(onSymbolTap == nil)

                        if index < displayed.count - 1 {
                            AppGroupedDivider()
                        }
                    }
                }
            }
        }
    }
}

private struct PortfolioHoldingsRow: View {
    let summary: SymbolHoldingSummary

    var body: some View {
        AppListRow {
            HStack(spacing: 12) {
                SymbolAvatar(symbol: summary.symbol, size: 36)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(summary.symbol)
                            .font(AppTypography.cardTitle)
                            .foregroundStyle(AppColors.label)
                        if summary.alertCount > 0 {
                            Text("\(summary.alertCount)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppColors.onAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppColors.warning)
                                .clipShape(Capsule())
                        }
                    }
                    Text(CurrencyFormatter.usd(summary.marketValue, fractionDigits: 0))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
            }
        } trailing: {
            VStack(alignment: .trailing, spacing: 3) {
                Text(CurrencyFormatter.compactPercent(summary.weightPct))
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(AppColors.secondaryLabel)
                Text(CurrencyFormatter.signedUsd(summary.openProfitLoss))
                    .font(AppTypography.captionEmphasis)
                    .foregroundStyle(profitTone(summary.openProfitLoss))
                Text(CurrencyFormatter.signedUsd(summary.dayProfitLoss))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(profitTone(summary.dayProfitLoss))
            }
        }
    }

    private func profitTone(_ value: Double) -> Color {
        if value > 0 { return AppColors.success }
        if value < 0 { return AppColors.error }
        return AppColors.secondaryLabel
    }
}

// MARK: - Options risk

struct PortfolioRiskSection: View {
    let cashSecuredPutSummary: CashSecuredPutSummary?
    let assignmentRiskSummary: AssignmentRiskSummary?
    let cashBalance: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let csp = cashSecuredPutSummary, csp.totalReservedCash > 0 {
                CashSecuredPutSummaryCard(summary: csp, cashBalance: cashBalance)
            }
            if let assignment = assignmentRiskSummary, OptionsRiskHelpers.hasAssignmentRisk(assignment) {
                AssignmentRiskSummaryCard(summary: assignment)
            }
        }
    }
}

struct CashSecuredPutSummaryCard: View {
    let summary: CashSecuredPutSummary
    let cashBalance: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Cash-secured puts", systemImage: "lock.circle.fill")
                .font(AppTypography.bodySecondary.weight(.semibold))
                .foregroundStyle(AppColors.label)

            HStack(spacing: 12) {
                riskMetric("Reserved", CurrencyFormatter.usd(summary.totalReservedCash, fractionDigits: 0))
                if let available = summary.availableCashAfterReserves ?? cashBalance.map({ max($0 - summary.totalReservedCash, 0) }) {
                    riskMetric("Available", CurrencyFormatter.usd(available, fractionDigits: 0))
                }
            }

            if !summary.positions.isEmpty {
                VStack(spacing: 6) {
                    ForEach(summary.positions.prefix(5)) { position in
                        HStack {
                            Text(position.underlyingSymbol ?? position.symbol)
                                .font(.caption.weight(.semibold).monospaced())
                            Spacer()
                            Text(CurrencyFormatter.usd(position.reservedCash, fractionDigits: 0))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AppColors.secondaryLabel)
                        }
                    }
                }
            }
        }
        .appPanel(subtle: true)
    }

    private func riskMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
                .textCase(.uppercase)
            Text(value)
                .font(AppTypography.cardTitle)
                .foregroundStyle(AppColors.label)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AssignmentRiskSummaryCard: View {
    let summary: AssignmentRiskSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Assignment risk", systemImage: "exclamationmark.triangle.fill")
                .font(AppTypography.bodySecondary.weight(.semibold))
                .foregroundStyle(AppColors.warning)

            if let withinDays = summary.withinDays {
                Text("Expiring within \(withinDays) days")
                    .font(.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            VStack(spacing: 8) {
                ForEach(summary.positions.prefix(6)) { position in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(position.underlyingSymbol ?? position.symbol)
                                .font(.caption.weight(.semibold).monospaced())
                            Spacer()
                            Text(position.riskLevel?.capitalized ?? "Watch")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(riskColor(position.riskLevel))
                        }
                        Text("\(position.putCall ?? "OPT") · \(position.daysToExpiration ?? 0)d · strike \(CurrencyFormatter.usd(position.strike ?? 0))")
                            .font(.caption2)
                            .foregroundStyle(AppColors.secondaryLabel)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.secondaryBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
        .appPanel(subtle: true)
    }

    private func riskColor(_ level: String?) -> Color {
        switch level?.lowercased() {
        case "critical", "high": AppColors.error
        case "moderate": AppColors.warning
        default: AppColors.secondaryLabel
        }
    }
}
