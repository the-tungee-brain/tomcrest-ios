import Foundation

@MainActor
@Observable
final class EmergingLeadersViewModel {
    private let auth: AuthSession

    var items: [EmergingLeaderItem] = []
    var metaLine: String?
    var isLoading = false
    var errorMessage: String?
    var expandedSymbol: String?

    private var pollTask: Task<Void, Never>?

    init(auth: AuthSession) {
        self.auth = auth
    }

    func start() {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(for: .seconds(120))
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        guard let accessToken = auth.accessToken, !accessToken.isEmpty else {
            errorMessage = "Sign in to view emerging leaders."
            return
        }
        isLoading = items.isEmpty
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await EmergingLeadersService.fetch(
                accessToken: accessToken,
                limit: 20
            )
            items = response.items
            metaLine =
                "Scanned \(response.universeScanned) · \(response.symbolsWithData) with OHLCV · excluded \(response.excludedTopMovers) top movers"
            if let expandedSymbol,
               !items.contains(where: { $0.symbol.uppercased() == expandedSymbol.uppercased() }) {
                self.expandedSymbol = nil
            }
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            if items.isEmpty {
                items = []
            }
        }
    }

    func collapseExpanded() {
        expandedSymbol = nil
    }

    func toggleExpanded(_ symbol: String) {
        let key = symbol.uppercased()
        if expandedSymbol == key {
            expandedSymbol = nil
        } else {
            expandedSymbol = key
        }
    }
}
