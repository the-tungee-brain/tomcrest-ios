import Foundation

@MainActor
@Observable
final class SymbolPositionViewModel {
    let symbol: String

    private(set) var positions: [Position] = []
    private(set) var recentOrders: [RecentOrderEntry] = []
    private(set) var proactiveAlerts: [ProactiveAlert] = []
    private(set) var portfolioBrief: PortfolioIntelligence?
    private(set) var suggestedActions: [SuggestedAnalysisAction] = []
    private(set) var isLoading = false
    private(set) var recentOrdersLoading = false
    private(set) var loadError: String?
    private(set) var recentOrdersError: String?
    private(set) var schwabConnected: Bool?
    private(set) var symbolAnalysisLoading = false
    private(set) var symbolAnalysisStatus: String?
    private(set) var symbolAnalysisError: String?
    private(set) var structuredAnalysis: StructuredAnalysis?
    private(set) var symbolPrecomputed: SymbolAnalysisPrecomputed?
    private var loaded = false

    private var chatAccountPayload: JSONPassThrough?
    private var chatPositionsPayload: JSONPassThrough?

    private let auth: AuthSession
    private let api: APIClient

    init(symbol: String, auth: AuthSession, api: APIClient = .shared) {
        self.symbol = symbol.uppercased()
        self.auth = auth
        self.api = api
    }

    var hasPosition: Bool {
        !positions.isEmpty
    }

    var hasOptionPositions: Bool {
        SymbolOptionsHelpers.symbolHasOptionPositions(positions)
    }

    var symbolAlerts: [ProactiveAlert] {
        IntelligenceHelpers.symbolAlerts(
            symbol: symbol,
            proactive: proactiveAlerts,
            brief: portfolioBrief
        )
    }

    var taxAlertItems: [TaxAlertItem] {
        IntelligenceHelpers.collectTaxAlertItems(
            alerts: PortfolioAlerts.merged(proactive: proactiveAlerts, brief: portfolioBrief),
            suggestedActions: suggestedActions,
            symbol: symbol
        )
    }

    var tradeSuggestedActions: [SuggestedAnalysisAction] {
        IntelligenceHelpers.pickSuggestedActions(
            IntelligenceHelpers.filterNonTaxSuggestedActions(suggestedActions)
        )
    }

    func loadIfNeeded(force: Bool = false) async {
        guard auth.accessToken != nil else { return }
        if loaded, !force { return }

        isLoading = true
        loadError = nil
        defer { isLoading = false }

        let connected = await auth.fetchSchwabStatus()
        schwabConnected = connected
        guard connected == true else { return }

        do {
            let result = try await PortfolioService.fetchPositions(
                accessToken: auth.accessToken!,
                api: api
            )
            chatAccountPayload = result.accountPayload
            chatPositionsPayload = result.positionsPayload
            positions = result.response.flattenedPositions
                .filter { $0.displaySymbol.uppercased() == symbol }
                .sorted { $0.marketValue > $1.marketValue }
            proactiveAlerts = result.response.proactiveAlerts ?? []
            portfolioBrief = result.response.portfolioBrief
            loaded = true
            auth.clearError()
            await loadRecentOrdersIfNeeded(force: force)
        } catch let error as APIError {
            loadError = error.errorDescription ?? "Could not load your Schwab positions."
        } catch {
            loadError = error.localizedDescription
        }
    }

    func runSymbolAnalysis() async {
        guard !symbolAnalysisLoading,
              let accessToken = auth.accessToken,
              let accountPayload = chatAccountPayload,
              let positionsPayload = chatPositionsPayload,
              hasPosition else { return }

        symbolAnalysisLoading = true
        symbolAnalysisError = nil
        symbolAnalysisStatus = "Reviewing your position…"
        defer { symbolAnalysisLoading = false }

        do {
            let response = try await PortfolioService.fetchStructuredSymbolAnalysis(
                account: accountPayload,
                positions: positionsPayload,
                symbol: symbol,
                accessToken: accessToken
            ) { [weak self] chunk in
                Task { @MainActor in
                    if chunk.localizedCaseInsensitiveContains("reviewing") ||
                        chunk.localizedCaseInsensitiveContains("pulling") {
                        self?.symbolAnalysisStatus = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            }
            structuredAnalysis = response.analysis
            symbolPrecomputed = response.symbolPrecomputed
            symbolAnalysisStatus = nil
            auth.clearError()
        } catch {
            symbolAnalysisError = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    func loadRecentOrdersIfNeeded(force: Bool = false) async {
        guard hasPosition, let accessToken = auth.accessToken else { return }
        if recentOrdersLoading { return }
        if !recentOrders.isEmpty, !force { return }

        recentOrdersLoading = true
        recentOrdersError = nil
        defer { recentOrdersLoading = false }

        do {
            let response = try await PortfolioService.fetchRecentOrders(
                accessToken: accessToken,
                symbol: symbol,
                daysBack: 30,
                api: api
            )
            recentOrders = response.orders
            suggestedActions = response.suggestedActions ?? []
        } catch let error as APIError {
            recentOrdersError = error.errorDescription ?? "Could not load recent trades."
        } catch {
            recentOrdersError = error.localizedDescription
        }
    }
}
