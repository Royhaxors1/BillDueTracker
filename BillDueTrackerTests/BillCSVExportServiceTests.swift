import XCTest
@testable import BillDueTracker

final class BillCSVExportServiceTests: XCTestCase {
    func testCSVIncludesHeaderAndSortedRows() {
        let older = BillItem(
            category: .utilityBill,
            providerName: "SP Group",
            nickname: "Home",
            dueDay: 10,
            billingCadence: .monthly,
            expectedAmount: 42.5,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let newer = BillItem(
            category: .telcoBill,
            providerName: "Singtel",
            nickname: "Mobile",
            dueDay: 20,
            billingCadence: .monthly,
            expectedAmount: 88.0,
            updatedAt: Date(timeIntervalSince1970: 1_700_010_000)
        )

        let csv = BillCSVExportService.csvString(for: [older, newer])
        let rows = csv.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        XCTAssertEqual(rows.first, BillCSVExportService.header)
        XCTAssertEqual(rows.count, 3)
        XCTAssertTrue(rows[1].contains("\"Singtel\""))
        XCTAssertTrue(rows[2].contains("\"SP Group\""))
        XCTAssertTrue(rows[1].contains(",88.00,"))
    }

    func testCSVEscapesQuotesAndCommas() {
        let bill = BillItem(
            category: .subscriptionDue,
            providerName: "ACME \"Power\", Ltd",
            nickname: "",
            dueDay: 5,
            billingCadence: .yearly,
            expectedAmount: nil,
            updatedAt: Date(timeIntervalSince1970: 1_700_020_000)
        )

        let csv = BillCSVExportService.csvString(for: [bill])

        XCTAssertTrue(csv.contains("\"ACME \"\"Power\"\", Ltd\""))
        XCTAssertTrue(csv.contains("\"\",\"Subscription\",5,"))
    }
}
