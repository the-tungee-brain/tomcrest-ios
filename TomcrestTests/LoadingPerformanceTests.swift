import XCTest
@testable import Tomcrest

private actor RequestRecorder {
    private var values: [String] = []

    func record(_ value: String) {
        values.append(value)
    }

    func snapshot() -> [String] {
        values
    }
}

@MainActor
final class LoadingPerformanceTests: XCTestCase {
    func testTopMoversAppliesRankingsBeforeMetadataAndBoundsPatternPrefetch() async throws {
        let auth = AuthSession(saveAccessToken: { _ in })
        try auth.completeSignIn(accessToken: "token")

        let patternRecorder = RequestRecorder()
        let rankings = try Self.rankings(symbols: (1 ... 20).map { "S\($0)" })
        let viewModel = TopMoversViewModel(
            auth: auth,
            fetchRankings: { _ in rankings },
            fetchHealth: { _ in
                try await Task.sleep(for: .milliseconds(200))
                return SystemHealthResponse(
                    apiVersion: "v1",
                    systemStatus: "ok",
                    regimeId: "health-regime",
                    lastRankingRunAt: "health-time",
                    universeSize: 500
                )
            },
            fetchPortfolioSymbols: { _ in
                try await Task.sleep(for: .milliseconds(200))
                return ["S1"]
            },
            fetchPatternIntelligence: { symbol, _ in
                await patternRecorder.record(symbol)
                throw APIError.httpStatus(503, message: "Skipped in test")
            }
        )

        await viewModel.refresh()

        XCTAssertEqual(viewModel.items.map(\.symbol).prefix(2), ["S1", "S2"])
        XCTAssertEqual(viewModel.regimeId, "ranking-regime")
        XCTAssertNil(viewModel.universeSize)
        XCTAssertFalse(viewModel.isLoading)

        try await Task.sleep(for: .milliseconds(260))

        XCTAssertEqual(viewModel.regimeId, "health-regime")
        XCTAssertEqual(viewModel.universeSize, 500)
        XCTAssertTrue(viewModel.isInPortfolio("S1"))

        let prefetched = await patternRecorder.snapshot()
        XCTAssertEqual(Set(prefetched), Set(["S1", "S2", "S3", "S4"]))
        XCTAssertFalse(prefetched.contains("S20"))
    }

    func testMomentumInitialLoadSkipsHistoryAndPaperUntilRequested() async throws {
        let auth = AuthSession(saveAccessToken: { _ in })
        try auth.completeSignIn(accessToken: "token")

        let recorder = RequestRecorder()
        let viewModel = MomentumBreakoutAlertsViewModel(
            auth: auth,
            fetchFeatureStatus: { _ in
                await recorder.record("feature")
                return MomentumBreakoutFeatureStatusResponse(
                    disclaimer: "",
                    flags: MomentumBreakoutFeatureFlagsDto(
                        alertsEnabled: true,
                        alertCreationEnabled: true,
                        alertNotificationsEnabled: true,
                        paperAnalyticsEnabled: true
                    )
                )
            },
            fetchActiveAlerts: { _ in
                await recorder.record("active")
                return MomentumBreakoutAlertListResponse(disclaimer: "disc", alerts: [])
            },
            fetchAlertHistory: { _ in
                await recorder.record("history")
                return MomentumBreakoutAlertListResponse(disclaimer: "disc", alerts: [])
            },
            fetchScan: { _, _, _ in
                await recorder.record("scan")
                return MomentumBreakoutScanResponse(
                    scanTime: "2026-06-04T12:00:00Z",
                    totalSymbolsScanned: 10,
                    validSetupsFound: 0,
                    tradableCandidatesFound: 0,
                    blockedCandidatesCount: 0,
                    candidatesFound: 0,
                    candidates: []
                )
            },
            fetchPaperSummary: { _ in
                await recorder.record("paper-summary")
                return PaperTradePerformanceSummaryResponse(
                    meta: PaperTradePerformanceMetaDto(
                        label: "Paper",
                        disclaimer: "",
                        source: "test"
                    ),
                    summary: PaperTradeSummaryDto(
                        totalAlerts: 0,
                        triggeredAlerts: 0,
                        expiredAlerts: 0,
                        winRate: nil,
                        averageWin: nil,
                        averageLoss: nil,
                        expectancy: nil,
                        profitFactor: nil,
                        averageHoldingDays: nil,
                        maxDrawdown: nil,
                        currentOpenTrades: 0
                    ),
                    byRiskGate: nil
                )
            },
            fetchPaperTrades: { _ in
                await recorder.record("paper-trades")
                return PaperTradePerformanceTradesResponse(
                    meta: PaperTradePerformanceMetaDto(
                        label: "Paper",
                        disclaimer: "",
                        source: "test"
                    ),
                    trades: []
                )
            }
        )

        await viewModel.loadAll()

        var calls = await recorder.snapshot()
        XCTAssertTrue(calls.contains("feature"))
        XCTAssertTrue(calls.contains("active"))
        XCTAssertTrue(calls.contains("scan"))
        XCTAssertFalse(calls.contains("history"))
        XCTAssertFalse(calls.contains("paper-summary"))
        XCTAssertFalse(calls.contains("paper-trades"))

        await viewModel.loadHistoryIfNeeded()
        await viewModel.loadPaperPerformanceIfNeeded()

        calls = await recorder.snapshot()
        XCTAssertEqual(calls.filter { $0 == "history" }.count, 1)
        XCTAssertEqual(calls.filter { $0 == "paper-summary" }.count, 1)
        XCTAssertEqual(calls.filter { $0 == "paper-trades" }.count, 1)
    }

    private static func rankings(symbols: [String]) throws -> RankingsTopResponse {
        let items = symbols.enumerated().map { index, symbol in
            """
            {"symbol":"\(symbol)","rank":\(index + 1),"final_score":\(100 - index)}
            """
        }.joined(separator: ",")
        let data = Data("""
        {
          "api_version": "v1",
          "timestamp": "ranking-time",
          "run_id": "run-1",
          "as_of_date": "2026-06-04",
          "regime_id": "ranking-regime",
          "items": [\(items)]
        }
        """.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(RankingsTopResponse.self, from: data)
    }
}
