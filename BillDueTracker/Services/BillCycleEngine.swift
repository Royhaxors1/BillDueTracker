import Foundation

struct ReminderPlan: Equatable {
    let stage: ReminderStage
    let scheduledAt: Date
}

enum BillCycleEngine {
    static let reminderHour = 9
    static let reminderMinute = 0

    static func cycleMonthIdentifier(for date: Date, in timeZone: TimeZone) -> String {
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", components.year ?? 1970, components.month ?? 1)
    }

    static func monthAnchor(from identifier: String, in timeZone: TimeZone) -> Date? {
        let parts = identifier.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else {
            return nil
        }

        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: 1, hour: 0, minute: 0))
    }

    static func dueDate(
        monthAnchor: Date,
        dueDay: Int,
        rule: DueDateRule,
        in timeZone: TimeZone
    ) -> Date {
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone

        let startOfMonth = monthAnchor.startOfMonth(in: timeZone, calendar: calendar)
        let dayRange = calendar.range(of: .day, in: .month, for: startOfMonth) ?? 1..<29
        let maxDay = dayRange.count

        let resolvedDay: Int
        switch rule {
        case .endOfMonthClamp:
            resolvedDay = min(max(1, dueDay), maxDay)
        case .fixedDay:
            resolvedDay = min(max(1, dueDay), maxDay)
        }

        var components = calendar.dateComponents([.year, .month], from: startOfMonth)
        components.day = resolvedDay
        components.hour = reminderHour
        components.minute = reminderMinute
        components.second = 0
        return calendar.date(from: components) ?? monthAnchor
    }

    static func dueDayHasPassed(dueDate: Date, now: Date, in timeZone: TimeZone) -> Bool {
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone
        let dueDayStart = dueDate.startOfDay(in: timeZone, calendar: calendar)
        let endOfDueDay = calendar.date(byAdding: .day, value: 1, to: dueDayStart) ?? dueDate
        return now >= endOfDueDay
    }

    static func reminderPlans(
        dueDate: Date,
        paymentState: PaymentState,
        now: Date,
        enabledStages: Set<ReminderStage> = Set(ReminderStage.allCases),
        in timeZone: TimeZone
    ) -> [ReminderPlan] {
        guard paymentState == .unpaid else { return [] }

        let offsets: [(ReminderStage, Int)] = [
            (.sevenDay, -7),
            (.threeDay, -3),
            (.oneDay, -1),
            (.dueDay, 0)
        ]

        var plans: [ReminderPlan] = []

        for (stage, offset) in offsets {
            guard enabledStages.contains(stage) else { continue }
            let candidate = dueDate.addingDays(offset, in: timeZone)
            if candidate >= now {
                plans.append(ReminderPlan(stage: stage, scheduledAt: candidate))
            }
        }

        if enabledStages.contains(.overdue), dueDayHasPassed(dueDate: dueDate, now: now, in: timeZone) {
            let firstOverdue = dueDate.addingDays(1, in: timeZone)
            let overdueStart = max(firstOverdue, nextDailyReminderSlot(after: now, in: timeZone))
            plans.append(ReminderPlan(stage: .overdue, scheduledAt: overdueStart))
        }

        return plans.sorted { lhs, rhs in
            if lhs.scheduledAt == rhs.scheduledAt {
                return lhs.stage.sortOrder < rhs.stage.sortOrder
            }
            return lhs.scheduledAt < rhs.scheduledAt
        }
    }

    static func nextDailyReminderSlot(after now: Date, in timeZone: TimeZone) -> Date {
        var calendar = Calendar.gregorian
        calendar.timeZone = timeZone

        var components = calendar.dateComponents([.year, .month, .day], from: now)
        components.hour = reminderHour
        components.minute = reminderMinute
        components.second = 0

        let candidate = calendar.date(from: components) ?? now
        if candidate > now {
            return candidate
        }
        return calendar.date(byAdding: .day, value: 1, to: candidate) ?? now.addingDays(1, in: timeZone)
    }
}
