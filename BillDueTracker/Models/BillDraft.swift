import Foundation

struct BillDraft {
    var category: BillCategory = .utilityBill
    var providerName: String = ""
    var nickname: String = ""
    var dueDay: Int = 1
    var dueDateRule: DueDateRule = .endOfMonthClamp
    var billingCadence: BillingCadence = .monthly
    var annualDueMonth: Int?
    var expectedAmountText: String = ""
    var autopayEnabled: Bool = false
    var autopayNote: String = ""

    var expectedAmount: Double? {
        let cleaned = expectedAmountText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    func resolvedAnnualDueMonth(defaultMonth: Int) -> Int? {
        guard category == .subscriptionDue, billingCadence == .yearly else {
            return nil
        }
        let month = annualDueMonth ?? defaultMonth
        return min(max(month, 1), 12)
    }
}
