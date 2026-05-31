import Foundation

@MainActor
@Observable
final class SymbolDepthViewModel {
    let symbol: String

    private(set) var earnings: EarningsListResponse?
    private(set) var dividends: DividendHistoryContext?
    private(set) var news: PressReleasesResponse?
    private(set) var fundamentals: FundamentalsBlock?

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
    }

    func loadIfNeeded(_ tab: ResearchTab, force: Bool = false) async {
        guard tab != .overview else { return }
        if !force, loadedTabs.contains(tab), loadingTab != tab { return }

        loadingTab = tab
        tabErrors[tab] = nil
        defer {
            if loadingTab == tab {
                loadingTab = nil
            }
        }

        do {
            switch tab {
            case .overview:
                break
            case .earnings:
                earnings = try await ResearchService.fetchEarningsList(symbol: symbol)
                if selectedHistoryEvent == nil {
                    selectedHistoryEvent = earnings?.history.first
                }
            case .news:
                guard let accessToken = auth.accessToken else {
                    throw APIError.missingToken
                }
                news = try await ResearchService.fetchPressReleases(
                    symbol: symbol,
                    accessToken: accessToken
                )
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
            }
            loadedTabs.insert(tab)
        } catch {
            tabErrors[tab] = (error as? APIError)?.errorDescription ?? error.localizedDescription
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
        await loadIfNeeded(tab, force: true)
        if tab == .earnings, let event = earnings?.history.first {
            selectedHistoryEvent = event
        }
    }
}
