import XCTest
@testable import BillDueTracker

@MainActor
final class EntitlementStateTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "EntitlementStateTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testDefaultsToFreeWhenNoPersistedData() {
        let state = EntitlementState(defaults: defaults)

        XCTAssertEqual(state.tier, .free)
        XCTAssertFalse(state.isPro)
        XCTAssertNil(state.renewalDate)
    }

    func testLoadsPersistedTierFromDefaults() {
        defaults.set(SubscriptionTier.pro.rawValue, forKey: "subscription.tier")
        let state = EntitlementState(defaults: defaults)

        XCTAssertEqual(state.tier, .pro)
        XCTAssertTrue(state.isPro)
    }

    func testHasAccessForFreeTierBlocksProFeatures() {
        let state = EntitlementState(defaults: defaults)

        XCTAssertFalse(state.hasAccess(to: .csvExport))
        XCTAssertFalse(state.hasAccess(to: .monthlyInsights))
    }

    func testProductUnavailableErrorUsesProvidedDetail() {
        let error = EntitlementError.productUnavailable("Missing product in App Store Connect.")

        XCTAssertEqual(error.errorDescription, "Missing product in App Store Connect.")
    }

    func testNoActiveSubscriptionRestoreErrorDescription() {
        let error = EntitlementError.noActiveSubscription

        XCTAssertEqual(
            error.errorDescription,
            "No active Pro subscription was found to restore for this Apple Account."
        )
    }
}
