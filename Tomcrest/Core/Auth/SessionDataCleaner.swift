import Foundation

enum SessionDataCleaner {
    @MainActor
    static func clearLocalUserData(
        watchlistStore: WatchlistStore,
        researchBookmarks: ResearchSymbolBookmarks,
        account: AccountContext,
        bootstrap: AppBootstrapState
    ) {
        watchlistStore.reset()
        researchBookmarks.reload()
        account.clearSession()
        bootstrap.clearPreloadedSession()
        OnboardingStorage.clearAll()
    }
}
