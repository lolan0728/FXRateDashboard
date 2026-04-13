import Foundation
import XCTest
@testable import FXRateDashboardKit

final class RateMathTests: XCTestCase {
    func testCreateSnapshotComputesChangeFields() {
        let points = [
            RatePoint(timestampUTC: Date(timeIntervalSince1970: 1_744_243_200), rate: 7.10),
            RatePoint(timestampUTC: Date(timeIntervalSince1970: 1_744_329_600), rate: 7.35)
        ]

        let snapshot = RateMath.createSnapshot(pair: "USD/CNY", range: .day, points: points)

        XCTAssertEqual(snapshot.changeAbsolute, Decimal(string: "0.25"))
        XCTAssertEqual(snapshot.currentRate, Decimal(string: "7.35"))
        XCTAssertEqual(snapshot.changePercent.rounded(scale: 6), Decimal(string: "3.521127"))
    }

    func testDownsampleKeepsFirstAndLastPoint() {
        let points = (0..<20).map {
            RatePoint(timestampUTC: Date(timeIntervalSince1970: TimeInterval($0 * 60)), rate: Decimal($0))
        }

        let sampled = RateMath.downsample(points, maxPoints: 5)

        XCTAssertEqual(sampled.count, 5)
        XCTAssertEqual(sampled.first?.rate, points.first?.rate)
        XCTAssertEqual(sampled.last?.rate, points.last?.rate)
    }

    func testDetermineAxisDecimalPlacesIncreasesUntilLabelsAreDistinct() {
        let values: [Decimal] = [429.151, 429.154, 429.159]
        let decimals = RateMath.determineAxisDecimalPlaces(values: values)

        XCTAssertEqual(decimals, 3)
    }
}
