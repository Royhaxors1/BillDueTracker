import Foundation
import UserNotifications

@MainActor
protocol UserNotificationCentering: AnyObject {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers identifiers: [String])
    func removeAllPendingNotificationRequests()
    func authorizationStatus() async -> UNAuthorizationStatus
    func pendingNotificationRequests() async -> [UNNotificationRequest]
}

extension UNUserNotificationCenter: UserNotificationCentering {
    func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func pendingNotificationRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }
}

@MainActor
final class ReminderNotificationService {
    static let shared = ReminderNotificationService()
    static let billIDUserInfoKey = "bill_id"
    static let cycleIDUserInfoKey = "cycle_id"

    private let center: UserNotificationCentering

    init(center: UserNotificationCentering = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.authorizationStatus()
    }

    func pendingRequests() async -> [UNNotificationRequest] {
        await center.pendingNotificationRequests()
    }

    func scheduleSelfTestNotification(after seconds: TimeInterval) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Bill Due Tracker Test"
        content.body = "Notifications are active on this device."
        content.sound = .default

        let safeInterval = max(1, seconds)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: safeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: "reminder-self-test-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        try await center.add(request)
    }

    func nextTriggerDate(from request: UNNotificationRequest) -> Date? {
        guard let trigger = request.trigger else { return nil }
        if let calendarTrigger = trigger as? UNCalendarNotificationTrigger {
            return calendarTrigger.nextTriggerDate()
        }
        if let intervalTrigger = trigger as? UNTimeIntervalNotificationTrigger {
            return Date().addingTimeInterval(intervalTrigger.timeInterval)
        }
        return nil
    }

    func schedule(event: ReminderEvent, for bill: BillItem) async {
        let content = UNMutableNotificationContent()
        content.title = notificationTitle(for: event.stage, billName: bill.displayName)
        content.body = notificationBody(for: event.stage, bill: bill)
        content.sound = .default
        var userInfo: [AnyHashable: Any] = [
            Self.billIDUserInfoKey: bill.id.uuidString
        ]
        if let cycleID = event.billCycle?.id {
            userInfo[Self.cycleIDUserInfoKey] = cycleID.uuidString
        }
        content.userInfo = userInfo

        let trigger: UNNotificationTrigger
        switch event.stage {
        case .overdue:
            let components = Calendar.gregorian.dateComponents([.hour, .minute], from: event.scheduledAt)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        default:
            let components = Calendar.gregorian.dateComponents([.year, .month, .day, .hour, .minute], from: event.scheduledAt)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        }

        let request = UNNotificationRequest(
            identifier: event.notificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
        } catch {
            event.deliveryStatus = .failed
        }
    }

    func cancel(events: [ReminderEvent]) {
        let identifiers = events.map(\.notificationIdentifier)
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    private func notificationTitle(for stage: ReminderStage, billName: String) -> String {
        switch stage {
        case .sevenDay:
            return "\(billName) due in 7 days"
        case .threeDay:
            return "\(billName) due in 3 days"
        case .oneDay:
            return "\(billName) due tomorrow"
        case .dueDay:
            return "\(billName) is due today"
        case .overdue:
            return "\(billName) is overdue"
        }
    }

    private func notificationBody(for stage: ReminderStage, bill: BillItem) -> String {
        let amountText: String
        if let expectedAmount = bill.expectedAmount {
            amountText = String(format: " (about %@ %.2f)", bill.currency, expectedAmount)
        } else {
            amountText = ""
        }

        switch stage {
        case .overdue:
            return "Mark it paid in Bill Due Tracker to stop overdue reminders\(amountText)."
        default:
            return "Tap to review the due date and action link\(amountText)."
        }
    }
}
