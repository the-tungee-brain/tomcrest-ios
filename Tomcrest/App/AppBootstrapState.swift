import Foundation
import SwiftUI

enum AppBootstrapPhase: Equatable {
    case coldStart
    case bootstrapping
    case ready
}

@MainActor
@Observable
final class AppBootstrapState {
    private(set) var phase: AppBootstrapPhase = .coldStart
    private(set) var showBrandShell = true
    private(set) var timedOut = false
    private(set) var portfolioViewModel: PortfolioViewModel?

    private var warmUpFinished = false

    private static let minimumBrandDisplay: Duration = .milliseconds(900)
    private static let maximumBrandDisplay: Duration = .milliseconds(2750)

    func run(auth: AuthSession, account: AccountContext, watchlistStore: WatchlistStore) async {
        guard phase == .coldStart else { return }
        phase = .bootstrapping

        auth.bootstrap()
        watchlistStore.bind(auth: auth)
        await configureAPIClients(auth: auth)

        let clock = ContinuousClock()
        let started = clock.now

        Task { await performWarmUp(auth: auth, account: account, watchlistStore: watchlistStore) }

        try? await Task.sleep(for: Self.minimumBrandDisplay)

        while !warmUpFinished {
            if clock.now - started >= Self.maximumBrandDisplay {
                timedOut = true
                break
            }
            try? await Task.sleep(for: .milliseconds(40))
        }

        withAnimation(BrandMotion.shellCrossfade) {
            showBrandShell = false
            phase = .ready
        }
    }

    private func performWarmUp(auth: AuthSession, account: AccountContext, watchlistStore: WatchlistStore) async {
        defer { warmUpFinished = true }

        async let watchlistLoad: Void = watchlistStore.load(
            localSymbols: ResearchSymbolStorage.watchlist(),
            includeQuotes: false
        )

        guard auth.phase == .signedIn, let accessToken = auth.accessToken else {
            _ = await watchlistLoad
            return
        }

        let portfolio = PortfolioViewModel(auth: auth)
        portfolioViewModel = portfolio

        Task { await portfolio.loadIfNeeded() }
        async let planLoad: Void = account.loadPlan(accessToken: accessToken)
        _ = await (planLoad, watchlistLoad)
    }

    func clearPreloadedSession() {
        portfolioViewModel = nil
    }

    private func configureAPIClients(auth: AuthSession) async {
        let refresh: @Sendable () async -> String? = { [auth] in
            await auth.refreshAccessToken()
        }
        await APIClient.shared.setTokenRefresher(refresh)
        StreamingAPIClient.setTokenRefresher(refresh)
    }
}
