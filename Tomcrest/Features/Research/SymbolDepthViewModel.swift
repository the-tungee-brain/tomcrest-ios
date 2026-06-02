import Foundation

@MainActor
@Observable
final class SymbolDepthViewModel {
    let symbol: String

    private(set) var earnings: EarningsListResponse?
    private(set) var dividends: DividendHistoryContext?
    private(set) var news: PressReleasesResponse?
    private(set) var companyNews: StockNewsView?
    private(set) var companyNewsAnalyzing = false
    private(set) var fundamentals: FundamentalsBlock?
    private(set) var business: BusinessBlock?
    private(set) var etfHoldings: EtfHoldingsContext?
    private(set) var symbolIntelligence: SymbolIntelligenceDetail?
    private(set) var wheelBacktest: WheelBacktestResult?
    private(set) var patternPrediction: PatternPredictionResponse?
    private(set) var patternIntelligence: PatternIntelligenceResponse?
    private(set) var patternModelHealth: PatternPredictionHealthResponse?
    private(set) var secFilings: SecFilingsResponse?
    private(set) var secRatios: SecRatiosResponse?
    private(set) var secFinancials: SecFinancialsResponse?
    var wheelBacktestQuery: WheelBacktestQuery
    var dividendBacktestQuery = DividendBacktestQuery()
    private(set) var wheelBacktestLoading = false
    private(set) var dividendBacktestLoading = false
    private(set) var hasRunDividendBacktest = false

    private(set) var selectedHistoryEvent: EarningsEvent?
    private(set) var earningsDetail: EarningsDetailResponse?
    private(set) var earningsDetailLoading = false
    private(set) var earningsDetailError: String?

    private(set) var loadingTab: ResearchTab?
    private(set) var tabErrors: [ResearchTab: String] = [:]

    private var loadedTabs: Set<ResearchTab> = []
    private let auth: AuthSession

    init(symbol: String, auth: AuthSession) {
        self.symbol = symbol.uppercased()
        self.auth = auth
        self.wheelBacktestQuery = WheelBacktestQuery(symbol: symbol.uppercased())
    }

    func loadIfNeeded(
        _ tab: ResearchTab,
        more: ResearchMoreDestination? = nil,
        force: Bool = false
    ) async {
        guard tab != .overview else { return }

        let loadKey = loadCacheKey(tab: tab, more: more)
        if !force, loadedTabs.contains(loadKey), loadingTab != loadKey { return }

        loadingTab = loadKey
        tabErrors[loadKey] = nil
        defer {
            if loadingTab == loadKey {
                loadingTab = nil
            }
        }

        await loadTab(tab, more: more)
    }

    private func loadCacheKey(tab: ResearchTab, more: ResearchMoreDestination?) -> ResearchTab {
        switch (tab, more) {
        case (.more, .income): .more
        case (.more, .tools): .more
        case (.more, .composition): .more
        case (.more, .portfolio): .more
        default: tab
        }
    }

    func prefetchOptionsIntelligenceIfNeeded(hasOptionPositions: Bool) async {
        guard hasOptionPositions, symbolIntelligence == nil else { return }
        guard let accessToken = auth.accessToken else { return }

        do {
            symbolIntelligence = try await ResearchService.fetchSymbolIntelligence(
                symbol: symbol,
                accessToken: accessToken
            )
        } catch {
            // Options tab gating falls back to position checks only.
        }
    }

    private func loadTab(_ tab: ResearchTab, more: ResearchMoreDestination? = nil) async {
        let loadKey = loadCacheKey(tab: tab, more: more)
        do {
            guard let accessToken = auth.accessToken else {
                throw APIError.missingToken
            }

            switch tab {
            case .overview:
                break
            case .analysis:
                do {
                    business = try await ResearchService.fetchBusinessDetails(
                        symbol: symbol,
                        accessToken: accessToken
                    )
                } catch {
                    // Pro gate or unavailable — Analysis hub shows upsell inline.
                }
                do {
                    patternPrediction = try await PatternPredictionService.fetchPrediction(
                        symbol: symbol,
                        accessToken: accessToken
                    )
                } catch {
                    patternPrediction = nil
                }
                do {
                    patternIntelligence = try await PatternPredictionService.fetchIntelligence(
                        symbol: symbol,
                        accessToken: accessToken
                    )
                } catch {
                    patternIntelligence = nil
                }
                do {
                    patternModelHealth = try await PatternPredictionService.fetchHealth(
                        accessToken: accessToken
                    )
                } catch {
                    patternModelHealth = nil
                }
            case .metrics:
                fundamentals = try await ResearchService.fetchFundamentals(
                    symbol: symbol,
                    accessToken: accessToken
                )
            case .news:
                try await loadNews(accessToken: accessToken)
            case .financials:
                async let fundamentalsTask = ResearchService.fetchFundamentals(
                    symbol: symbol,
                    accessToken: accessToken
                )
                async let filingsTask = ResearchService.fetchSecFilings(
                    symbol: symbol,
                    accessToken: accessToken
                )
                async let ratiosTask = ResearchService.fetchSecRatios(
                    symbol: symbol,
                    accessToken: accessToken
                )
                async let financialsTask = ResearchService.fetchSecFinancials(
                    symbol: symbol,
                    accessToken: accessToken
                )
                let (fundamentalsResult, filingsResult, ratiosResult, financialsResult) = try await (
                    fundamentalsTask, filingsTask, ratiosTask, financialsTask
                )
                fundamentals = fundamentalsResult
                secFilings = filingsResult
                secRatios = ratiosResult
                secFinancials = financialsResult
            case .more:
                switch more {
                case .income:
                    earnings = try await ResearchService.fetchEarningsList(
                        symbol: symbol,
                        accessToken: accessToken
                    )
                    if selectedHistoryEvent == nil {
                        selectedHistoryEvent = earnings?.history.first
                    }
                    dividends = try await ResearchService.fetchDividendHistory(
                        symbol: symbol,
                        accessToken: accessToken
                    )
                case .tools:
                    dividends = try await ResearchService.fetchDividendHistory(
                        symbol: symbol,
                        accessToken: accessToken
                    )
                case .composition:
                    etfHoldings = try await ResearchService.fetchEtfHoldings(
                        symbol: symbol,
                        accessToken: accessToken
                    )
                case .portfolio:
                    symbolIntelligence = try await ResearchService.fetchSymbolIntelligence(
                        symbol: symbol,
                        accessToken: accessToken
                    )
                case nil:
                    break
                }
            }
            loadedTabs.insert(loadKey)
        } catch {
            tabErrors[loadKey] = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func loadNews(accessToken: String) async throws {
        var errors: [String] = []

        do {
            news = try await ResearchService.fetchPressReleases(
                symbol: symbol,
                accessToken: accessToken
            )
        } catch {
            errors.append("Official releases: \((error as? APIError)?.errorDescription ?? error.localizedDescription)")
        }

        do {
            companyNews = try await ResearchService.fetchCompanyNews(
                symbol: symbol,
                accessToken: accessToken
            )
        } catch {
            errors.append("Market coverage: \((error as? APIError)?.errorDescription ?? error.localizedDescription)")
        }

        if news == nil, companyNews == nil {
            if let first = errors.first {
                throw APIError.httpStatus(-1, message: first)
            }
            throw APIError.httpStatus(-1, message: "Could not load news for this symbol.")
        }

        if !errors.isEmpty {
            tabErrors[.news] = errors.joined(separator: " ")
        }
    }

    func analyzeCompanyNews(refresh: Bool = false) async {
        guard let accessToken = auth.accessToken else { return }
        if companyNewsAnalyzing { return }

        companyNewsAnalyzing = true
        tabErrors[.news] = nil
        defer { companyNewsAnalyzing = false }

        do {
            companyNews = try await ResearchService.analyzeCompanyNews(
                symbol: symbol,
                accessToken: accessToken,
                refresh: refresh
            )
        } catch {
            tabErrors[.news] = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func selectHistoryEvent(_ event: EarningsEvent, includeAnalysis: Bool) async {
        selectedHistoryEvent = event
        earningsDetail = nil
        earningsDetailError = nil
        await loadEarningsDetail(includeAnalysis: includeAnalysis)
    }

    func loadEarningsDetail(includeAnalysis: Bool, force: Bool = false) async {
        guard let event = selectedHistoryEvent,
              let accessToken = auth.accessToken else { return }
        if earningsDetailLoading { return }
        if !force, earningsDetail?.event.id == event.id { return }

        earningsDetailLoading = true
        earningsDetailError = nil
        defer { earningsDetailLoading = false }

        do {
            earningsDetail = try await ResearchService.fetchEarningsDetail(
                symbol: symbol,
                reportDate: event.reportDate,
                accessToken: accessToken,
                includeAnalysis: includeAnalysis
            )
        } catch {
            earningsDetailError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func reload(_ tab: ResearchTab, more: ResearchMoreDestination? = nil) async {
        let loadKey = loadCacheKey(tab: tab, more: more)
        loadedTabs.remove(loadKey)
        if more == .income || tab == .more && more == .income {
            earningsDetail = nil
            selectedHistoryEvent = nil
        }
        if tab == .news {
            companyNews = nil
        }
        if tab == .analysis {
            patternPrediction = nil
            patternIntelligence = nil
            patternModelHealth = nil
        }
        await loadIfNeeded(tab, more: more, force: true)
        if more == .income, let event = earnings?.history.first {
            selectedHistoryEvent = event
        }
    }

    func loadDividendSnowball(
        projectYears: Int = 10,
        reinvestDividends: Bool = true,
        priceCagrPct: Double? = nil,
        annualContributionUsd: Double = 0,
        shares: Double = 100
    ) async {
        guard let accessToken = auth.accessToken else { return }
        loadingTab = .more
        tabErrors[.more] = nil
        defer {
            if loadingTab == .more { loadingTab = nil }
        }

        do {
            dividends = try await ResearchService.fetchDividendHistory(
                symbol: symbol,
                accessToken: accessToken,
                shares: shares,
                projectYears: projectYears,
                reinvestDividends: reinvestDividends,
                priceCagrPct: priceCagrPct,
                annualContributionUsd: annualContributionUsd
            )
            loadedTabs.insert(.more)
        } catch {
            tabErrors[.more] = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadDividendBacktest(
        historyStartYear: Int,
        context: DividendHistoryContext,
        marketSharePrice: Double?
    ) async {
        guard let accessToken = auth.accessToken else { return }
        dividendBacktestLoading = true
        tabErrors[.more] = nil
        defer { dividendBacktestLoading = false }

        let endYear = DividendBacktestSupport.completedYears(from: context).last ?? historyStartYear
        let (resolvedQuery, sharePrice) = DividendBacktestSupport.resolveQueryForRun(
            dividendBacktestQuery,
            context: context,
            marketSharePrice: marketSharePrice,
            startYear: historyStartYear,
            endYear: endYear
        )
        dividendBacktestQuery = resolvedQuery

        guard resolvedQuery.shares > 0 || resolvedQuery.investmentUsd > 0 else {
            tabErrors[.more] = "Enter an investment amount or share count to run the backtest."
            return
        }

        do {
            dividends = try await ResearchService.fetchDividendHistory(
                symbol: symbol,
                accessToken: accessToken,
                shares: max(resolvedQuery.shares, 0.01),
                investmentUsd: resolvedQuery.investmentUsd > 0 ? resolvedQuery.investmentUsd : nil,
                sharePrice: sharePrice,
                reinvestDividends: resolvedQuery.reinvestDividends,
                historyStartYear: historyStartYear,
                annualContributionUsd: resolvedQuery.annualContributionUsd
            )
            loadedTabs.insert(.more)
            hasRunDividendBacktest = true
        } catch {
            tabErrors[.more] = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func runWheelBacktest() async {
        guard let accessToken = auth.accessToken else { return }
        wheelBacktestLoading = true
        tabErrors[.more] = nil
        defer { wheelBacktestLoading = false }

        do {
            wheelBacktest = try await ResearchService.fetchWheelBacktest(
                query: wheelBacktestQuery,
                accessToken: accessToken
            )
        } catch {
            tabErrors[.more] = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
