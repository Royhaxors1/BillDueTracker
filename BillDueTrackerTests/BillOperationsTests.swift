import XCTest
import SwiftData
import UserNotifications
@testable import BillDueTracker

@MainActor
final class BillOperationsTests: XCTestCase {
    func testMarkPaidCancelsPendingFutureReminders() throws {
        let (context, _) = try makeInMemoryContext()
        let center = BillOpsFakeNotificationCenter()
        let notificationService = ReminderNotificationService(center: center)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let bill = BillItem(category: .utilityBill, providerName: "SP Group", nickname: "Home", dueDay: 12)
        context.insert(bill)

        let cycle = BillCycle(
            cycleMonth: "2026-03",
            dueDate: now.addingTimeInterval(24 * 60 * 60),
            reminderState: .dueDay,
            paymentState: .unpaid,
            billItem: bill
        )
        context.insert(cycle)

        let pendingEvent = ReminderEvent(
            stage: .dueDay,
            scheduledAt: now.addingTimeInterval(3600),
            deliveryStatus: .pending,
            billCycle: cycle
        )
        context.insert(pendingEvent)
        try context.save()

        try BillOperations.markPaid(
            cycle: cycle,
            context: context,
            notificationService: notificationService,
            now: now
        )

        XCTAssertEqual(cycle.paymentState, .paid)
        XCTAssertEqual(cycle.reminderEvents.first?.deliveryStatus, .cancelled)
        XCTAssertTrue(center.removedIdentifiers.contains(pendingEvent.notificationIdentifier))
    }

    func testSetBillActiveFalseCancelsPendingReminders() async throws {
        let (context, _) = try makeInMemoryContext()
        let center = BillOpsFakeNotificationCenter()
        let notificationService = ReminderNotificationService(center: center)

        let bill = BillItem(category: .telcoBill, providerName: "Singtel", nickname: "Mobile", dueDay: 20)
        context.insert(bill)

        let cycle = BillCycle(
            cycleMonth: "2026-03",
            dueDate: Date(timeIntervalSince1970: 1_700_000_000),
            reminderState: .threeDay,
            paymentState: .unpaid,
            billItem: bill
        )
        context.insert(cycle)

        let pendingEvent = ReminderEvent(
            stage: .threeDay,
            scheduledAt: Date(timeIntervalSince1970: 1_700_000_100),
            deliveryStatus: .pending,
            billCycle: cycle
        )
        context.insert(pendingEvent)
        try context.save()

        try await BillOperations.setBillActive(
            bill,
            isActive: false,
            context: context,
            notificationService: notificationService,
            now: .now,
            timeZone: .current
        )

        XCTAssertFalse(bill.isActive)
        XCTAssertEqual(pendingEvent.deliveryStatus, .cancelled)
        XCTAssertTrue(center.removedIdentifiers.contains(pendingEvent.notificationIdentifier))
    }

    func testDeleteBillRemovesBillAndCancelsPendingReminders() throws {
        let (context, _) = try makeInMemoryContext()
        let center = BillOpsFakeNotificationCenter()
        let notificationService = ReminderNotificationService(center: center)

        let bill = BillItem(category: .creditCardDue, providerName: "UOB", nickname: "Card", dueDay: 3)
        context.insert(bill)

        let cycle = BillCycle(
            cycleMonth: "2026-03",
            dueDate: Date(timeIntervalSince1970: 1_700_000_000),
            reminderState: .oneDay,
            paymentState: .unpaid,
            billItem: bill
        )
        context.insert(cycle)

        let pendingEvent = ReminderEvent(
            stage: .oneDay,
            scheduledAt: Date(timeIntervalSince1970: 1_700_000_120),
            deliveryStatus: .pending,
            billCycle: cycle
        )
        context.insert(pendingEvent)
        try context.save()

        try BillOperations.deleteBill(
            bill,
            context: context,
            notificationService: notificationService
        )

        XCTAssertTrue(center.removedIdentifiers.contains(pendingEvent.notificationIdentifier))
        XCTAssertEqual(try context.fetch(FetchDescriptor<BillItem>()).count, 0)
        XCTAssertEqual(try context.fetch(FetchDescriptor<BillCycle>()).count, 0)
    }

    private func makeInMemoryContext() throws -> (ModelContext, ModelContainer) {
        let container = try ModelContainer(
            for: UserProfile.self,
            BillItem.self,
            BillCycle.self,
            ReminderEvent.self,
            PaymentProof.self,
            ProviderAction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return (ModelContext(container), container)
    }
}

@MainActor
private final class BillOpsFakeNotificationCenter: UserNotificationCentering {
    var removedIdentifiers: [String] = []

    func requestAuthorization(options _: UNAuthorizationOptions) async throws -> Bool { true }

    func add(_: UNNotificationRequest) async throws {}

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }

    func removeAllPendingNotificationRequests() {}

    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }

    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
}
