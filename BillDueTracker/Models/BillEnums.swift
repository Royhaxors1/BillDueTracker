import Foundation
import SwiftUI

enum BillCategory: String, Codable, CaseIterable, Identifiable {
    case utilityBill = "UTILITY_BILL"
    case telcoBill = "TELCO_BILL"
    case creditCardDue = "CREDIT_CARD_DUE"
    case subscriptionDue = "SUBSCRIPTION_DUE"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .utilityBill:
            return "Utility"
        case .telcoBill:
            return "Telco"
        case .creditCardDue:
            return "Credit Card"
        case .subscriptionDue:
            return "Subscription"
        }
    }

    var symbolName: String {
        switch self {
        case .utilityBill:
            return "bolt.fill"
        case .telcoBill:
            return "antenna.radiowaves.left.and.right"
        case .creditCardDue:
            return "creditcard.fill"
        case .subscriptionDue:
            return "arrow.triangle.2.circlepath.circle.fill"
        }
    }
}

enum BillingCadence: String, Codable, CaseIterable {
    case monthly = "MONTHLY"
    case yearly = "YEARLY"

    var title: String {
        switch self {
        case .monthly:
            return "Monthly"
        case .yearly:
            return "Yearly"
        }
    }
}

enum BillStatus: String, Codable, CaseIterable {
    case active = "ACTIVE"
    case paidCurrentCycle = "PAID_CURRENT_CYCLE"
    case overdue = "OVERDUE"
    case paused = "PAUSED"
}

enum ReminderStage: String, Codable, CaseIterable {
    case sevenDay = "SEVEN_DAY"
    case threeDay = "THREE_DAY"
    case oneDay = "ONE_DAY"
    case dueDay = "DUE_DAY"
    case overdue = "OVERDUE"

    var sortOrder: Int {
        switch self {
        case .sevenDay:
            return 0
        case .threeDay:
            return 1
        case .oneDay:
            return 2
        case .dueDay:
            return 3
        case .overdue:
            return 4
        }
    }

    var label: String {
        switch self {
        case .sevenDay:
            return "7 days before"
        case .threeDay:
            return "3 days before"
        case .oneDay:
            return "1 day before"
        case .dueDay:
            return "Due day"
        case .overdue:
            return "Overdue"
        }
    }
}

enum PaymentState: String, Codable, CaseIterable {
    case unpaid = "UNPAID"
    case paid = "PAID"
}

enum DueDateRule: String, Codable, CaseIterable {
    case fixedDay = "FIXED_DAY"
    case endOfMonthClamp = "END_OF_MONTH_CLAMP"
}

enum ReminderDeliveryStatus: String, Codable, CaseIterable {
    case pending = "PENDING"
    case sent = "SENT"
    case failed = "FAILED"
    case cancelled = "CANCELLED"
}

enum ExtractionConfidence: String, Codable, CaseIterable {
    case high = "HIGH"
    case medium = "MEDIUM"
    case low = "LOW"
}

enum AppAppearanceMode: String, CaseIterable, Identifiable {
    case system = "SYSTEM"
    case light = "LIGHT"
    case dark = "DARK"

    static let storageKey = "settings.appearanceMode"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

enum AppTab: String, Hashable {
    case dashboard
    case timeline
    case settings
}

enum BillScopeFilter: String, CaseIterable, Identifiable {
    case active = "ACTIVE"
    case inactive = "INACTIVE"
    case all = "ALL"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .active:
            return "Active"
        case .inactive:
            return "Inactive"
        case .all:
            return "All"
        }
    }
}

struct BillNavigationTarget: Hashable, Identifiable {
    let billID: UUID
    let cycleID: UUID?

    var id: String {
        "\(billID.uuidString)-\(cycleID?.uuidString ?? "current")"
    }
}

@MainActor
final class AppNavigationState: ObservableObject {
    @Published var selectedTab: AppTab = .dashboard
    @Published var pendingNavigationTarget: BillNavigationTarget?

    func routeToBill(_ target: BillNavigationTarget) {
        selectedTab = .dashboard
        pendingNavigationTarget = target
    }
}
