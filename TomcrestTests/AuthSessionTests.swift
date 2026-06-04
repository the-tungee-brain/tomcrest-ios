import XCTest
@testable import Tomcrest

@MainActor
final class AuthSessionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        KeychainTokenStore.delete()
    }

    override func tearDown() {
        KeychainTokenStore.delete()
        super.tearDown()
    }

    func testConcurrentRefreshesShareSingleRequest() async throws {
        var requestCount = 0
        let session = AuthSession(
            refreshAccessTokenRequest: { accessToken in
                requestCount += 1
                XCTAssertEqual(accessToken, "old-token")
                try await Task.sleep(for: .milliseconds(25))
                return AuthRefreshResponse(accessToken: "new-token")
            },
            saveAccessToken: { _ in }
        )
        try session.completeSignIn(accessToken: "old-token")

        async let first = session.refreshAccessToken()
        async let second = session.refreshAccessToken()
        async let third = session.refreshAccessToken()

        let results = await [first, second, third]

        XCTAssertEqual(results, ["new-token", "new-token", "new-token"])
        XCTAssertEqual(requestCount, 1)
        XCTAssertEqual(session.accessToken, "new-token")
    }

    func testFailedRefreshClearsSingleFlightTaskForLaterRetry() async throws {
        var requestCount = 0
        let session = AuthSession(
            refreshAccessTokenRequest: { _ in
                requestCount += 1
                if requestCount == 1 {
                    throw APIError.unauthorized
                }
                return AuthRefreshResponse(accessToken: "retry-token")
            },
            saveAccessToken: { _ in }
        )
        try session.completeSignIn(accessToken: "old-token")

        let failed = await session.refreshAccessToken()
        let retried = await session.refreshAccessToken()

        XCTAssertNil(failed)
        XCTAssertEqual(retried, "retry-token")
        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(session.accessToken, "retry-token")
    }
}
