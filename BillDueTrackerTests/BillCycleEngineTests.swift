import XCTest
@testable import BillDueTracker

final class BillCycleEngineTests: XCTestCase {
    func testDueDateClampsToEndOfMonth() {
        let timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone
        let monthAnchor = calendar.date(from: DateComponents(year: 2026, month: 2, day: 1)) ?? .now

        let dueDate = BillCycleEngine.dueDate(
            monthAnchor: monthAnchor,
            dueDay: 31,
            rule: .endOfMonthClamp,
            in: timeZone
        )

        XCTAssertEqual(calendar.component(.day, from: dueDate), 28)
        XCTAssertEqual(calendar.component(.month, from: dueDate), 2)
    }

    func testReminderPlansIncludeStandardOffsets() {
        let timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone

        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 9, minute: 0)) ?? .now
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 8, minute: 0)) ?? .now

        let plans = BillCycleEngine.reminderPlans(
            dueDate: dueDate,
            paymentState: .unpaid,
            now: now,
            in: timeZone
        )

        XCTAssertEqual(plans.map(\.stage), [.sevenDay, .threeDay, .oneDay, .dueDay])
    }

    func testOverdueReminderIsAddedWhenDueDatePassed() {
        let timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone

        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10, hour: 9, minute: 0)) ?? .now
        let now = calendar.date(from: DateComponents(year: 2026, month: 1, day: 20, hour: 10, minute: 0)) ?? .now

        let plans = BillCycleEngine.reminderPlans(
            dueDate: dueDate,
            paymentState: .unpaid,
            now: now,
            in: timeZone
        )

        XCTAssertEqual(plans.count, BillCycleEngine.overdueReminderLookaheadDays)
        XCTAssertTrue(plans.allSatisfy { $0.stage == .overdue })

        let expectedStart = BillCycleEngine.nextDailyReminderSlot(after: now, in: timeZone)
        XCTAssertEqual(plans.first?.scheduledAt, expectedStart)

        for (index, plan) in plans.enumerated() {
            let expectedDate = expectedStart.addingDays(index, in: timeZone)
            XCTAssertEqual(plan.scheduledAt, expectedDate)
        }
    }

    func testReminderPlansRespectEnabledStages() {
        let timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone

        let dueDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 20, hour: 9, minute: 0)) ?? .now
        let now = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 8, minute: 0)) ?? .now

        let plans = BillCycleEngine.reminderPlans(
            dueDate: dueDate,
            paymentState: .unpaid,
            now: now,
            enabledStages: [.oneDay, .dueDay],
            in: timeZone
        )

        XCTAssertEqual(plans.map(\.stage), [.oneDay, .dueDay])
    }

    func testYearlyDueDateClampsForShortMonth() {
        let timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone
        let yearlyAnchor = calendar.date(from: DateComponents(year: 2027, month: 2, day: 1)) ?? .now

        let dueDate = BillCycleEngine.dueDate(
            monthAnchor: yearlyAnchor,
            dueDay: 31,
            rule: .endOfMonthClamp,
            in: timeZone
        )

        XCTAssertEqual(calendar.component(.year, from: dueDate), 2027)
        XCTAssertEqual(calendar.component(.month, from: dueDate), 2)
        XCTAssertEqual(calendar.component(.day, from: dueDate), 28)
    }

    func testReminderPlansAreSameForYearlySubscriptionDueDate() {
        let timeZone = TimeZone(identifier: "Asia/Singapore") ?? .current
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone

        let dueDate = calendar.date(from: DateComponents(year: 2027, month: 12, day: 12, hour: 9, minute: 0)) ?? .now
        let now = calendar.date(from: DateComponents(year: 2027, month: 12, day: 1, hour: 9, minute: 0)) ?? .now

        let plans = BillCycleEngine.reminderPlans(
            dueDate: dueDate,
            paymentState: .unpaid,
            now: now,
            in: timeZone
        )

        XCTAssertEqual(plans.map(\.stage), [.sevenDay, .threeDay, .oneDay, .dueDay])
    }
}
