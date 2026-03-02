import Foundation
import SwiftData

@Model
final class BillCycle {
    @Attribute(.unique) var id: UUID
    var cycleMonth: String
    var dueDate: Date
    var reminderStateRaw: String
    var paymentStateRaw: String
    var paidAt: Date?
    var overdueStartedAt: Date?

    var billItem: BillItem?

    @Relationship(deleteRule: .cascade, inverse: \PaymentProof.billCycle)
    var proofs: [PaymentProof] = []

    @Relationship(deleteRule: .cascade, inverse: \ReminderEvent.billCycle)
    var reminderEvents: [ReminderEvent] = []

    init(
        id: UUID = UUID(),
        cycleMonth: String,
        dueDate: Date,
        reminderState: ReminderStage = .sevenDay,
        paymentState: PaymentState = .unpaid,
        paidAt: Date? = nil,
        overdueStartedAt: Date? = nil,
        billItem: BillItem? = nil
    ) {
        self.id = id
        self.cycleMonth = cycleMonth
        self.dueDate = dueDate
        self.reminderStateRaw = reminderState.rawValue
        self.paymentStateRaw = paymentState.rawValue
        self.paidAt = paidAt
        self.overdueStartedAt = overdueStartedAt
        self.billItem = billItem
    }

    var reminderState: ReminderStage {
        get { ReminderStage(rawValue: reminderStateRaw) ?? .sevenDay }
        set { reminderStateRaw = newValue.rawValue }
    }

    var paymentState: PaymentState {
        get { PaymentState(rawValue: paymentStateRaw) ?? .unpaid }
        set { paymentStateRaw = newValue.rawValue }
    }
}
