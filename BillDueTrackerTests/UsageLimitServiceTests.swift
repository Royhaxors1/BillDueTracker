import XCTest
@testable import BillDueTracker

final class UsageLimitServiceTests: XCTestCase {
    func testFreeTierBlocksBillCreationAtLimit() {
        let decision = UsageLimitService.canCreateBill(tier: .free, activeBillCount: UsageLimitService.freeActiveBillLimit)

        XCTAssertFalse(decision.isAllowed)
        XCTAssertNotNil(decision.message)
    }

    func testProTierAllowsBillCreationBeyondFreeLimit() {
        let decision = UsageLimitService.canCreateBill(tier: .pro, activeBillCount: 100)

        XCTAssertTrue(decision.isAllowed)
        XCTAssertNil(decision.message)
    }

    func testFeatureAccessRequiresProForExtractionAndInsights() {
        XCTAssertFalse(UsageLimitService.canUse(.extractionAutomation, tier: .free))
        XCTAssertFalse(UsageLimitService.canUse(.monthlyInsights, tier: .free))

        XCTAssertTrue(UsageLimitService.canUse(.extractionAutomation, tier: .pro))
        XCTAssertTrue(UsageLimitService.canUse(.monthlyInsights, tier: .pro))
    }
}
