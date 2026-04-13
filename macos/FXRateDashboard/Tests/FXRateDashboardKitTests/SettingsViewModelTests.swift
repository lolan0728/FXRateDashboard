import Foundation
import XCTest
@testable import FXRateDashboardKit

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testLoadWithSavedTokenShowsMaskedValueAndKeepsExistingTokenWhenUnchanged() throws {
        let viewModel = SettingsViewModel()
        let token = "abcd1234efgh5678"
        viewModel.load(
            from: AppSettings(baseCurrency: "JPY", quoteCurrency: "CNY", baseAmount: 10_000, refreshSeconds: 60),
            hasToken: true,
            maskedToken: SettingsViewModel.maskToken(token)
        )

        let built = try viewModel.buildSettings()

        XCTAssertFalse(viewModel.apiTokenText.isEmpty)
        XCTAssertNotEqual(viewModel.apiTokenText, token)
        XCTAssertEqual(viewModel.resolveTokenUpdate(), .unchanged)
        XCTAssertEqual(built.baseCurrency, "JPY")
        XCTAssertEqual(built.quoteCurrency, "CNY")
    }

    func testBuildSettingsWithUnknownCurrencyFailsValidation() {
        let viewModel = SettingsViewModel()
        viewModel.baseCurrency = "AAA"
        viewModel.quoteCurrency = "CNY"
        viewModel.baseAmountText = "100"
        viewModel.refreshSecondsText = "60"

        XCTAssertThrowsError(try viewModel.buildSettings())
    }

    func testBuildSettingsPreservesLoadedPlacementAndRange() throws {
        let viewModel = SettingsViewModel()
        viewModel.load(
            from: AppSettings(
                baseCurrency: "JPY",
                quoteCurrency: "CNY",
                baseAmount: 100,
                activeRange: .month,
                refreshSeconds: 60,
                windowOriginX: 123,
                windowOriginY: 456
            ),
            hasToken: false,
            maskedToken: nil
        )
        viewModel.baseAmountText = "200"

        let built = try viewModel.buildSettings()

        XCTAssertEqual(built.activeRange, .month)
        XCTAssertEqual(built.windowOriginX, 123)
        XCTAssertEqual(built.windowOriginY, 456)
    }
}
