import Foundation
import Observation

@MainActor
@Observable
final class TopMoversViewModel {
    typealias FetchRankings = (String) async throws -> RankingsTopResponse
    typealias FetchHealth = (String) async throws -> SystemHealthResponse
    typealias FetchPortfolioSymbols = (String) async throws -> Set<String>
    typealias FetchPatternIntelligence = (String, String) async throws -> PatternIntelligenceResponse

    private(set) var items: [RankingItem] = []
    private(set) var regimeId: String?
    private(set) var asOfDate: String?
    private(set) var updatedAt: String?
    private(set) var systemStatus: String = "ok"
    private(set) var universeSize: Int?
    private(set) var portfolioSymbols: Set<String> = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var expandedSymbol: String?
    private(set) var patternIntelligenceBySymbol: [String: PatternIntelligenceResponse] = [:]
    private(set) var breakdownLoadingSymbols: Set<String> = []
    private var breakdownTask: Task<Void, Never>?

    private let auth: AuthSession
    private let fetchRankings: FetchRankings
    private let fetchHealth: FetchHealth
    private let fetchPortfolioSymbols: FetchPortfolioSymbols
    private let fetchPatternIntelligence: FetchPatternIntelligence
    private var pollTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private var metadataTask: Task<Void, Never>?
    private static let cacheKey = "rankings_top_v1"
    private static let breakdownPrefetchConcurrency = 4
    private static let initialBreakdownPrefetchLimit = 4

    private static let apiDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private static let apiEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        return encoder
    }()

    init(
        auth: AuthSession,
        fetchRankings: @escaping FetchRankings = { token in
            try await RankingService.fetchRankingsTop(accessToken: token)
        },
        fetchHealth: @escaping FetchHealth = { token in
            try await RankingService.fetchSystemHealth(accessToken: token)
        },
        fetchPortfolioSymbols: @escaping FetchPortfolioSymbols = { token in
            try await RankingService.fetchPortfolioSymbols(accessToken: token)
        },
        fetchPatternIntelligence: @escaping FetchPatternIntelligence = { symbol, token in
            try await PatternPredictionService.fetchIntelligence(
                symbol: symbol,
                accessToken: token
            )
        }
    ) {
        self.auth = auth
        self.fetchRankings = fetchRankings
        self.fetchHealth = fetchHealth
        self.fetchPortfolioSymbols = fetchPortfolioSymbols
        self.fetchPatternIntelligence = fetchPatternIntelligence
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                await refresh()
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
        breakdownTask?.cancel()
        breakdownTask = nil
        prefetchTask?.cancel()
        prefetchTask = nil
        metadataTask?.cancel()
        metadataTask = nil
    }

    var hasMlMetrics: Bool {
        TopMoversFormatting.rankingsHaveMlMetrics(items)
    }

    func refresh() async {
        guard let token = auth.accessToken else { return }
        if items.isEmpty { isLoading = true }
        errorMessage = nil

        var rankingsResult: RankingsTopResponse?
        var fetchErrors: [String] = []

        do {
            rankingsResult = try await fetchRankings(token)
        } catch let error as APIError {
            fetchErrors.append(error.errorDescription ?? "Rankings failed.")
        } catch {
            fetchErrors.append(error.localizedDescription)
        }

        if let rankingsResult {
            apply(rankings: rankingsResult)
            errorMessage = nil
            isLoading = false
            scheduleMetadataLoad(accessToken: token, rankings: rankingsResult)
            prefetchInitialBreakdowns(accessToken: token)
        } else if items.isEmpty, let cached = loadCached() {
            apply(rankings: cached)
            errorMessage = fetchErrors.first
            isLoading = false
            scheduleMetadataLoad(accessToken: token, rankings: cached)
            prefetchInitialBreakdowns(accessToken: token)
        } else if !items.isEmpty {
            errorMessage = fetchErrors.first
            isLoading = false
        } else {
            errorMessage = fetchErrors.first ?? "Could not load rankings."
            isLoading = false
        }
    }

    func rankContext(for item: RankingItem) -> RankContext {
        TopMoversInsightEngine.rankContext(item: item, items: items)
    }

    func researchInsight(for item: RankingItem, symbol: String) -> MoverResearchInsight {
        let key = symbol.uppercased()
        let intel = patternIntelligenceBySymbol[key]
        let segments = breakdownSegments(for: key)
        return TopMoversInsightEngine.build(
            item: item,
            intel: intel,
            segments: segments,
            regimeId: regimeId,
            listCount: max(items.count, 1),
            inPortfolio: isInPortfolio(symbol)
        )
    }

    func portfolioRole(for item: RankingItem, symbol: String) -> String? {
        let tier = TopMoversInsightEngine.convictionFromListPercentile(
            TopMoversInsightEngine.listRankPercentile(
                rank: item.rank,
                listCount: max(items.count, 1)
            )
        )
        return TopMoversInsightEngine.portfolioRole(
            item: item,
            listCount: max(items.count, 1),
            inPortfolio: isInPortfolio(symbol),
            listTier: tier,
            regimeId: regimeId
        )
    }

    func convictionForRow(for item: RankingItem) -> ConvictionDisplay {
        TopMoversFormatting.convictionForRow(
            rank: item.rank,
            listCount: max(items.count, 1)
        )
    }

    func convictionForDetail(symbol: String, item: RankingItem) -> ConvictionDisplay {
        TopMoversFormatting.convictionForDetail(
            rank: item.rank,
            listCount: max(items.count, 1),
            scores: patternIntelligenceBySymbol[symbol.uppercased()]?.scores
        )
    }

    func priceTrendLabel(for symbol: String) -> String? {
        TopMoversFormatting.priceTrendLabel(
            patternIntelligenceBySymbol[symbol.uppercased()]
        )
    }

    func strengthsAndGaps(for symbol: String) -> StrengthsAndGaps {
        let key = symbol.uppercased()
        let intel = patternIntelligenceBySymbol[key]
        let segments = breakdownSegments(for: key)
        return TopMoversFormatting.strengthsAndGaps(intel: intel, segments: segments)
    }

    func sparklineValues(for symbol: String) -> [Double] {
        TopMoversFormatting.sparklineValues(
            from: breakdownSegments(for: symbol.uppercased())
        )
    }

    func insightHeadline(for symbol: String) -> String? {
        let headline = patternIntelligenceBySymbol[symbol.uppercased()]?
            .explanation
            .headline
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let headline, !headline.isEmpty else { return nil }
        return headline
    }

    func intelligence(for symbol: String) -> PatternIntelligenceResponse? {
        patternIntelligenceBySymbol[symbol.uppercased()]
    }

    func collapseExpanded() {
        guard expandedSymbol != nil else { return }
        expandedSymbol = nil
        breakdownTask?.cancel()
        breakdownTask = nil
    }

    func toggleExpanded(_ symbol: String) {
        let key = symbol.uppercased()
        if expandedSymbol == key {
            collapseExpanded()
        } else {
            expandedSymbol = key
            breakdownTask?.cancel()
            breakdownTask = Task { [weak self] in
                await self?.loadScoreBreakdown(symbol: key)
            }
        }
    }

    func breakdownSegments(for symbol: String) -> [ScoreBreakdownSegment] {
        let scores = patternIntelligenceBySymbol[symbol.uppercased()]?.scores
        return TopMoversFormatting.segments(from: scores)
    }

    /// Warms pattern intelligence for the rows most likely to be visible first.
    private func prefetchInitialBreakdowns(accessToken: String) {
        prefetchTask?.cancel()
        let symbols = items
            .prefix(Self.initialBreakdownPrefetchLimit)
            .map { $0.symbol.uppercased() }
        guard !symbols.isEmpty else { return }

        prefetchTask = Task { [weak self] in
            guard let self else { return }
            await prefetchBreakdowns(symbols: symbols, accessToken: accessToken)
        }
    }

    private func prefetchBreakdowns(symbols: [String], accessToken: String) async {
        let concurrency = Self.breakdownPrefetchConcurrency
        var nextIndex = 0

        await withTaskGroup(of: Void.self) { group in
            var inFlight = 0

            while nextIndex < symbols.count || inFlight > 0 {
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }

                while inFlight < concurrency, nextIndex < symbols.count {
                    let symbol = symbols[nextIndex]
                    nextIndex += 1
                    inFlight += 1
                    group.addTask { [weak self] in
                        await self?.loadScoreBreakdown(
                            symbol: symbol,
                            accessToken: accessToken
                        )
                    }
                }

                await group.next()
                inFlight -= 1
            }
        }
    }

    func hasPatternIntelligence(for symbol: String) -> Bool {
        patternIntelligenceBySymbol[symbol.uppercased()] != nil
    }

    private func loadScoreBreakdown(symbol: String, accessToken: String? = nil) async {
        let token = accessToken ?? auth.accessToken
        guard let token else { return }
        let key = symbol.uppercased()
        if patternIntelligenceBySymbol[key] != nil { return }

        breakdownLoadingSymbols.insert(key)
        defer { breakdownLoadingSymbols.remove(key) }

        do {
            let payload = try await fetchPatternIntelligence(key, token)
            patternIntelligenceBySymbol[key] = payload
        } catch {
            // Breakdown is optional; list remains usable.
        }
    }

    private func apply(rankings response: RankingsTopResponse) {
        items = response.items
        regimeId = response.regimeId
        asOfDate = response.asOfDate
        updatedAt = response.timestamp
        systemStatus = "ok"
        universeSize = nil
        persist(response)
    }

    private func scheduleMetadataLoad(accessToken: String, rankings: RankingsTopResponse) {
        metadataTask?.cancel()
        metadataTask = Task { [weak self] in
            guard let self else { return }

            async let health = self.fetchOptionalHealth(accessToken)
            async let portfolio = self.fetchOptionalPortfolioSymbols(accessToken)
            let metadata = await (health, portfolio)
            guard !Task.isCancelled else { return }

            if let health = metadata.0 {
                regimeId = health.regimeId ?? rankings.regimeId
                updatedAt = health.lastRankingRunAt ?? rankings.timestamp
                systemStatus = health.systemStatus
                universeSize = health.universeSize
            }
            if let portfolio = metadata.1 {
                portfolioSymbols = portfolio
            }
        }
    }

    private func fetchOptionalHealth(_ accessToken: String) async -> SystemHealthResponse? {
        try? await fetchHealth(accessToken)
    }

    private func fetchOptionalPortfolioSymbols(_ accessToken: String) async -> Set<String>? {
        try? await fetchPortfolioSymbols(accessToken)
    }

    func isInPortfolio(_ symbol: String) -> Bool {
        portfolioSymbols.contains(symbol.uppercased())
    }

    private func persist(_ response: RankingsTopResponse) {
        guard let data = try? Self.apiEncoder.encode(response) else { return }
        UserDefaults.standard.set(data, forKey: Self.cacheKey)
    }

    private func loadCached() -> RankingsTopResponse? {
        guard let data = UserDefaults.standard.data(forKey: Self.cacheKey) else { return nil }
        return try? Self.apiDecoder.decode(RankingsTopResponse.self, from: data)
    }
}
