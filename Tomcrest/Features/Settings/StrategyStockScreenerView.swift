import SwiftUI

enum ScreenerFilterSupport {
    static let marketCapPresets: [(label: String, value: Int)] = [
        ("$2B+", 2_000_000_000),
        ("$10B+", 10_000_000_000),
        ("$50B+", 50_000_000_000),
    ]

    static let sectors = [
        "Technology", "Healthcare", "Financial Services", "Consumer Cyclical",
        "Industrials", "Communication Services", "Consumer Defensive", "Energy",
        "Utilities", "Real Estate", "Basic Materials",
    ]
}

@MainActor
@Observable
final class StrategyScreenerViewModel {
    private(set) var result: StrategyStockScreenerResult?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var addedSymbols: Set<String> = []

    var page = 1
    var filters = StrategyScreenerFilters()
    var showFilters = false

    private let auth: AuthSession
    private let strategyId: String
    private var autoRunTask: Task<Void, Never>?

    init(strategyId: String, auth: AuthSession) {
        self.strategyId = strategyId
        self.auth = auth
    }

    var filterSummary: String {
        var parts: [String] = []
        parts.append("Cap ≥ \(CurrencyFormatter.compactUSD(Double(filters.minMarketCap)))")
        if let maxPe = filters.maxPe {
            parts.append("P/E ≤ \(String(format: "%.0f", maxPe))")
        }
        if filters.requireDividend { parts.append("Dividend payers") }
        if let sectors = filters.sectors, !sectors.isEmpty {
            parts.append("\(sectors.count) sectors")
        }
        return parts.joined(separator: " · ")
    }

    func load(force: Bool = false) async {
        guard let accessToken = auth.accessToken else { return }
        if isLoading { return }
        if result != nil, !force { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            result = try await StrategyService.fetchStockScreener(
                strategyId: strategyId,
                accessToken: accessToken,
                page: page,
                pageSize: 10,
                filters: filters
            )
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func runSearch() async {
        page = 1
        result = nil
        await load(force: true)
    }

    func scheduleAutoRun() {
        autoRunTask?.cancel()
        autoRunTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await runSearch()
        }
    }

    func nextPage() async {
        guard let result, page < result.totalPages else { return }
        page += 1
        await load(force: true)
    }

    func previousPage() async {
        guard page > 1 else { return }
        page -= 1
        await load(force: true)
    }

    func markAdded(_ symbol: String) {
        addedSymbols.insert(symbol.uppercased())
    }
}

struct StrategyStockScreenerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: StrategyScreenerViewModel
    var onAddSymbol: ((String) async -> Void)?

    init(strategyId: String, auth: AuthSession, onAddSymbol: ((String) async -> Void)? = nil) {
        _viewModel = State(initialValue: StrategyScreenerViewModel(strategyId: strategyId, auth: auth))
        self.onAddSymbol = onAddSymbol
    }

    var body: some View {
        AppNavigationCanvasStack {
            AppScrollScreen {
                if viewModel.isLoading, viewModel.result == nil {
                    AppLoadingState(message: "Running screener…")
                } else if let error = viewModel.errorMessage, viewModel.result == nil {
                    AppErrorState(message: error) {
                        Task { await viewModel.load(force: true) }
                    }
                } else if let result = viewModel.result {
                    screenerContent(result)
                } else {
                    filterPanel
                    Button("Run screener") {
                        Task { await viewModel.runSearch() }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.onAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(AppColors.accent)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                }
            }
            .appRootNavigation("Stock screener")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(viewModel.showFilters ? "Hide filters" : "Filters") {
                        viewModel.showFilters.toggle()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                if viewModel.showFilters {
                    filterPanel
                        .padding(.horizontal, Layout.horizontalPadding)
                        .padding(.vertical, 10)
                        .background(AppColors.secondaryBackground.opacity(0.95))
                }
            }
            .task {
                await viewModel.runSearch()
            }
            .onChange(of: viewModel.filters.minMarketCap) { _, _ in
                viewModel.scheduleAutoRun()
            }
            .onChange(of: viewModel.filters.requireDividend) { _, _ in
                viewModel.scheduleAutoRun()
            }
            .onChange(of: viewModel.filters.maxPe) { _, _ in
                viewModel.scheduleAutoRun()
            }
            .onChange(of: viewModel.filters.sectors) { _, _ in
                viewModel.scheduleAutoRun()
            }
        }
    }

    @ViewBuilder
    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Filters")
                .font(.caption.weight(.semibold))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ScreenerFilterSupport.marketCapPresets, id: \.value) { preset in
                        AppChip(
                            title: preset.label,
                            isSelected: viewModel.filters.minMarketCap == preset.value
                        ) {
                            viewModel.filters.minMarketCap = preset.value
                        }
                    }
                }
            }
            Toggle("Dividend payers only", isOn: $viewModel.filters.requireDividend)
                .font(.caption)
            HStack {
                Text("Max P/E")
                    .font(.caption)
                Slider(
                    value: Binding(
                        get: { viewModel.filters.maxPe ?? 40 },
                        set: { viewModel.filters.maxPe = $0 }
                    ),
                    in: 10 ... 60,
                    step: 1
                )
                Text(viewModel.filters.maxPe.map { String(format: "%.0f", $0) } ?? "Any")
                    .font(.caption.monospacedDigit())
            }
            Text("Sectors")
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.tertiaryLabel)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(ScreenerFilterSupport.sectors, id: \.self) { sector in
                    let selected = viewModel.filters.sectors?.contains(sector) == true
                    AppChip(title: sector, isSelected: selected) {
                        var current = viewModel.filters.sectors ?? []
                        if selected {
                            current.removeAll { $0 == sector }
                        } else {
                            current.append(sector)
                        }
                        viewModel.filters.sectors = current.isEmpty ? nil : current
                    }
                }
            }
            Text(viewModel.filterSummary)
                .font(.caption2)
                .foregroundStyle(AppColors.secondaryLabel)
            Button("Apply filters") {
                Task { await viewModel.runSearch() }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppColors.accentHighlight)
            .buttonStyle(.plain)
        }
        .appPanel(subtle: true)
    }

    @ViewBuilder
    private func screenerContent(_ result: StrategyStockScreenerResult) -> some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            Text(viewModel.filterSummary)
                .font(.caption2)
                .foregroundStyle(AppColors.secondaryLabel)

            if !result.summary.isEmpty {
                Text(result.summary)
                    .font(AppTypography.bodySecondary)
                    .foregroundStyle(AppColors.secondaryLabel)
                    .lineSpacing(3)
            }

            AppScreenSection(
                title: result.preset.label,
                footnote: "\(result.totalCount) matches · page \(result.page)/\(max(result.totalPages, 1))"
            ) {
                if result.quotes.isEmpty {
                    AppEmptyMessage(message: "No symbols matched your filters.")
                } else {
                    AppGroupedList {
                        ForEach(Array(result.quotes.enumerated()), id: \.element.id) { index, quote in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(quote.symbol)
                                        .font(AppTypography.cardTitle.monospaced())
                                    Spacer()
                                    if let price = quote.price {
                                        Text(CurrencyFormatter.usd(price))
                                            .font(.caption.monospacedDigit())
                                    }
                                }
                                if let name = quote.companyName {
                                    Text(name)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.secondaryLabel)
                                        .lineLimit(1)
                                }
                                HStack {
                                    if let pe = quote.peRatio {
                                        Text("P/E \(String(format: "%.1f", pe))")
                                    }
                                    if let yield = quote.dividendYield {
                                        Text("Yield \(CurrencyFormatter.percent(yield))")
                                    }
                                    Spacer()
                                    if onAddSymbol != nil {
                                        if viewModel.addedSymbols.contains(quote.symbol) {
                                            Text("Added")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(AppColors.success)
                                        } else {
                                            Button("Add") {
                                                Task {
                                                    await onAddSymbol?(quote.symbol)
                                                    viewModel.markAdded(quote.symbol)
                                                }
                                            }
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(AppColors.accentHighlight)
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                                .font(.caption2)
                                .foregroundStyle(AppColors.tertiaryLabel)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)

                            if index < result.quotes.count - 1 {
                                AppGroupedDivider()
                            }
                        }
                    }
                }
            }

            HStack {
                Button("Previous") {
                    Task { await viewModel.previousPage() }
                }
                .disabled(viewModel.page <= 1 || viewModel.isLoading)
                Spacer()
                Button("Next") {
                    Task { await viewModel.nextPage() }
                }
                .disabled((viewModel.result?.page ?? 1) >= (viewModel.result?.totalPages ?? 1) || viewModel.isLoading)
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.plain)
        }
    }
}

private extension CurrencyFormatter {
    static func compactUSD(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return String(format: "$%.0fB", value / 1_000_000_000)
        }
        if value >= 1_000_000 {
            return String(format: "$%.0fM", value / 1_000_000)
        }
        return usd(value, fractionDigits: 0)
    }
}
