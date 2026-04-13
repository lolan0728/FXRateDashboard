import Foundation
import XCTest
@testable import FXRateDashboardKit

final class RateQueryMapperTests: XCTestCase {
    func testMapHistoryQueryReturnsExpectedWindows() {
        let cases: [(TimeRangePreset, String, TimeInterval)] = [
            (.day, "minute", -86_400),
            (.week, "hour", -604_800),
            (.month, "day", -2_592_000),
            (.year, "day", -31_536_000)
        ]

        let mapper = RateQueryMapper()
        let anchor = Date(timeIntervalSince1970: 1_744_360_200)

        for (range, group, delta) in cases {
            let query = mapper.mapHistoryQuery(range, nowUTC: anchor)
            XCTAssertEqual(query.group, group)
            XCTAssertEqual(query.toUTC, anchor)
            XCTAssertEqual(query.fromUTC, anchor.addingTimeInterval(delta))
        }
    }
}
