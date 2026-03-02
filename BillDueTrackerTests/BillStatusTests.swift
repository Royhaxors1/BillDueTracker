import XCTest
import SwiftData
import UserNotifications
@testable import BillDueTracker

@MainActor
final class BillStatusTests: XCTestCase {
    func testCurrentStatusOverdueWhenUnpaidAndOverdueStarted() {
        let bill = BillItem(category: .utilityBill, providerName: "SP Group", nickname: "Home Utilities", dueDay: 10)
        let cycle = BillCycle(cycleMonth: "2026-02", dueDate: .now, reminderState: .overdue, paymentState: .unpaid, overdueStartedAt: .now, billItem: bill)
        bill.cycles.append(cycle)

        XCTAssertEqual(bill.currentStatus, .overdue)
    }

    func testCurrentStatusPaidWhenCyclePaid() {
        let bill = BillItem(category: .creditCardDue, providerName: "DBS/POSB", nickname: "DBS Card", dueDay: 21)
        let cycle = BillCycle(cycleMonth: "2026-02", dueDate: .now, reminderState: .dueDay, paymentState: .paid, paidAt: .now, billItem: bill)
        bill.cycles.append(cycle)

        XCTAssertEqual(bill.currentStatus, .paidCurrentCycle)
    }

    func testCycleForCurrentMonthFallsBackToNearestUpcomingUnpaidCycle() {
        let timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone

        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9, minute: 0)) ?? .now

        let bill = BillItem(
            category: .subscriptionDue,
            providerName: "Netflix",
            nickname: "Netflix",
            dueDay: 12,
            billingCadence: .yearly,
            annualDueMonth: 12
        )

        let paidPast = BillCycle(
            cycleMonth: "2026-01",
            dueDate: calendar.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 9, minute: 0)) ?? .now,
            reminderState: .dueDay,
            paymentState: .paid,
            paidAt: now,
            billItem: bill
        )
        let nextUpcoming = BillCycle(
            cycleMonth: "2026-12",
            dueDate: calendar.date(from: DateComponents(year: 2026, month: 12, day: 12, hour: 9, minute: 0)) ?? .now,
            reminderState: .sevenDay,
            paymentState: .unpaid,
            billItem: bill
        )
        bill.cycles.append(contentsOf: [paidPast, nextUpcoming])

        let selected = BillOperations.cycleForCurrentMonth(bill: bill, now: now, timeZone: timeZone)
        XCTAssertEqual(selected?.cycleMonth, "2026-12")
    }

    func testCycleForCurrentMonthPrefersPastUnpaidOverFutureUpcoming() {
        let timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone

        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9, minute: 0)) ?? .now

        let bill = BillItem(
            category: .subscriptionDue,
            providerName: "Netflix",
            nickname: "Netflix",
            dueDay: 12,
            billingCadence: .yearly,
            annualDueMonth: 1
        )

        let overdueCurrentYear = BillCycle(
            cycleMonth: "2026-01",
            dueDate: calendar.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 9, minute: 0)) ?? .now,
            reminderState: .overdue,
            paymentState: .unpaid,
            overdueStartedAt: calendar.date(from: DateComponents(year: 2026, month: 1, day: 13, hour: 9, minute: 0)),
            billItem: bill
        )
        let futureNextYear = BillCycle(
            cycleMonth: "2027-01",
            dueDate: calendar.date(from: DateComponents(year: 2027, month: 1, day: 12, hour: 9, minute: 0)) ?? .now,
            reminderState: .sevenDay,
            paymentState: .unpaid,
            billItem: bill
        )
        bill.cycles.append(contentsOf: [overdueCurrentYear, futureNextYear])

        let selected = BillOperations.cycleForCurrentMonth(bill: bill, now: now, timeZone: timeZone)
        XCTAssertEqual(selected?.cycleMonth, "2026-01")
    }

    func testCycleForCurrentMonthPrefersCurrentUnpaidOverOlderPastCycle() {
        let timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone

        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10, hour: 9, minute: 0)) ?? .now

        let bill = BillItem(
            category: .utilityBill,
            providerName: "SP Group",
            nickname: "Utilities",
            dueDay: 12
        )

        let pastUnpaid = BillCycle(
            cycleMonth: "2026-02",
            dueDate: calendar.date(from: DateComponents(year: 2026, month: 2, day: 12, hour: 9, minute: 0)) ?? .now,
            reminderState: .overdue,
            paymentState: .unpaid,
            overdueStartedAt: calendar.date(from: DateComponents(year: 2026, month: 2, day: 13, hour: 9, minute: 0)),
            billItem: bill
        )
        let currentUnpaid = BillCycle(
            cycleMonth: "2026-03",
            dueDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 12, hour: 9, minute: 0)) ?? .now,
            reminderState: .dueDay,
            paymentState: .unpaid,
            billItem: bill
        )
        bill.cycles.append(contentsOf: [pastUnpaid, currentUnpaid])

        let selected = BillOperations.cycleForCurrentMonth(bill: bill, now: now, timeZone: timeZone)
        XCTAssertEqual(selected?.cycleMonth, "2026-03")
    }

    func testCurrentStatusUsesNearestUnpaidCycleNotLatestPaidCycle() {
        let now = Date()
        let bill = BillItem(category: .utilityBill, providerName: "SP Group", nickname: "Utilities", dueDay: 5)

        let overdueUnpaid = BillCycle(
            cycleMonth: "2026-01",
            dueDate: now.addingTimeInterval(-24 * 60 * 60),
            reminderState: .overdue,
            paymentState: .unpaid,
            overdueStartedAt: now,
            billItem: bill
        )
        let latestPaid = BillCycle(
            cycleMonth: "2026-12",
            dueDate: now.addingTimeInterval(24 * 60 * 60),
            reminderState: .dueDay,
            paymentState: .paid,
            paidAt: now,
            billItem: bill
        )
        bill.cycles.append(contentsOf: [overdueUnpaid, latestPaid])

        XCTAssertEqual(bill.currentStatus, .overdue)
    }

    func testUpdateMonthlySubscriptionToYearlyRegeneratesTargetCycles() async throws {
        let timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 9, minute: 0)) ?? .now

        let container = try ModelContainer(
            for: UserProfile.self,
            BillItem.self,
            BillCycle.self,
            ReminderEvent.self,
            PaymentProof.self,
            ProviderAction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let notificationService = ReminderNotificationService(center: BillStatusFakeNotificationCenter())

        var monthlyDraft = BillDraft()
        monthlyDraft.category = .subscriptionDue
        monthlyDraft.providerName = "Netflix"
        monthlyDraft.nickname = "Netflix"
        monthlyDraft.dueDay = 10
        monthlyDraft.billingCadence = .monthly

        let bill = try await BillOperations.addBill(
            draft: monthlyDraft,
            context: context,
            notificationService: notificationService,
            now: now,
            timeZone: timeZone
        )
        XCTAssertTrue(Set(bill.cycles.map(\.cycleMonth)).isSuperset(of: ["2026-01", "2026-02"]))

        var yearlyDraft = monthlyDraft
        yearlyDraft.billingCadence = .yearly
        yearlyDraft.annualDueMonth = 11

        try await BillOperations.updateBill(
            bill,
            draft: yearlyDraft,
            context: context,
            notificationService: notificationService,
            now: now,
            timeZone: timeZone
        )

        let cycleMonths = Set(bill.cycles.map(\.cycleMonth))
        XCTAssertTrue(cycleMonths.contains("2026-11"))
        XCTAssertTrue(cycleMonths.contains("2027-11"))

        let legacyCycles = bill.cycles.filter { !["2026-11", "2027-11"].contains($0.cycleMonth) }
        for cycle in legacyCycles {
            let pending = cycle.reminderEvents.filter { $0.deliveryStatus == .pending }
            XCTAssertTrue(pending.isEmpty)
        }
    }

    func testReminderStagePreferencePersistsOnUserProfile() throws {
        let container = try ModelContainer(
            for: UserProfile.self,
            BillItem.self,
            BillCycle.self,
            ReminderEvent.self,
            PaymentProof.self,
            ProviderAction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        XCTAssertTrue(BillOperations.enabledReminderStages(context: context).contains(.sevenDay))

        try BillOperations.setReminderStagePreference(
            stage: .sevenDay,
            enabled: false,
            context: context
        )

        let stages = BillOperations.enabledReminderStages(context: context)
        XCTAssertFalse(stages.contains(.sevenDay))
        XCTAssertTrue(stages.contains(.dueDay))
    }

    func testSavingCustomProviderMakesItAvailableInProviderList() throws {
        let container = try ModelContainer(
            for: UserProfile.self,
            BillItem.self,
            BillCycle.self,
            ReminderEvent.self,
            PaymentProof.self,
            ProviderAction.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)

        try BillOperations.saveCustomProvider(
            "My Water Co",
            for: .utilityBill,
            context: context
        )

        let providers = BillOperations.providerNames(for: .utilityBill, context: context)
        XCTAssertTrue(providers.contains(where: { $0 == "My Water Co" }))
    }
}

@MainActor
private final class BillStatusFakeNotificationCenter: UserNotificationCentering {
    func requestAuthorization(options _: UNAuthorizationOptions) async throws -> Bool { true }

    func add(_: UNNotificationRequest) async throws {}

    func removePendingNotificationRequests(withIdentifiers _: [String]) {}

    func removeAllPendingNotificationRequests() {}

    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }

    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
}
