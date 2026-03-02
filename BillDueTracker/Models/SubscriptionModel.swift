import Foundation

enum SubscriptionTier: String, Codable, CaseIterable {
    case free = "FREE"
    case pro = "PRO"

    var title: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        }
    }
}

enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case annualPro = "ANNUAL_PRO"
    case monthlyPro = "MONTHLY_PRO"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .annualPro:
            return "Annual Pro"
        case .monthlyPro:
            return "Monthly Pro"
        }
    }

    var productID: String {
        switch self {
        case .annualPro:
            return "com.marcuschin.billduetracker.pro.annual"
        case .monthlyPro:
            return "com.marcuschin.billduetracker.pro.monthly"
        }
    }

    var badge: String {
        switch self {
        case .annualPro:
            return "7-day trial"
        case .monthlyPro:
            return "Flexible"
        }
    }

    var ctaLabel: String {
        switch self {
        case .annualPro:
            return "Start 7-Day Trial"
        case .monthlyPro:
            return "Upgrade Monthly"
        }
    }

    var fallbackPriceLabel: String {
        switch self {
        case .annualPro:
            return "S$24.98 / year"
        case .monthlyPro:
            return "S$2.98 / month"
        }
    }
}

enum BillFeature: String, CaseIterable, Identifiable {
    case unlimitedBills = "UNLIMITED_BILLS"
    case extractionAutomation = "EXTRACTION_AUTOMATION"
    case advancedReminderControls = "ADVANCED_REMINDER_CONTROLS"
    case monthlyInsights = "MONTHLY_INSIGHTS"
    case csvExport = "CSV_EXPORT"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .unlimitedBills:
            return "Unlimited bills"
        case .extractionAutomation:
            return "OCR/PDF auto-fill"
        case .advancedReminderControls:
            return "Advanced reminders"
        case .monthlyInsights:
            return "Monthly cashflow insights"
        case .csvExport:
            return "CSV export"
        }
    }

    var subtitle: String {
        switch self {
        case .unlimitedBills:
            return "Track every recurring bill without limits."
        case .extractionAutomation:
            return "Convert bill screenshots and PDFs into draft fields."
        case .advancedReminderControls:
            return "Fine-tune reminder cadence and overdue behavior."
        case .monthlyInsights:
            return "See risk, totals, and due concentration at a glance."
        case .csvExport:
            return "Export your bills for finance workflows."
        }
    }
}

enum PaywallEntryPoint: String, Identifiable {
    case addBillLimit = "add_bill_limit"
    case extraction = "extraction"
    case dashboardInsights = "dashboard_insights"
    case settingsSubscription = "settings_subscription"
    case settingsExport = "settings_export"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .addBillLimit:
            return "Bill limit reached"
        case .extraction:
            return "Unlock OCR + PDF import"
        case .dashboardInsights:
            return "Unlock insights"
        case .settingsSubscription:
            return "Upgrade to Pro"
        case .settingsExport:
            return "Unlock CSV export"
        }
    }

    var subtitle: String {
        switch self {
        case .addBillLimit:
            return "Free supports up to 8 active bills. Upgrade for unlimited tracking."
        case .extraction:
            return "Auto-fill due day, provider, and amount from attachments."
        case .dashboardInsights:
            return "View monthly totals and due-risk insights in one place."
        case .settingsSubscription:
            return "Start your Pro plan to unlock advanced automation."
        case .settingsExport:
            return "Export bills to CSV for budgeting and reconciliation."
        }
    }
}

struct UsageLimitDecision {
    let isAllowed: Bool
    let message: String?

    static let allowed = UsageLimitDecision(isAllowed: true, message: nil)
}
