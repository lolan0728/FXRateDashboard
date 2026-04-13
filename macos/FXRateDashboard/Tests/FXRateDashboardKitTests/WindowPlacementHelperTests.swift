import CoreGraphics
import XCTest
@testable import FXRateDashboardKit

final class WindowPlacementHelperTests: XCTestCase {
    func testCalculateClampedTopLeftShiftsLeftWhenExpansionWouldOverflowRightEdge() {
        let result = WindowPlacementHelper.calculateClampedTopLeft(
            workArea: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            currentBounds: CGRect(x: 1600, y: 40, width: 196, height: 122),
            targetSize: CGSize(width: 404, height: 410)
        )

        XCTAssertEqual(result.x, 1516)
        XCTAssertEqual(result.y, 40)
    }

    func testCalculateClampedTopLeftAnchorsToBottomEdgeWhenDockedBottom() {
        let result = WindowPlacementHelper.calculateClampedTopLeft(
            workArea: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            currentBounds: CGRect(x: 1200, y: 958, width: 236, height: 122),
            targetSize: CGSize(width: 404, height: 410)
        )

        XCTAssertEqual(result.x, 1200)
        XCTAssertEqual(result.y, 670)
    }
}
