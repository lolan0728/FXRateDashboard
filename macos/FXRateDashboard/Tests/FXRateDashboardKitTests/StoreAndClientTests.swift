import Foundation
import XCTest
@testable import FXRateDashboardKit

final class StoreAndClientTests: XCTestCase {
    func testCacheStoreRoundTripsSnapshotJSON() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = AppPaths(
            applicationSupportDirectory: root,
            settingsFileURL: root.appendingPathComponent("settings.json"),
            cacheDirectoryURL: root.appendingPathComponent("cache", isDirectory: true)
        )
        let store = CacheStore(paths: paths)
        let snapshot = RateSeriesSnapshot(
            pair: "USD/CNY",
            range: .week,
            points: [
                RatePoint(timestampUTC: .now.addingTimeInterval(-3600), rate: 7.10),
                RatePoint(timestampUTC: .now, rate: 7.22)
            ],
            currentRate: 7.22,
            changeAbsolute: 0.12,
            changePercent: 1.6,
            asOfUTC: .now,
            isStale: false
        )

        try await store.saveSnapshot(snapshot)
        let reloaded = await store.loadSnapshot(pair: "USD/CNY", range: .week)

        XCTAssertEqual(reloaded?.pair, snapshot.pair)
        XCTAssertEqual(reloaded?.points.count, snapshot.points.count)
        XCTAssertEqual(reloaded?.currentRate, snapshot.currentRate)
    }

    func testWiseRateClientParsesTimestampWithoutColonInOffset() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.responseData = Data(#"[{"rate":7.2451,"source":"USD","target":"CNY","time":"2026-04-10T09:52:31+0000"}]"#.utf8)

        let session = URLSession(configuration: configuration)
        let client = WiseRateClient(session: session)

        let point = try await client.getCurrentRate(source: "USD", target: "CNY", token: "token")

        XCTAssertEqual(point.rate, Decimal(string: "7.2451"))
        XCTAssertEqual(point.timestampUTC, Date(timeIntervalSince1970: 1_744_280_351))
    }
}

private final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    static var responseData = Data()

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
