import XCTest
@testable import BillDueTracker

final class BillExtractionServiceTests: XCTestCase {
    func testExtractsDueDayAmountAndProviderFromText() {
        let text = "Your Singtel bill is due on 18. Total amount S$72.60."
        let result = BillExtractionService.extractFromText(text)

        XCTAssertEqual(result.dueDay, 18)
        XCTAssertEqual(result.providerHint, "Singtel")
        XCTAssertNotNil(result.amount)
        XCTAssertEqual(result.amount ?? 0, 72.60, accuracy: 0.01)
        XCTAssertEqual(result.confidence, .high)
    }

    func testReturnsLowConfidenceWhenNoSignalsPresent() {
        let text = "hello world"
        let result = BillExtractionService.extractFromText(text)

        XCTAssertNil(result.dueDay)
        XCTAssertNil(result.amount)
        XCTAssertEqual(result.confidence, .low)
    }
}
