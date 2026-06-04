import Foundation
import XCTest
@testable import Tomcrest

final class WatchlistVersioningTests: XCTestCase {
    func testWorkspaceResponseDecodesOptionalVersion() throws {
        let data = Data("""
        {
          "folders": [],
          "asOf": "2026-06-04T12:00:00Z",
          "workspaceVersion": 4
        }
        """.utf8)

        let response = try JSONDecoder().decode(WatchlistWorkspaceResponse.self, from: data)

        XCTAssertEqual(response.workspaceVersion, 4)
        XCTAssertTrue(response.folders.isEmpty)
    }

    func testWorkspaceResponseAllowsMissingVersion() throws {
        let data = Data("""
        {
          "folders": [],
          "asOf": "2026-06-04T12:00:00Z"
        }
        """.utf8)

        let response = try JSONDecoder().decode(WatchlistWorkspaceResponse.self, from: data)

        XCTAssertNil(response.workspaceVersion)
        XCTAssertTrue(response.folders.isEmpty)
    }

    func testSyncRequestEncodesBaseVersionOnlyWhenKnown() throws {
        let folder = WatchlistFolder(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "Tech",
            iconName: "star.fill",
            symbols: [],
            swatchID: "slate",
            accentHex: nil,
            isPinned: true,
            isCollapsed: false,
            sortOrder: 0
        )
        let encoder = JSONEncoder()

        let versioned = WatchlistAPIMapping.syncRequest(from: [folder], baseVersion: 7)
        let versionedJSON = try JSONSerialization.jsonObject(
            with: encoder.encode(versioned)
        ) as? [String: Any]

        let legacy = WatchlistAPIMapping.syncRequest(from: [folder], baseVersion: nil)
        let legacyJSON = try JSONSerialization.jsonObject(
            with: encoder.encode(legacy)
        ) as? [String: Any]

        XCTAssertEqual(versionedJSON?["baseVersion"] as? Int, 7)
        XCTAssertNil(legacyJSON?["baseVersion"])
    }

    func testAPIClientParsesWatchlistConflict() async throws {
        let api = APIClient.mocking(
            statusCode: 409,
            body: """
            {
              "detail": {
                "code": "watchlist_version_conflict",
                "message": "Changed elsewhere.",
                "currentVersion": 3,
                "baseVersion": 2
              }
            }
            """
        )
        let payload = WatchlistWorkspaceSyncRequest(folders: [], baseVersion: 2)

        do {
            let _: WatchlistWorkspaceResponse = try await api.put(
                "/watchlist/workspace",
                body: payload,
                accessToken: "token"
            )
            XCTFail("Expected watchlist conflict")
        } catch let APIError.watchlistConflict(currentVersion, baseVersion, message) {
            XCTAssertEqual(currentVersion, 3)
            XCTAssertEqual(baseVersion, 2)
            XCTAssertEqual(message, "Changed elsewhere.")
        } catch {
            XCTFail("Expected watchlist conflict, got \(error)")
        }
    }
}

@MainActor
final class WatchlistStoreVersioningTests: XCTestCase {
    func testConflictPreservesLocalFoldersAndPausesSync() async throws {
        let auth = AuthSession(saveAccessToken: { _ in })
        try auth.completeSignIn(accessToken: "token")

        var fetchCalls = 0
        var syncPayloads: [WatchlistWorkspaceSyncRequest] = []
        let store = WatchlistStore(
            fetchWorkspace: { _, _ in
                fetchCalls += 1
                if fetchCalls == 1 {
                    return WatchlistWorkspaceResponse(workspaceVersion: 1)
                }
                throw APIError.httpStatus(-1, message: "Follow-up fetch failed.")
            },
            syncWorkspace: { payload, _ in
                syncPayloads.append(payload)
                throw APIError.watchlistConflict(
                    currentVersion: 2,
                    baseVersion: payload.baseVersion,
                    message: "Changed elsewhere."
                )
            }
        )
        store.bind(auth: auth)

        await store.load(localSymbols: ["AAPL"], includeQuotes: false)

        XCTAssertEqual(store.workspaceVersion, 2)
        XCTAssertTrue(store.syncBlockedByConflict)
        XCTAssertEqual(store.errorMessage, "Changed elsewhere.")
        XCTAssertEqual(store.allTickers, ["AAPL"])
        XCTAssertNil(store.latestServerFoldersAfterConflict)
        XCTAssertEqual(syncPayloads.map(\.baseVersion), [1])

        store.addFolder(name: "Blocked", iconName: "folder.fill", swatchID: "slate")
        try await Task.sleep(for: .milliseconds(800))

        XCTAssertEqual(syncPayloads.count, 1)
    }

    func testRetryAfterConflictUsesConflictCurrentVersionWhenFollowUpFetchFails() async throws {
        let auth = AuthSession(saveAccessToken: { _ in })
        try auth.completeSignIn(accessToken: "token")

        var fetchCalls = 0
        var syncPayloads: [WatchlistWorkspaceSyncRequest] = []
        let store = WatchlistStore(
            fetchWorkspace: { _, _ in
                fetchCalls += 1
                if fetchCalls == 1 {
                    return WatchlistWorkspaceResponse(workspaceVersion: 1)
                }
                throw APIError.httpStatus(-1, message: "Follow-up fetch failed.")
            },
            syncWorkspace: { payload, _ in
                syncPayloads.append(payload)
                if syncPayloads.count == 1 {
                    throw APIError.watchlistConflict(
                        currentVersion: 2,
                        baseVersion: payload.baseVersion,
                        message: "Changed elsewhere."
                    )
                }
                return WatchlistWorkspaceResponse(workspaceVersion: 3)
            }
        )
        store.bind(auth: auth)

        await store.load(localSymbols: ["AAPL"], includeQuotes: false)
        await store.retrySyncAfterConflict()

        XCTAssertEqual(syncPayloads.map(\.baseVersion), [1, 2])
        XCTAssertEqual(store.workspaceVersion, 3)
        XCTAssertFalse(store.syncBlockedByConflict)
        XCTAssertEqual(store.allTickers, ["AAPL"])
    }

    func testQuoteRefreshDoesNotRegressWorkspaceVersion() async throws {
        let auth = AuthSession(saveAccessToken: { _ in })
        try auth.completeSignIn(accessToken: "token")

        var fetchCalls = 0
        let store = WatchlistStore(
            fetchWorkspace: { _, includeQuotes in
                fetchCalls += 1
                if fetchCalls == 1 {
                    return WatchlistWorkspaceResponse(
                        folders: [Self.folderDTO()],
                        workspaceVersion: 5
                    )
                }
                if includeQuotes {
                    return WatchlistWorkspaceResponse(
                        folders: [Self.folderDTO()],
                        workspaceVersion: nil
                    )
                }
                return WatchlistWorkspaceResponse(workspaceVersion: 5)
            },
            syncWorkspace: { _, _ in
                XCTFail("Quote refresh should not sync")
                return WatchlistWorkspaceResponse()
            }
        )
        store.bind(auth: auth)

        await store.load(includeQuotes: false)
        await store.refreshQuotes()

        XCTAssertEqual(store.workspaceVersion, 5)
    }

    private static func folderDTO() -> WatchlistFolderDTO {
        WatchlistFolderDTO(
            id: "00000000-0000-0000-0000-000000000001",
            name: "Tech",
            iconName: "star.fill",
            swatchID: "slate",
            accentHex: nil,
            isPinned: true,
            isCollapsed: false,
            sortOrder: 0,
            createdAt: nil,
            symbols: [
                WatchlistSymbolDTO(
                    id: "00000000-0000-0000-0000-000000000002",
                    ticker: "AAPL",
                    sortOrder: 0,
                    companyName: "Apple Inc.",
                    price: 190,
                    dayChange: 1,
                    dayChangePercent: 0.5,
                    createdAt: nil
                ),
            ]
        )
    }
}

private final class MockURLProtocol: URLProtocol {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var body = Data()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private extension APIClient {
    static func mocking(statusCode: Int, body: String) -> APIClient {
        MockURLProtocol.statusCode = statusCode
        MockURLProtocol.body = Data(body.utf8)

        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        return APIClient(
            config: APIConfiguration(baseURL: URL(string: "https://example.test")!),
            standardSession: session,
            longRunningSession: session
        )
    }
}
