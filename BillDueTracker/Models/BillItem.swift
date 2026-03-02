import Foundation
import SwiftData

@Model
final class BillItem {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String
    var providerName: String
    var nickname: String
    var dueDay: Int
    var dueDateRuleRaw: String
    var billingCadenceRaw: String
    var annualDueMonth: Int?
    var currency: String
    var expectedAmount: Double?
    var autopayEnabled: Bool
    var autopayNote: String
    var isActive: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \BillCycle.billItem)
    var cycles: [BillCycle] = []

    init(
        id: UUID = UUID(),
        category: BillCategory,
        providerName: String,
        nickname: String,
        dueDay: Int,
        dueDateRule: DueDateRule = .endOfMonthClamp,
        billingCadence: BillingCadence = .monthly,
        annualDueMonth: Int? = nil,
        currency: String = "SGD",
        expectedAmount: Double? = nil,
        autopayEnabled: Bool = false,
        autopayNote: String = "",
        isActive: Bool = true,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.categoryRaw = category.rawValue
        self.providerName = providerName
        self.nickname = nickname
        self.dueDay = dueDay
        self.dueDateRuleRaw = dueDateRule.rawValue
        self.billingCadenceRaw = billingCadence.rawValue
        self.annualDueMonth = annualDueMonth
        self.currency = currency
        self.expectedAmount = expectedAmount
        self.autopayEnabled = autopayEnabled
        self.autopayNote = autopayNote
        self.isActive = isActive
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var category: BillCategory {
        get { BillCategory(rawValue: categoryRaw) ?? .utilityBill }
        set { categoryRaw = newValue.rawValue }
    }

    var dueDateRule: DueDateRule {
        get { DueDateRule(rawValue: dueDateRuleRaw) ?? .endOfMonthClamp }
        set { dueDateRuleRaw = newValue.rawValue }
    }

    var billingCadence: BillingCadence {
        get { BillingCadence(rawValue: billingCadenceRaw) ?? .monthly }
        set { billingCadenceRaw = newValue.rawValue }
    }

    var latestCycle: BillCycle? {
        cycles.max { $0.dueDate < $1.dueDate }
    }

    var displayName: String {
        nickname.isEmpty ? providerName : nickname
    }

    var currentStatus: BillStatus {
        guard isActive else { return .paused }
        guard let cycle = cycleForStatus else { return .active }
        if cycle.paymentState == .paid {
            return .paidCurrentCycle
        }
        if cycle.paymentState == .unpaid, cycle.overdueStartedAt != nil {
            return .overdue
        }
        return .active
    }

    private var cycleForStatus: BillCycle? {
        let now = Date()

        let unpaidUpcoming = cycles
            .filter { $0.paymentState == .unpaid && $0.dueDate >= now }
            .sorted { $0.dueDate < $1.dueDate }
        if let firstUpcoming = unpaidUpcoming.first {
            return firstUpcoming
        }

        let unpaidPast = cycles
            .filter { $0.paymentState == .unpaid && $0.dueDate < now }
            .sorted { $0.dueDate > $1.dueDate }
        if let latestUnpaidPast = unpaidPast.first {
            return latestUnpaidPast
        }

        return latestCycle
    }
}
