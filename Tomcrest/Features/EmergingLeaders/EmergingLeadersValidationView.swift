import SwiftUI

struct EmergingLeadersValidationView: View {
    @Bindable var viewModel: EmergingLeadersValidationViewModel

    var body: some View {
        AppScreenSection(
            title: "Validation",
            footnote: viewModel.payload?.methodology
        ) {
            if viewModel.isLoading, viewModel.payload == nil {
                ProgressView("Loading validation…")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if let errorMessage = viewModel.errorMessage, viewModel.payload == nil {
                AppInlineBanner(message: errorMessage, tone: .error)
            } else if let payload = viewModel.payload {
                validationContent(payload)
            }
        }
    }

    @ViewBuilder
    private func validationContent(_ payload: EmergingLeadersValidationResponse) -> some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            summaryRow(payload)

            if payload.labeledRows == 0 {
                AppEmptyMessage(
                    message: "No labeled snapshots yet. Runs with the nightly ranking pipeline.",
                    systemImage: "chart.bar.doc.horizontal"
                )
            } else {
                topDecileCard(payload.topDecile)
                bucketSection(title: "By setup score", buckets: payload.setupScoreBuckets)
                bucketSection(title: "By compression velocity", buckets: payload.compressionVelocityBuckets)
                bucketSection(title: "By stage", buckets: payload.stageBuckets)
            }
        }
    }

    private func summaryRow(_ payload: EmergingLeadersValidationResponse) -> some View {
        HStack(spacing: 8) {
            ValidationStatChip(label: "Days", value: "\(payload.snapshotDates)")
            ValidationStatChip(label: "Snapshots", value: "\(payload.snapshotRows)")
            ValidationStatChip(label: "Labeled", value: "\(payload.labeledRows)")
        }
    }

    private func topDecileCard(_ metrics: ValidationBucketMetrics) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MoversSectionTitle(title: "TOP DECILE (SETUP SCORE)")
            ValidationBucketCard(metrics: metrics, emphasize: true)
        }
    }

    private func bucketSection(title: String, buckets: [ValidationBucketMetrics]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MoversSectionTitle(title: title.uppercased())
            VStack(spacing: 8) {
                ForEach(buckets.filter { $0.count > 0 }) { bucket in
                    ValidationBucketCard(metrics: bucket, emphasize: false)
                }
            }
        }
    }
}

private struct ValidationStatChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Token.textTertiary)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Token.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Token.surfaceFillSecondary.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct ValidationBucketCard: View {
    let metrics: ValidationBucketMetrics
    let emphasize: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(metrics.bucket)
                    .font(emphasize ? .subheadline.weight(.semibold) : .subheadline)
                    .foregroundStyle(Token.textPrimary)
                Spacer()
                Text("n=\(metrics.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Token.textTertiary)
            }

            ValidationMetricsGrid(metrics: metrics)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            emphasize
                ? AppColors.accentMuted.opacity(0.35)
                : Token.surfaceFillSecondary.opacity(0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ValidationMetricsGrid: View {
    let metrics: ValidationBucketMetrics

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            metricCell("5D excess", EmergingLeadersValidationFormatting.rate(metrics.avgExcess5D))
            metricCell("10D excess", EmergingLeadersValidationFormatting.rate(metrics.avgExcess10D))
            metricCell("20D excess", EmergingLeadersValidationFormatting.rate(metrics.avgExcess20D))
            metricCell("5D hit", EmergingLeadersValidationFormatting.hitRate(metrics.hitRate5D))
            metricCell("10D hit", EmergingLeadersValidationFormatting.hitRate(metrics.hitRate10D))
            metricCell("20D hit", EmergingLeadersValidationFormatting.hitRate(metrics.hitRate20D))
        }
    }

    private func metricCell(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Token.textTertiary)
            Text(value)
                .font(.caption.weight(.semibold).monospacedDigit())
                .foregroundStyle(Token.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

enum EmergingLeadersValidationFormatting {
    /// API returns decimal fractions (e.g. 0.04 → 4%).
    static func rate(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%+.1f%%", value * 100)
    }

    static func hitRate(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f%%", value * 100)
    }
}
