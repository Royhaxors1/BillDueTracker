import Foundation
import SwiftData

@MainActor
enum BillOperations {
    static func bootstrap(
        context: ModelContext,
        notificationService: ReminderNotificationService,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) async {
        ensureDefaultUser(context: context)
        do {
            try ProviderActionSeeder.seedIfNeeded(context: context)
        } catch {
            reportCriticalError(error, operation: "seeding provider actions during bootstrap")
        }
        await applyUITestSeedIfRequested(
            context: context,
            notificationService: notificationService,
            now: now,
            timeZone: timeZone
        )
        await reconcileReminders(
            context: context,
            notificationService: notificationService,
            now: now,
            timeZone: timeZone
        )
    }

    static func reconcileReminders(
        context: ModelContext,
        notificationService: ReminderNotificationService,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) async {
        let descriptor = FetchDescriptor<BillItem>()
        let bills: [BillItem]
        do {
            bills = try context.fetch(descriptor)
        } catch {
            reportCriticalError(error, operation: "fetching bills for reminder reconciliation")
            return
        }
        for bill in bills where bill.isActive {
            await refreshCyclesAndReminders(
                for: bill,
                context: context,
                notificationService: notificationService,
                now: now,
                timeZone: timeZone
            )
        }

        if let user = defaultUser(context: context, createIfMissing: true) {
            user.lastReminderReconciledAt = now
        }
        do {
            try context.save()
        } catch {
            reportCriticalError(error, operation: "saving reminder reconciliation changes")
        }
    }

    static func addBill(
        draft: BillDraft,
        context: ModelContext,
        notificationService: ReminderNotificationService,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) async throws -> BillItem {
        let cadenceFields = resolvedCadenceFields(from: draft, now: now, timeZone: timeZone)
        let bill = BillItem(
            category: draft.category,
            providerName: draft.providerName,
            nickname: draft.nickname,
            dueDay: draft.dueDay,
            dueDateRule: draft.dueDateRule,
            billingCadence: cadenceFields.cadence,
            annualDueMonth: cadenceFields.annualDueMonth,
            currency: Locale.current.currencyCode ?? "SGD",
            expectedAmount: draft.expectedAmount,
            autopayEnabled: draft.autopayEnabled,
            autopayNote: draft.autopayNote,
            isActive: true,
            createdAt: now,
            updatedAt: now
        )
        context.insert(bill)

        await refreshCyclesAndReminders(
            for: bill,
            context: context,
            notificationService: notificationService,
            now: now,
            timeZone: timeZone
        )

        try context.save()
        return bill
    }

    static func updateBill(
        _ bill: BillItem,
        draft: BillDraft,
        context: ModelContext,
        notificationService: ReminderNotificationService,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) async throws {
        let cadenceFields = resolvedCadenceFields(from: draft, now: now, timeZone: timeZone)
        bill.category = draft.category
        bill.providerName = draft.providerName
        bill.nickname = draft.nickname
        bill.dueDay = draft.dueDay
        bill.dueDateRule = draft.dueDateRule
        bill.billingCadence = cadenceFields.cadence
        bill.annualDueMonth = cadenceFields.annualDueMonth
        bill.expectedAmount = draft.expectedAmount
        bill.autopayEnabled = draft.autopayEnabled
        bill.autopayNote = draft.autopayNote
        bill.updatedAt = now

        await refreshCyclesAndReminders(
            for: bill,
            context: context,
            notificationService: notificationService,
            now: now,
            timeZone: timeZone
        )

        try context.save()
    }

    static func markPaid(
        cycle: BillCycle,
        context: ModelContext,
        notificationService: ReminderNotificationService,
        now: Date = .now
    ) throws {
        cycle.paymentState = .paid
        cycle.paidAt = now
        cycle.overdueStartedAt = nil

        let cancellableEvents = cycle.reminderEvents.filter {
            $0.deliveryStatus == .pending && $0.scheduledAt >= now
        }
        notificationService.cancel(events: cancellableEvents)
        for event in cancellableEvents {
            event.deliveryStatus = .cancelled
        }

        try context.save()
    }

    static func setBillActive(
        _ bill: BillItem,
        isActive: Bool,
        context: ModelContext,
        notificationService: ReminderNotificationService,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) async throws {
        if isActive {
            bill.isActive = true
            bill.updatedAt = now
            await refreshCyclesAndReminders(
                for: bill,
                context: context,
                notificationService: notificationService,
                now: now,
                timeZone: timeZone
            )
            try context.save()
            return
        }

        cancelPendingReminders(for: bill, notificationService: notificationService)
        bill.isActive = false
        bill.updatedAt = now
        try context.save()
    }

    static func deleteBill(
        _ bill: BillItem,
        context: ModelContext,
        notificationService: ReminderNotificationService
    ) throws {
        cancelPendingReminders(for: bill, notificationService: notificationService)
        context.delete(bill)
        try context.save()
    }

    static func addPaymentProof(
        cycle: BillCycle,
        localFileURL: URL,
        context: ModelContext
    ) throws {
        let proof = PaymentProof(
            fileURLString: localFileURL.absoluteString,
            fileType: localFileURL.pathExtension,
            uploadedAt: .now,
            billCycle: cycle
        )
        context.insert(proof)
        try context.save()
    }

    static func cycleForCurrentMonth(
        bill: BillItem,
        now: Date = .now,
        timeZone: TimeZone = .current
    ) -> BillCycle? {
        let currentCycleID = BillCycleEngine.cycleMonthIdentifier(for: now, in: timeZone)
        if let currentUnpaidCycle = bill.cycles.first(where: {
            $0.cycleMonth == currentCycleID && $0.paymentState == .unpaid
        }) {
            return currentUnpaidCycle
        }

        let unpaidPast = bill.cycles
            .filter { $0.paymentState == .unpaid && $0.dueDate < now }
            .sorted { $0.dueDate > $1.dueDate }
        if let latestUnpaidPast = unpaidPast.first {
            return latestUnpaidPast
        }

        let unpaidUpcoming = bill.cycles
            .filter { $0.paymentState == .unpaid && $0.dueDate >= now }
            .sorted { $0.dueDate < $1.dueDate }
        if let firstUpcoming = unpaidUpcoming.first {
            return firstUpcoming
        }

        if let currentMonthCycle = bill.cycles.first(where: { $0.cycleMonth == currentCycleID }) {
            return currentMonthCycle
        }

        return bill.latestCycle
    }

    static func enabledReminderStages(context: ModelContext) -> Set<ReminderStage> {
        defaultUser(context: context, createIfMissing: true)?.enabledReminderStages ?? Set(ReminderStage.allCases)
    }

    static func setReminderStagePreference(
        stage: ReminderStage,
        enabled: Bool,
        context: ModelContext
    ) throws {
        guard let user = defaultUser(context: context, createIfMissing: true) else { return }
        user.setReminderStage(stage, isEnabled: enabled)
        try context.save()
    }

    static func providerNames(for category: BillCategory, context: ModelContext) -> [String] {
        let catalogProviders = SGProviderCatalog.providers(for: category)
        let customProviders = defaultUser(context: context, createIfMissing: false)?.providers(for: category) ?? []
        return mergedProviders(catalogProviders, customProviders)
    }

    static func saveCustomProvider(
        _ providerName: String,
        for category: BillCategory,
        context: ModelContext
    ) throws {
        guard let user = defaultUser(context: context, createIfMissing: true) else { return }
        let inserted = user.addCustomProvider(providerName, for: category)
        if inserted {
            try context.save()
        }
    }

    static func refreshCyclesAndReminders(
        for bill: BillItem,
        context: ModelContext,
        notificationService: ReminderNotificationService,
        now: Date,
        timeZone: TimeZone
    ) async {
        let enabledStages = enabledReminderStages(context: context)
        let anchors = cycleAnchors(for: bill, now: now, timeZone: timeZone)
        let targetCycleMonths = Set(
            anchors.map { BillCycleEngine.cycleMonthIdentifier(for: $0, in: timeZone) }
        )

        let nonTargetCycles = bill.cycles.filter { !targetCycleMonths.contains($0.cycleMonth) }
        cancelAndDeletePendingReminders(
            for: nonTargetCycles,
            context: context,
            notificationService: notificationService
        )

        var didScheduleSuccessfully = false

        for anchor in anchors {
            let cycle = upsertCycle(
                for: bill,
                monthAnchor: anchor,
                now: now,
                context: context,
                timeZone: timeZone
            )
            let scheduledCycle = await regenerateReminderEvents(
                for: cycle,
                bill: bill,
                now: now,
                context: context,
                notificationService: notificationService,
                enabledReminderStages: enabledStages,
                timeZone: timeZone
            )
            didScheduleSuccessfully = didScheduleSuccessfully || scheduledCycle
        }

        if let user = defaultUser(context: context, createIfMissing: true) {
            user.lastReminderReconciledAt = now
            if didScheduleSuccessfully {
                user.lastReminderScheduleSuccessAt = now
            }
        }
    }

    private static func upsertCycle(
        for bill: BillItem,
        monthAnchor: Date,
        now: Date,
        context: ModelContext,
        timeZone: TimeZone
    ) -> BillCycle {
        let cycleMonth = BillCycleEngine.cycleMonthIdentifier(for: monthAnchor, in: timeZone)
        let dueDate = BillCycleEngine.dueDate(
            monthAnchor: monthAnchor,
            dueDay: bill.dueDay,
            rule: bill.dueDateRule,
            in: timeZone
        )

        if let existing = bill.cycles.first(where: { $0.cycleMonth == cycleMonth }) {
            existing.dueDate = dueDate
            if existing.paymentState == .unpaid,
               BillCycleEngine.dueDayHasPassed(dueDate: dueDate, now: now, in: timeZone) {
                existing.overdueStartedAt = dueDate.addingDays(1, in: timeZone)
                existing.reminderState = .overdue
            } else if existing.paymentState == .unpaid {
                existing.overdueStartedAt = nil
            }
            return existing
        }

        let cycle = BillCycle(
            cycleMonth: cycleMonth,
            dueDate: dueDate,
            reminderState: .sevenDay,
            paymentState: .unpaid,
            paidAt: nil,
            overdueStartedAt: nil,
            billItem: bill
        )

        if BillCycleEngine.dueDayHasPassed(dueDate: dueDate, now: now, in: timeZone) {
            cycle.overdueStartedAt = dueDate.addingDays(1, in: timeZone)
            cycle.reminderState = .overdue
        }

        context.insert(cycle)
        return cycle
    }

    private static func regenerateReminderEvents(
        for cycle: BillCycle,
        bill: BillItem,
        now: Date,
        context: ModelContext,
        notificationService: ReminderNotificationService,
        enabledReminderStages: Set<ReminderStage>,
        timeZone: TimeZone
    ) async -> Bool {
        let existingPending = cycle.reminderEvents.filter { $0.deliveryStatus == .pending }
        notificationService.cancel(events: existingPending)
        for event in existingPending {
            context.delete(event)
        }

        let plans = BillCycleEngine.reminderPlans(
            dueDate: cycle.dueDate,
            paymentState: cycle.paymentState,
            now: now,
            enabledStages: enabledReminderStages,
            in: timeZone
        )

        var didScheduleSuccessfully = false
        for plan in plans {
            let event = ReminderEvent(stage: plan.stage, scheduledAt: plan.scheduledAt, billCycle: cycle)
            context.insert(event)
            cycle.reminderState = plan.stage
            await notificationService.schedule(event: event, for: bill)
            if event.deliveryStatus != .failed {
                didScheduleSuccessfully = true
            }
        }

        return didScheduleSuccessfully
    }

    private static func resolvedCadenceFields(
        from draft: BillDraft,
        now: Date,
        timeZone: TimeZone
    ) -> (cadence: BillingCadence, annualDueMonth: Int?) {
        guard draft.category == .subscriptionDue else {
            return (.monthly, nil)
        }

        switch draft.billingCadence {
        case .monthly:
            return (.monthly, nil)
        case .yearly:
            var calendar = Calendar.gregorian
            calendar.timeZone = timeZone
            let defaultMonth = calendar.component(.month, from: now)
            let month = draft.resolvedAnnualDueMonth(defaultMonth: defaultMonth) ?? defaultMonth
            return (.yearly, month)
        }
    }

    private static func cycleAnchors(
        for bill: BillItem,
        now: Date,
        timeZone: TimeZone
    ) -> [Date] {
        if bill.category == .subscriptionDue, bill.billingCadence == .yearly {
            var calendar = Calendar.gregorian
            calendar.timeZone = timeZone

            let currentYear = calendar.component(.year, from: now)
            let fallbackMonth = calendar.component(.month, from: now)
            let annualMonth = min(max(bill.annualDueMonth ?? fallbackMonth, 1), 12)

            let thisYearAnchor = calendar.date(
                from: DateComponents(year: currentYear, month: annualMonth, day: 1, hour: 0, minute: 0)
            )
            let nextYearAnchor = calendar.date(
                from: DateComponents(year: currentYear + 1, month: annualMonth, day: 1, hour: 0, minute: 0)
            )

            return [thisYearAnchor, nextYearAnchor].compactMap { $0 }
        }

        let currentMonthAnchor = now.startOfMonth(in: timeZone)
        return [
            currentMonthAnchor,
            currentMonthAnchor.addingMonths(1, in: timeZone)
        ]
    }

    private static func cancelAndDeletePendingReminders(
        for cycles: [BillCycle],
        context: ModelContext,
        notificationService: ReminderNotificationService
    ) {
        for cycle in cycles {
            let pendingEvents = cycle.reminderEvents.filter { $0.deliveryStatus == .pending }
            guard !pendingEvents.isEmpty else { continue }

            notificationService.cancel(events: pendingEvents)
            for event in pendingEvents {
                event.deliveryStatus = .cancelled
                context.delete(event)
            }
        }
    }

    private static func ensureDefaultUser(context: ModelContext) {
        let descriptor = FetchDescriptor<UserProfile>()
        let users: [UserProfile]
        do {
            users = try context.fetch(descriptor)
        } catch {
            reportCriticalError(error, operation: "fetching users while ensuring default user")
            return
        }
        guard users.isEmpty else { return }

        let user = UserProfile(
            email: "local-user@billduetracker.local",
            timezoneIdentifier: TimeZone.current.identifier
        )
        context.insert(user)
    }

    private static func defaultUser(context: ModelContext, createIfMissing: Bool) -> UserProfile? {
        if createIfMissing {
            ensureDefaultUser(context: context)
        }
        let descriptor = FetchDescriptor<UserProfile>()
        do {
            return try context.fetch(descriptor).first
        } catch {
            reportCriticalError(error, operation: "fetching default user")
            return nil
        }
    }

    private static func cancelPendingReminders(
        for bill: BillItem,
        notificationService: ReminderNotificationService
    ) {
        let pendingEvents = bill.cycles
            .flatMap(\.reminderEvents)
            .filter { $0.deliveryStatus == .pending }
        guard !pendingEvents.isEmpty else { return }
        notificationService.cancel(events: pendingEvents)
        for event in pendingEvents {
            event.deliveryStatus = .cancelled
        }
    }

    private static func mergedProviders(_ lhs: [String], _ rhs: [String]) -> [String] {
        var merged: [String] = []
        for provider in lhs + rhs {
            let trimmed = provider.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let exists = merged.contains {
                $0.caseInsensitiveCompare(trimmed) == .orderedSame
            }
            if !exists {
                merged.append(trimmed)
            }
        }
        return merged.sorted { left, right in
            left.localizedCaseInsensitiveCompare(right) == .orderedAscending
        }
    }

    private static func applyUITestSeedIfRequested(
        context: ModelContext,
        notificationService: ReminderNotificationService,
        now: Date,
        timeZone: TimeZone
    ) async {
        let environment = ProcessInfo.processInfo.environment
        guard environment["UITEST_SEED"] == "1" else { return }

        if environment["UITEST_RESET"] == "1" {
            let descriptor = FetchDescriptor<BillItem>()
            let existingBills: [BillItem]
            do {
                existingBills = try context.fetch(descriptor)
            } catch {
                reportCriticalError(error, operation: "fetching bills for UITest reset")
                return
            }
            for bill in existingBills {
                context.delete(bill)
            }
            do {
                try context.save()
            } catch {
                reportCriticalError(error, operation: "saving UITest reset deletions")
                return
            }
        }

        let descriptor = FetchDescriptor<BillItem>()
        let bills: [BillItem]
        do {
            bills = try context.fetch(descriptor)
        } catch {
            reportCriticalError(error, operation: "fetching bills before UITest seeding")
            return
        }
        guard bills.isEmpty else { return }

        var utilityDraft = BillDraft()
        utilityDraft.category = .utilityBill
        utilityDraft.providerName = "SP Group"
        utilityDraft.nickname = "Home Utilities"
        utilityDraft.dueDay = 12
        utilityDraft.expectedAmountText = "168.40"

        var telcoDraft = BillDraft()
        telcoDraft.category = .telcoBill
        telcoDraft.providerName = "Singtel"
        telcoDraft.nickname = "Singtel Mobile"
        telcoDraft.dueDay = 18
        telcoDraft.expectedAmountText = "62.00"

        var cardDraft = BillDraft()
        cardDraft.category = .creditCardDue
        cardDraft.providerName = "DBS/POSB"
        cardDraft.nickname = "DBS Visa"
        cardDraft.dueDay = 25
        cardDraft.expectedAmountText = "450.00"

        var subscriptionDraft = BillDraft()
        subscriptionDraft.category = .subscriptionDue
        subscriptionDraft.providerName = "Netflix"
        subscriptionDraft.nickname = "Netflix"
        subscriptionDraft.dueDay = 7
        subscriptionDraft.billingCadence = .monthly
        subscriptionDraft.expectedAmountText = "21.98"

        let drafts = [utilityDraft, telcoDraft, cardDraft, subscriptionDraft]
        for draft in drafts {
            do {
                _ = try await addBill(
                    draft: draft,
                    context: context,
                    notificationService: notificationService,
                    now: now,
                    timeZone: timeZone
                )
            } catch {
                reportCriticalError(error, operation: "adding UITest seed bill \(draft.providerName)")
            }
        }
    }

    private static func reportCriticalError(_ error: Error, operation: String) {
        let message = "BillOperations critical failure while \(operation): \(error.localizedDescription)"
        assertionFailure(message)
        NSLog("%@", message)
    }
}
