import Foundation
import SwiftData

@Model
final class ReminderEvent {
    @Attribute(.unique) var id: UUID
    var stageRaw: String
    var scheduledAt: Date
    var sentAt: Date?
    var deliveryStatusRaw: String

    var billCycle: BillCycle?

    init(
        id: UUID = UUID(),
        stage: ReminderStage,
        scheduledAt: Date,
        sentAt: Date? = nil,
        deliveryStatus: ReminderDeliveryStatus = .pending,
        billCycle: BillCycle? = nil
    ) {
        self.id = id
        self.stageRaw = stage.rawValue
        self.scheduledAt = scheduledAt
        self.sentAt = sentAt
        self.deliveryStatusRaw = deliveryStatus.rawValue
        self.billCycle = billCycle
    }

    var stage: ReminderStage {
        get { ReminderStage(rawValue: stageRaw) ?? .dueDay }
        set { stageRaw = newValue.rawValue }
    }

    var deliveryStatus: ReminderDeliveryStatus {
        get { ReminderDeliveryStatus(rawValue: deliveryStatusRaw) ?? .pending }
        set { deliveryStatusRaw = newValue.rawValue }
    }

    var notificationIdentifier: String {
        "reminder-\(id.uuidString)"
    }
}
