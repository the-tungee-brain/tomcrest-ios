// MARK: - Shared settings cards (used by detail screens)

import SwiftUI

struct SettingsFieldLabel: View {
    let title: String

    var body: some View {
        Text(title)
            .font(AppTypography.captionEmphasis)
            .foregroundStyle(AppColors.secondaryLabel)
    }
}

// MARK: - Brokerage

struct SchwabConnectionCard: View {
    let connected: Bool?
    let isLoading: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                Text("Schwab")
                    .font(AppTypography.sectionTitle)
                    .foregroundStyle(AppColors.label)
                Spacer(minLength: 12)
                if isLoading {
                    ProgressView().controlSize(.small).tint(AppColors.accent)
                }
                AppStatusPill(label: statusLabel, uppercase: false, tone: statusTone)
            }

            Text("Read-only access — view positions, no trades.")
                .font(AppTypography.caption)
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            // One primary action — pull to refresh on Settings replaces a third button.
            if connected == true {
                Button("Disconnect Schwab", role: .destructive, action: onDisconnect)
                    .buttonStyle(AppPrimaryButtonStyle(destructive: true))
                    .disabled(isLoading)
            } else {
                Button("Connect Schwab", action: onConnect)
                    .buttonStyle(AppSecondaryButtonStyle())
                    .disabled(isLoading)
            }
        }
        .appPanel(subtle: true)
    }

    private var statusLabel: String {
        if isLoading, connected == nil { return "Checking…" }
        if let connected { return connected ? "Connected" : "Not connected" }
        return "Unknown"
    }

    private var statusTone: AppStatusPill.Tone {
        guard let connected else { return .neutral }
        return connected ? .success : .neutral
    }
}

// MARK: - Account identity

struct AccountIdentityRow: View {
    let email: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.crop.circle.fill")
                .font(.title2)
                .foregroundStyle(AppColors.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(email)
                    .font(AppTypography.cardTitle)
                    .foregroundStyle(AppColors.label)
                    .textSelection(.enabled)
                Text("Signed in with Google")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColors.secondaryLabel)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(subtle: true)
    }
}

// MARK: - Plan

struct AccountPlanCardView: View {
    let plan: AccountPlanResponse?
    let isLoading: Bool

    @State private var featuresExpanded = false

    private static let freeFeatures = [
        "Portfolio sync, morning brief, and strategy playbooks",
        "Portfolio and position analysis with AI-powered insights",
        "Research essentials: quotes, SEC filings, earnings history, news headlines",
        "Dividend history charts and allocation tools",
        "Assistant chat on free-tier AI models",
    ]

    private static let proFeatures = [
        "Most capable AI model for research synthesis and portfolio analysis",
        "AI earnings analysis (quarterly summaries & takeaways)",
        "AI news research (brief, sentiment, coverage analysis)",
        "Financial strength & fundamental AI on Research",
        "Big picture & business AI on Research Overview and Business",
        "5-day pattern trend forecast on Research",
        "Income snowball (DRIP projections & contributions)",
        "Wheel backtest with trade log and PDF export",
        "Advanced chat models (gpt-5.1, gpt-4o, gpt-5.4, o3, and more)",
    ]

    var body: some View {
        Group {
            if isLoading, plan == nil {
                loadingCard
            } else {
                planCard
            }
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView().tint(AppColors.accent)
            Text("Loading plan…")
                .font(AppTypography.bodySecondary)
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanel(subtle: true)
    }

    private var planCard: some View {
        let isPaid = plan?.isPaid ?? false
        let freeModel = plan?.freeModel ?? ChatConfig.freeDefaultModel
        let backgroundModel = plan?.backgroundModel ?? ChatConfig.proDefaultModel
        let features = isPaid ? Self.proFeatures : Self.freeFeatures

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isPaid ? "Pro" : "Free")
                        .font(AppTypography.sectionTitle)
                        .foregroundStyle(AppColors.label)
                    Text(planSummary(isPaid: isPaid, freeModel: freeModel))
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColors.secondaryLabel)
                }
                Spacer()
                PlanBadge(label: isPaid ? "Pro" : "Free", isPaid: isPaid)
            }

            AppDisclosureSection(
                title: "What's included",
                footnote: "\(features.count) features",
                isExpanded: $featuresExpanded
            ) {
                AppFeatureChecklist(
                    items: features,
                    footnote: isPaid ? proFootnote(backgroundModel) : freeFootnote(freeModel)
                )
            }

            if !isPaid, let url = proRequestURL {
                Link("Request Pro access", destination: url)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accent)
            }
        }
        .appPanel(subtle: true)
    }

    private var proRequestURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfig.supportEmail
        components.queryItems = [URLQueryItem(name: "subject", value: "Tomcrest Pro access")]
        return components.url
    }

    private func planSummary(isPaid: Bool, freeModel: String) -> String {
        if isPaid {
            return "Full access to every AI model and Pro research synthesis."
        }
        return "Portfolio analysis and chat on efficient models (default \(freeModel))."
    }

    private func freeFootnote(_ freeModel: String) -> String {
        "Research data is free; AI-generated earnings, news, business, and financial analysis require Pro."
    }

    private func proFootnote(_ backgroundModel: String) -> String {
        "Automated analysis uses \(backgroundModel). Billing is invite-only during beta."
    }
}

private struct PlanBadge: View {
    let label: String
    let isPaid: Bool

    var body: some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isPaid ? AppColors.accentHighlight : AppColors.secondaryLabel)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isPaid ? AppColors.accent.opacity(0.15) : AppColors.secondaryFill)
            .clipShape(Capsule())
    }
}

// MARK: - Delete account

struct DeleteAccountCard: View {
    let confirmDelete: Bool
    let isDeleting: Bool
    let error: String?
    let onBeginDelete: () -> Void
    let onConfirmDelete: () -> Void
    let onCancelDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                "Permanently removes your account, Schwab connection, chat history, " +
                    "strategy settings, and stored portfolio data."
            )
            .font(AppTypography.caption)
            .foregroundStyle(AppColors.secondaryLabel)

            if let error {
                AppInlineBanner(message: error, tone: .error)
            }

            if confirmDelete {
                HStack(spacing: 10) {
                    Button(isDeleting ? "Deleting…" : "Delete permanently", role: .destructive) {
                        onConfirmDelete()
                    }
                    .buttonStyle(AppPrimaryButtonStyle(destructive: true))
                    .disabled(isDeleting)

                    Button("Cancel", action: onCancelDelete)
                        .buttonStyle(AppSecondaryButtonStyle())
                        .disabled(isDeleting)
                }
            } else {
                Button("Delete account", role: .destructive, action: onBeginDelete)
                    .buttonStyle(AppSecondaryButtonStyle(destructive: true))
            }
        }
    }
}

// Legacy aliases — use AppPrimaryButtonStyle / AppSecondaryButtonStyle in new code.
typealias SettingsPrimaryButtonStyle = AppPrimaryButtonStyle
typealias SettingsSecondaryButtonStyle = AppSecondaryButtonStyle
typealias SettingsTertiaryButtonStyle = AppTertiaryButtonStyle
