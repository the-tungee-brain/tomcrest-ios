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

    func run(auth: AuthSession, account: AccountContext) async {
        guard phase == .coldStart else { return }
        phase = .bootstrapping

        auth.bootstrap()
        await configureAPIClients(auth: auth)

        let clock = ContinuousClock()
        let started = clock.now

        Task { await performWarmUp(auth: auth, account: account) }

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

    private func performWarmUp(auth: AuthSession, account: AccountContext) async {
        defer { warmUpFinished = true }

        guard auth.phase == .signedIn, let accessToken = auth.accessToken else { return }

        let portfolio = PortfolioViewModel(auth: auth)
        portfolioViewModel = portfolio

        async let planLoad: Void = account.loadPlan(accessToken: accessToken)
        async let portfolioLoad: Void = portfolio.loadIfNeeded()
        _ = await (planLoad, portfolioLoad)
    }

    private func configureAPIClients(auth: AuthSession) async {
        let refresh: @Sendable () async -> String? = { [auth] in
            await auth.refreshAccessToken()
        }
        await APIClient.shared.setTokenRefresher(refresh)
        StreamingAPIClient.setTokenRefresher(refresh)
    }
}
