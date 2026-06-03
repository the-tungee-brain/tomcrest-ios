import Foundation
import Observation

@MainActor
@Observable
final class TopMoversViewModel {
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
    private(set) var companyNames: [String: String] = [:]
    private(set) var breakdownLoadingSymbols: Set<String> = []
    private var breakdownTask: Task<Void, Never>?

    private let auth: AuthSession
    private var pollTask: Task<Void, Never>?
    private var namesTask: Task<Void, Never>?
    private var prefetchTask: Task<Void, Never>?
    private static let cacheKey = "rankings_top_v1"
    private static let companyNamePrefetchLimit = 12
    private static let breakdownPrefetchLimit = 5

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

    init(auth: AuthSession) {
        self.auth = auth
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
        namesTask?.cancel()
        namesTask = nil
        breakdownTask?.cancel()
        breakdownTask = nil
        prefetchTask?.cancel()
        prefetchTask = nil
    }

    var hasMlMetrics: Bool {
        TopMoversFormatting.rankingsHaveMlMetrics(items)
    }

    func refresh() async {
        guard let token = auth.accessToken else { return }
        if items.isEmpty { isLoading = true }
        errorMessage = nil
        defer { isLoading = false }

        var rankingsResult: RankingsTopResponse?
        var healthResult: SystemHealthResponse?
        var fetchErrors: [String] = []

        do {
            rankingsResult = try await RankingService.fetchRankingsTop(accessToken: token)
        } catch let error as APIError {
            fetchErrors.append(error.errorDescription ?? "Rankings failed.")
        } catch {
            fetchErrors.append(error.localizedDescription)
        }

        do {
            healthResult = try await RankingService.fetchSystemHealth(accessToken: token)
        } catch {
            // Health is optional for the list; regime may come from rankings.
        }

        if let rankingsResult {
            items = rankingsResult.items
            regimeId = healthResult?.regimeId ?? rankingsResult.regimeId
            asOfDate = rankingsResult.asOfDate
            updatedAt = healthResult?.lastRankingRunAt ?? rankingsResult.timestamp
            systemStatus = healthResult?.systemStatus ?? "ok"
            universeSize = healthResult?.universeSize
            persist(rankingsResult)
            errorMessage = nil
        } else if items.isEmpty, let cached = loadCached() {
            items = cached.items
            regimeId = cached.regimeId
            asOfDate = cached.asOfDate
            updatedAt = cached.timestamp
            errorMessage = fetchErrors.first
        } else if !items.isEmpty {
            errorMessage = fetchErrors.first
        } else {
            errorMessage = fetchErrors.first ?? "Could not load rankings."
        }

        if let portfolio = try? await RankingService.fetchPortfolioSymbols(accessToken: token) {
            portfolioSymbols = portfolio
        }

        prefetchCompanyNames(accessToken: token)
        prefetchTopBreakdowns(accessToken: token)
    }

    func topUniverseLabel(for item: RankingItem) -> String {
        TopMoversFormatting.topUniverseLabel(
            rank: item.rank,
            universeSize: universeSize,
            listCount: items.count
        )
    }

    func trendDisplayForRow(for symbol: String) -> TrendDisplay {
        let key = symbol.uppercased()
        let rank = items.first(where: { $0.symbol.uppercased() == key })?.rank ?? items.count
        return TopMoversFormatting.trendDisplayForRow(
            rank: rank,
            listCount: max(items.count, 1)
        )
    }

    func trendDisplayForDetail(symbol: String) -> TrendDisplay? {
        guard let intel = patternIntelligenceBySymbol[symbol.uppercased()] else {
            return nil
        }
        return TopMoversFormatting.trendDisplayFromIntelligence(intel)
    }

    func signalStrength(for symbol: String) -> String? {
        TopMoversFormatting.signalStrengthLabel(
            scores: patternIntelligenceBySymbol[symbol.uppercased()]?.scores
        )
    }

    func keySignals(for symbol: String) -> [KeySignalItem] {
        TopMoversFormatting.keySignals(
            from: patternIntelligenceBySymbol[symbol.uppercased()]
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

    func toggleExpanded(_ symbol: String) {
        let key = symbol.uppercased()
        if expandedSymbol == key {
            expandedSymbol = nil
            breakdownTask?.cancel()
            breakdownTask = nil
        } else {
            expandedSymbol = key
            breakdownTask?.cancel()
            breakdownTask = Task { [weak self] in
                await self?.loadScoreBreakdown(symbol: key)
            }
        }
    }

    func companyName(for symbol: String) -> String? {
        let key = symbol.uppercased()
        return companyNames[key]
    }

    private func prefetchCompanyNames(accessToken: String) {
        namesTask?.cancel()
        let symbols = items
            .prefix(Self.companyNamePrefetchLimit)
            .map { $0.symbol.uppercased() }
        guard !symbols.isEmpty else { return }

        namesTask = Task { [weak self] in
            guard let self else { return }
            await loadCompanyNames(symbols: symbols, accessToken: accessToken)
        }
    }

    private func loadCompanyNames(symbols: [String], accessToken: String) async {
        await withTaskGroup(of: (String, String?).self) { group in
            for symbol in symbols {
                group.addTask {
                    guard !Task.isCancelled else { return (symbol, nil) }
                    guard let item = try? await RankingService.lookupSymbol(
                        symbol: symbol,
                        accessToken: accessToken
                    ) else {
                        return (symbol, nil)
                    }
                    let title = item.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard let title, !title.isEmpty else { return (symbol, nil) }
                    return (symbol, title)
                }
            }

            for await (symbol, name) in group {
                if Task.isCancelled { break }
                if let name {
                    companyNames[symbol] = name
                }
            }
        }
    }

    func breakdownSegments(for symbol: String) -> [ScoreBreakdownSegment] {
        let scores = patternIntelligenceBySymbol[symbol.uppercased()]?.scores
        return TopMoversFormatting.segments(from: scores)
    }

    /// Score bars use `/pattern/intelligence` only — not the full research overview bundle.
    private func prefetchTopBreakdowns(accessToken: String) {
        prefetchTask?.cancel()
        let symbols = items
            .prefix(Self.breakdownPrefetchLimit)
            .map { $0.symbol.uppercased() }
        guard !symbols.isEmpty else { return }

        prefetchTask = Task { [weak self] in
            guard let self else { return }
            for symbol in symbols {
                if Task.isCancelled { break }
                await loadScoreBreakdown(symbol: symbol)
            }
        }
    }

    private func loadScoreBreakdown(symbol: String) async {
        guard let token = auth.accessToken else { return }
        let key = symbol.uppercased()
        if patternIntelligenceBySymbol[key] != nil { return }

        breakdownLoadingSymbols.insert(key)
        defer { breakdownLoadingSymbols.remove(key) }

        do {
            let payload = try await PatternPredictionService.fetchIntelligence(
                symbol: key,
                accessToken: token
            )
            patternIntelligenceBySymbol[key] = payload
        } catch {
            // Breakdown is optional; list remains usable.
        }
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
