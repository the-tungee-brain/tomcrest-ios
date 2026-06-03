import SwiftUI

struct FinancialStrengthCard: View {
    let strength: FinancialStrength

    private var verdictText: String {
        let v = strength.financialVerdict.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = v.isEmpty ? strength.scoreExplanation : v
        guard let first = raw.first else { return raw }
        return String(first).uppercased() + raw.dropFirst()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(strength.profile)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentHighlight)
                Spacer()
                Text("Health \(strength.score)/100")
                    .font(AppTypography.caption.monospacedDigit())
                    .foregroundStyle(AppColors.secondaryLabel)
            }

            if !strength.businessContext.isEmpty {
                Text(strength.businessContext)
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }

            if !verdictText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Financial verdict")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.tertiaryLabel)
                        .textCase(.uppercase)
                    Text(verdictText)
                        .font(AppTypography.bodySecondary)
                        .foregroundStyle(AppColors.label)
                        .lineSpacing(3)
                }
            }

            if !strength.headline.isEmpty {
                Text(strength.headline)
                    .font(.caption2)
                    .foregroundStyle(AppColors.tertiaryLabel)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Score drivers")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.tertiaryLabel)
                    .textCase(.uppercase)

                breakdownRow("Growth (30%)", strength.scoreBreakdown.growth)
                breakdownRow("Profitability (30%)", strength.scoreBreakdown.profitability)
                breakdownRow("Cash flow (25%)", strength.scoreBreakdown.cashFlow)
                breakdownRow("Balance sheet (15%)", strength.scoreBreakdown.balanceSheet)
            }
        }
        .appPanel(subtle: true)
    }

    @ViewBuilder
    private func breakdownRow(_ label: String, _ row: FinancialCategoryScore) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(AppColors.secondaryLabel)
                Spacer()
                Text("\(row.score)/100 · \(row.rankLabel)")
                    .font(AppTypography.monoCaption2)
                    .foregroundStyle(AppColors.label)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(AppColors.secondaryBackground.opacity(0.8))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(AppColors.accentHighlight.opacity(0.85))
                        .frame(width: geometry.size.width * CGFloat(row.score) / 100)
                }
            }
            .frame(height: 6)
        }
    }
}
