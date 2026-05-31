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

    func loadIfNeeded(_ tab: ResearchTab, force: Bool = false) async {
        guard tab != .overview, tab != .position else { return }
        if !force, loadedTabs.contains(tab), loadingTab != tab { return }

        loadingTab = tab
        tabErrors[tab] = nil
        defer {
            if loadingTab == tab {
                loadingTab = nil
            }
        }

        await loadTab(tab)
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

    private func loadTab(_ tab: ResearchTab) async {
        do {
            switch tab {
            case .overview, .position:
                break
            case .earnings:
                guard let accessToken = auth.accessToken else {
                    throw APIError.missingToken
                }
                earnings = try await ResearchService.fetchEarningsList(
                    symbol: symbol,
                    accessToken: accessToken
                )
                if selectedHistoryEvent == nil {
                    selectedHistoryEvent = earnings?.history.first
                }
            case .news:
                guard let accessToken = auth.accessToken else {
                    throw APIError.missingToken
                }
                async let releases = ResearchService.fetchPressReleases(
                    symbol: symbol,
                    accessToken: accessToken
                )
                async let coverage = ResearchService.fetchCompanyNews(
                    symbol: symbol,
                    accessToken: accessToken
                )
                let (official, market) = try await (releases, coverage)
                news = official
                companyNews = market
            case .dividends:
                guard let accessToken = auth.accessToken else {
                    throw APIError.missingToken
                }
                dividends = try await ResearchService.fetchDividendHistory(
                    symbol: symbol,
                    accessToken: accessToken
                )
            case .fundamentals:
                guard let accessToken = auth.accessToken else {
                    throw APIError.missingToken
                }
                fundamentals = try await ResearchService.fetchFundamentals(
                    symbol: symbol,
                    accessToken: accessToken
                )
            case .financials:
                guard let accessToken = auth.accessToken else {
                    throw APIError.missingToken
                }
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
            case .composition:
                guard let accessToken = auth.accessToken else {
                    throw APIError.missingToken
                }
                etfHoldings = try await ResearchService.fetchEtfHoldings(
                    symbol: symbol,
                    accessToken: accessToken
                )
            case .business:
                guard let accessToken = auth.accessToken else {
                    throw APIError.missingToken
                }
                business = try await ResearchService.fetchBusinessDetails(
                    symbol: symbol,
                    accessToken: accessToken
                )
            case .options:
                guard let accessToken = auth.accessToken else {
                    throw APIError.missingToken
                }
                symbolIntelligence = try await ResearchService.fetchSymbolIntelligence(
                    symbol: symbol,
                    accessToken: accessToken
                )
            case .backtest:
                guard let accessToken = auth.accessToken else {
                    throw APIError.missingToken
                }
                dividends = try await ResearchService.fetchDividendHistory(
                    symbol: symbol,
                    accessToken: accessToken
                )
            }
            loadedTabs.insert(tab)
        } catch {
            tabErrors[tab] = (error as? APIError)?.errorDescription ?? error.localizedDescription
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

    func reload(_ tab: ResearchTab) async {
        loadedTabs.remove(tab)
        if tab == .earnings {
            earningsDetail = nil
            selectedHistoryEvent = nil
        }
        if tab == .news {
            companyNews = nil
        }
        await loadIfNeeded(tab, force: true)
        if tab == .earnings, let event = earnings?.history.first {
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
        loadingTab = .dividends
        tabErrors[.dividends] = nil
        defer {
            if loadingTab == .dividends { loadingTab = nil }
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
            loadedTabs.insert(.dividends)
        } catch {
            tabErrors[.dividends] = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadDividendBacktest(
        historyStartYear: Int,
        context: DividendHistoryContext,
        marketSharePrice: Double?
    ) async {
        guard let accessToken = auth.accessToken else { return }
        dividendBacktestLoading = true
        tabErrors[.backtest] = nil
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
            tabErrors[.backtest] = "Enter an investment amount or share count to run the backtest."
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
            loadedTabs.insert(.dividends)
            hasRunDividendBacktest = true
        } catch {
            tabErrors[.backtest] = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func runWheelBacktest() async {
        guard let accessToken = auth.accessToken else { return }
        wheelBacktestLoading = true
        tabErrors[.backtest] = nil
        defer { wheelBacktestLoading = false }

        do {
            wheelBacktest = try await ResearchService.fetchWheelBacktest(
                query: wheelBacktestQuery,
                accessToken: accessToken
            )
        } catch {
            tabErrors[.backtest] = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}
