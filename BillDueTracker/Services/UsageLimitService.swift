import Foundation

enum UsageLimitService {
    static let freeActiveBillLimit = 8

    static func canCreateBill(tier: SubscriptionTier, activeBillCount: Int) -> UsageLimitDecision {
        if tier == .pro {
            return .allowed
        }

        let billLimit = effectiveFreeBillLimit
        guard activeBillCount < billLimit else {
            return UsageLimitDecision(
                isAllowed: false,
                message: "Free plan supports up to \(billLimit) active bills. Upgrade to Pro for unlimited bills."
            )
        }
        return .allowed
    }

    static func canUse(_ feature: BillFeature, tier: SubscriptionTier) -> Bool {
        guard tier != .pro else { return true }

        switch feature {
        case .unlimitedBills, .extractionAutomation, .advancedReminderControls, .monthlyInsights, .csvExport:
            return false
        }
    }

    static var proFeatures: [BillFeature] {
        [
            .unlimitedBills,
            .extractionAutomation,
            .advancedReminderControls,
            .monthlyInsights,
            .csvExport
        ]
    }

    private static var effectiveFreeBillLimit: Int {
        let environment = ProcessInfo.processInfo.environment
        if let rawOverride = environment["UITEST_FREE_BILL_LIMIT"],
           let limit = Int(rawOverride),
           limit >= 0 {
            return limit
        }
        return freeActiveBillLimit
    }
}
