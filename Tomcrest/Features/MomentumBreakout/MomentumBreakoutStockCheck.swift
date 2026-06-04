import SwiftUI

struct MomentumBreakoutStockCheck: View {
    @Environment(WatchlistStore.self) private var watchlistStore
    @Bindable var viewModel: MomentumBreakoutAlertsViewModel

    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            AppSearchField(
                placeholder: "Symbol or company name",
                text: $viewModel.stockCheckQuery,
                isLoading: viewModel.stockCheckSearching,
                onSubmit: {
                    searchFocused = false
                    Task { await viewModel.runStockCheck(symbol: viewModel.stockCheckQuery) }
                },
                focus: $searchFocused
            )
            .onChange(of: viewModel.stockCheckQuery) { _, newValue in
                viewModel.updateStockCheckQuery(newValue)
            }

            if showSearchResults {
                searchResultsPanel
            }

            if !watchlistSuggestions.isEmpty {
                watchlistChipsSection
            }

            if viewModel.stockCheckLoading {
                loadingCard
            }

            if let error = viewModel.stockCheckError, !error.isEmpty {
                AppInlineBanner(message: error, tone: .error)
            }

            if let result = viewModel.stockCheckResult, !viewModel.stockCheckLoading {
                checkResultCard(result)
            }

            if let plan = viewModel.customPlan {
                customPlanCard(plan)
            }
        }
        .appPanel()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Check any stock")
        .task {
            await watchlistStore.ensureLoaded()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("MANUAL CHECK")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
                .tracking(0.6)
            Text("Check any stock")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(AppColors.label)
            Text("Run a one-off breakout check, or tap a symbol from your research watchlist.")
                .font(.system(size: 13))
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var showSearchResults: Bool {
        !viewModel.stockCheckResults.isEmpty
            && !viewModel.stockCheckQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && searchFocused
    }

    private var watchlistSuggestions: [(symbol: String, title: String)] {
        var seen = Set<String>()
        var items: [(symbol: String, title: String)] = []
        for folder in watchlistStore.sortedFolders {
            for symbol in folder.symbols {
                let upper = symbol.ticker.uppercased()
                guard seen.insert(upper).inserted else { continue }
                let title = symbol.companyName.trimmingCharacters(in: .whitespacesAndNewlines)
                items.append((upper, title.isEmpty ? upper : title))
            }
        }
        if items.isEmpty, !watchlistStore.allTickers.isEmpty {
            for ticker in watchlistStore.allTickers {
                let upper = ticker.uppercased()
                guard seen.insert(upper).inserted else { continue }
                items.append((upper, upper))
            }
        }
        return items
    }

    private var watchlistChipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("From your watchlist")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 76), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(watchlistSuggestions, id: \.symbol) { item in
                    Button {
                        searchFocused = false
                        Task { await viewModel.runStockCheck(symbol: item.symbol) }
                    } label: {
                        Text(item.symbol)
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppColors.background)
                            .clipShape(Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(AppColors.separator.opacity(0.8), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var searchResultsPanel: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.stockCheckResults) { item in
                Button {
                    searchFocused = false
                    Task { await viewModel.runStockCheck(symbol: item.symbol) }
                } label: {
                    SymbolSearchRowContent(item: item)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                if item.id != viewModel.stockCheckResults.last?.id {
                    Divider().overlay(AppColors.separator.opacity(0.6))
                }
            }
        }
        .background(AppColors.background)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }

    private var loadingCard: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Checking setup…")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppColors.secondaryLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColors.background.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    @ViewBuilder
    private func checkResultCard(_ result: MomentumBreakoutCheckResponse) -> some View {
        let tone = resultPanelTone(result.checkStatus)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(result.symbol)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppColors.label)
                statusPill(for: result.checkStatus)
                Spacer(minLength: 0)
            }

            Text(result.verdictTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.label)
            Text(result.verdictMessage)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            if result.checkStatus == .rejectedBreakout, !result.rejectionReasons.isEmpty {
                ruleList(result.rejectionReasons)
            }
            if result.checkStatus == .noBreakoutSetup, !result.failedSetupRules.isEmpty {
                ruleList(result.failedSetupRules)
            }

            if let entry = result.entryPrice, let stop = result.stopPrice {
                let target = result.targetPrice.map {
                    MomentumBreakoutAlertPresentation.formatUsd($0)
                } ?? "—"
                Text(
                    "Entry \(MomentumBreakoutAlertPresentation.formatUsd(entry)) · Stop \(MomentumBreakoutAlertPresentation.formatUsd(stop)) · Target \(target)"
                )
                .font(.system(size: 12))
                .foregroundStyle(AppColors.tertiaryLabel)
            }

            if result.canTrackBreakoutPlan,
               result.checkStatus == .tradableBreakout || result.checkStatus == .rejectedBreakout {
                trackButton(for: result.symbol)
            }

            if result.checkStatus == .noBreakoutSetup {
                Button {
                    Task { await viewModel.generateCustomPlan() }
                } label: {
                    Group {
                        if viewModel.customPlanLoading {
                            ProgressView()
                                .tint(AppColors.background)
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Generate custom educational plan")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppColors.background)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .opacity(viewModel.customPlanLoading ? 0.75 : 1)
                .disabled(viewModel.customPlanLoading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tone.background)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tone.border, lineWidth: 1)
        }
    }

    private func statusPill(for status: MomentumBreakoutCheckStatus) -> some View {
        let label: String
        let color: Color
        switch status {
        case .tradableBreakout:
            label = "Tradable"
            color = AppColors.success
        case .rejectedBreakout:
            label = "Rejected"
            color = AppColors.warning
        case .noBreakoutSetup:
            label = "No setup"
            color = AppColors.secondaryLabel
        default:
            label = "Unavailable"
            color = AppColors.tertiaryLabel
        }
        return Text(label.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func trackButton(for symbol: String) -> some View {
        let upper = symbol.uppercased()
        let tracked = viewModel.trackedSymbols.contains(upper)
        let loading = viewModel.trackingSymbol == upper
        return Button {
            Task { await viewModel.trackPlan(symbol: upper) }
        } label: {
            Group {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text(tracked ? "View on watchlist" : "Track this breakout plan")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(loading)
    }

    private func customPlanCard(_ plan: CustomTradePlanResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CUSTOM PLAN · NOT MOMENTUM BREAKOUT")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(AppColors.tertiaryLabel)
                .tracking(0.5)
            Text(plan.entryExplanation)
                .font(.system(size: 13))
                .foregroundStyle(AppColors.secondaryLabel)
                .fixedSize(horizontal: false, vertical: true)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), alignment: .leading),
                    GridItem(.flexible(), alignment: .leading),
                ],
                spacing: 8
            ) {
                metricTile(
                    title: "Current",
                    value: MomentumBreakoutAlertPresentation.formatUsd(plan.currentPrice),
                    footnote: plan.latestBarDate
                )
                metricTile(
                    title: "Entry trigger",
                    value: MomentumBreakoutAlertPresentation.formatUsd(plan.entryPrice),
                    footnote: plan.distanceToEntryPct > 2
                        ? String(format: "+%.1f%% away", plan.distanceToEntryPct)
                        : nil
                )
                metricTile(
                    title: "Stop",
                    value: MomentumBreakoutAlertPresentation.formatUsd(plan.stopPrice),
                    footnote: nil
                )
                metricTile(
                    title: "Target",
                    value: "\(MomentumBreakoutAlertPresentation.formatUsd(plan.targetPrice)) · \(String(format: "%.1f", plan.riskReward))R",
                    footnote: nil
                )
            }

            if !plan.planActiveAtCurrentPrice {
                Text("Inactive until entry trigger is reached. Educational only — we do not place trades.")
                    .font(.system(size: 12))
                    .foregroundStyle(AppColors.secondaryLabel)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.warning.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            if !plan.warnings.isEmpty {
                ruleList(plan.warnings)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.background.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.panelBorder, lineWidth: 1)
        }
    }

    private func metricTile(title: String, value: String, footnote: String?) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(AppColors.tertiaryLabel)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppColors.label)
                .minimumScaleFactor(0.85)
                .lineLimit(1)
            if let footnote {
                Text(footnote)
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.tertiaryLabel)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(AppColors.secondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func ruleList(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("·")
                        .foregroundStyle(AppColors.tertiaryLabel)
                    Text(item)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.system(size: 13))
                .foregroundStyle(AppColors.secondaryLabel)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColors.background.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func resultPanelTone(_ status: MomentumBreakoutCheckStatus) -> (
        background: Color,
        border: Color
    ) {
        switch status {
        case .tradableBreakout:
            return (AppColors.success.opacity(0.08), AppColors.success.opacity(0.3))
        case .rejectedBreakout:
            return (AppColors.warning.opacity(0.1), AppColors.warning.opacity(0.3))
        case .noBreakoutSetup:
            return (AppColors.tertiaryBackground.opacity(0.5), AppColors.panelBorder)
        default:
            return (AppColors.tertiaryBackground.opacity(0.4), AppColors.panelBorder)
        }
    }
}
