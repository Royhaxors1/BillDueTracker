import XCTest
import SwiftData
import UserNotifications
@testable import BillDueTracker

@MainActor
final class BackupServiceTests: XCTestCase {
    func testBuildPayloadRoundTripPreservesCounts() throws {
        let (context, _) = try makeInMemoryContext()

        let user = UserProfile(email: "local-user@billduetracker.local", timezoneIdentifier: "Asia/Singapore")
        context.insert(user)

        let bill = BillItem(
            category: .utilityBill,
            providerName: "SP Group",
            nickname: "Home",
            dueDay: 12,
            expectedAmount: 120.5
        )
        context.insert(bill)

        let cycle = BillCycle(
            cycleMonth: "2026-03",
            dueDate: Date(timeIntervalSince1970: 1_700_000_000),
            reminderState: .threeDay,
            paymentState: .unpaid,
            billItem: bill
        )
        context.insert(cycle)

        let reminder = ReminderEvent(
            stage: .threeDay,
            scheduledAt: Date(timeIntervalSince1970: 1_700_010_000),
            deliveryStatus: .pending,
            billCycle: cycle
        )
        context.insert(reminder)

        let proof = PaymentProof(
            fileURLString: "file:///tmp/proof.jpg",
            fileType: "jpg",
            billCycle: cycle
        )
        context.insert(proof)

        let action = ProviderAction(
            category: .utilityBill,
            providerName: "SP Group",
            actionLabel: "Open Portal",
            urlString: "https://www.spgroup.com.sg"
        )
        context.insert(action)

        try context.save()

        let payload = try BackupService.buildPayload(context: context)
        let data = try BackupService.data(for: payload)
        let decoded = try BackupService.payload(from: data)

        XCTAssertEqual(decoded.schemaVersion, BackupService.currentSchemaVersion)
        XCTAssertEqual(decoded.users.count, 1)
        XCTAssertEqual(decoded.users.first?.enabledReminderStagesRaw, user.enabledReminderStagesRaw)
        XCTAssertEqual(decoded.users.first?.customProvidersByCategoryRaw, user.customProvidersByCategoryRaw)
        XCTAssertEqual(decoded.bills.count, 1)
        XCTAssertEqual(decoded.cycles.count, 1)
        XCTAssertEqual(decoded.reminders.count, 1)
        XCTAssertEqual(decoded.proofs.count, 1)
        XCTAssertEqual(decoded.providerActions.count, 1)
    }

    func testValidateFailsWhenReminderReferencesMissingCycle() {
        let billID = UUID()
        let reminderCycleID = UUID()

        let payload = BackupPayload(
            schemaVersion: BackupService.currentSchemaVersion,
            exportedAt: .now,
            users: [],
            bills: [
                BackupPayload.BillRecord(
                    id: billID,
                    categoryRaw: BillCategory.utilityBill.rawValue,
                    providerName: "SP Group",
                    nickname: "",
                    dueDay: 10,
                    dueDateRuleRaw: DueDateRule.endOfMonthClamp.rawValue,
                    billingCadenceRaw: BillingCadence.monthly.rawValue,
                    annualDueMonth: nil,
                    currency: "SGD",
                    expectedAmount: nil,
                    autopayEnabled: false,
                    autopayNote: "",
                    isActive: true,
                    createdAt: .now,
                    updatedAt: .now
                )
            ],
            cycles: [],
            reminders: [
                BackupPayload.ReminderRecord(
                    id: UUID(),
                    stageRaw: ReminderStage.dueDay.rawValue,
                    scheduledAt: .now,
                    sentAt: nil,
                    deliveryStatusRaw: ReminderDeliveryStatus.pending.rawValue,
                    cycleID: reminderCycleID
                )
            ],
            proofs: [],
            providerActions: []
        )

        XCTAssertThrowsError(try BackupService.validate(payload: payload)) { error in
            guard case BackupValidationError.missingCycleReference = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testValidateFailsWhenCycleReferencesMissingBill() {
        let missingBillID = UUID()
        let payload = BackupPayload(
            schemaVersion: BackupService.currentSchemaVersion,
            exportedAt: .now,
            users: [],
            bills: [],
            cycles: [
                BackupPayload.CycleRecord(
                    id: UUID(),
                    cycleMonth: "2026-03",
                    dueDate: .now,
                    reminderStateRaw: ReminderStage.sevenDay.rawValue,
                    paymentStateRaw: PaymentState.unpaid.rawValue,
                    paidAt: nil,
                    overdueStartedAt: nil,
                    billID: missingBillID
                )
            ],
            reminders: [],
            proofs: [],
            providerActions: []
        )

        XCTAssertThrowsError(try BackupService.validate(payload: payload)) { error in
            guard case BackupValidationError.missingBillReference = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testValidateFailsWhenProofReferencesMissingCycle() {
        let billID = UUID()
        let missingCycleID = UUID()
        let payload = BackupPayload(
            schemaVersion: BackupService.currentSchemaVersion,
            exportedAt: .now,
            users: [],
            bills: [
                BackupPayload.BillRecord(
                    id: billID,
                    categoryRaw: BillCategory.utilityBill.rawValue,
                    providerName: "SP Group",
                    nickname: "Home",
                    dueDay: 10,
                    dueDateRuleRaw: DueDateRule.endOfMonthClamp.rawValue,
                    billingCadenceRaw: BillingCadence.monthly.rawValue,
                    annualDueMonth: nil,
                    currency: "SGD",
                    expectedAmount: nil,
                    autopayEnabled: false,
                    autopayNote: "",
                    isActive: true,
                    createdAt: .now,
                    updatedAt: .now
                )
            ],
            cycles: [],
            reminders: [],
            proofs: [
                BackupPayload.ProofRecord(
                    id: UUID(),
                    fileURLString: "file:///tmp/proof.jpg",
                    fileType: "jpg",
                    uploadedAt: .now,
                    cycleID: missingCycleID
                )
            ],
            providerActions: []
        )

        XCTAssertThrowsError(try BackupService.validate(payload: payload)) { error in
            guard case BackupValidationError.missingProofCycleReference = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRestoreReplacesExistingData() async throws {
        let (context, _) = try makeInMemoryContext()
        let notificationService = ReminderNotificationService(center: BackupFakeNotificationCenter())

        let staleBill = BillItem(category: .telcoBill, providerName: "Old", nickname: "Old", dueDay: 1)
        context.insert(staleBill)
        try context.save()

        let billID = UUID()
        let cycleID = UUID()
        let payload = BackupPayload(
            schemaVersion: BackupService.currentSchemaVersion,
            exportedAt: .now,
            users: [
                BackupPayload.UserRecord(
                    id: UUID(),
                    email: "local-user@billduetracker.local",
                    timezoneIdentifier: "Asia/Singapore",
                    createdAt: .now,
                    enabledReminderStagesRaw: "[\"SEVEN_DAY\",\"THREE_DAY\",\"ONE_DAY\",\"DUE_DAY\",\"OVERDUE\"]",
                    customProvidersByCategoryRaw: "{}"
                )
            ],
            bills: [
                BackupPayload.BillRecord(
                    id: billID,
                    categoryRaw: BillCategory.utilityBill.rawValue,
                    providerName: "SP Group",
                    nickname: "Utilities",
                    dueDay: 12,
                    dueDateRuleRaw: DueDateRule.endOfMonthClamp.rawValue,
                    billingCadenceRaw: BillingCadence.monthly.rawValue,
                    annualDueMonth: nil,
                    currency: "SGD",
                    expectedAmount: 140.0,
                    autopayEnabled: false,
                    autopayNote: "",
                    isActive: true,
                    createdAt: .now,
                    updatedAt: .now
                )
            ],
            cycles: [
                BackupPayload.CycleRecord(
                    id: cycleID,
                    cycleMonth: "2026-03",
                    dueDate: .now,
                    reminderStateRaw: ReminderStage.sevenDay.rawValue,
                    paymentStateRaw: PaymentState.unpaid.rawValue,
                    paidAt: nil,
                    overdueStartedAt: nil,
                    billID: billID
                )
            ],
            reminders: [],
            proofs: [],
            providerActions: []
        )

        _ = try await BackupService.restore(
            payload: payload,
            context: context,
            notificationService: notificationService,
            now: .now
        )

        let bills = try context.fetch(FetchDescriptor<BillItem>())
        XCTAssertEqual(bills.count, 1)
        XCTAssertEqual(bills.first?.providerName, "SP Group")
        XCTAssertEqual(bills.first?.nickname, "Utilities")
    }

    func testRestoreCanReplaceExistingRowsWithSameBillID() async throws {
        let (context, _) = try makeInMemoryContext()
        let notificationService = ReminderNotificationService(center: BackupFakeNotificationCenter())

        let sharedBillID = UUID()
        let existingBill = BillItem(
            id: sharedBillID,
            category: .telcoBill,
            providerName: "Old Provider",
            nickname: "Old",
            dueDay: 1
        )
        context.insert(existingBill)
        try context.save()

        let payload = BackupPayload(
            schemaVersion: BackupService.currentSchemaVersion,
            exportedAt: .now,
            users: [],
            bills: [
                BackupPayload.BillRecord(
                    id: sharedBillID,
                    categoryRaw: BillCategory.utilityBill.rawValue,
                    providerName: "SP Group",
                    nickname: "Utilities",
                    dueDay: 12,
                    dueDateRuleRaw: DueDateRule.endOfMonthClamp.rawValue,
                    billingCadenceRaw: BillingCadence.monthly.rawValue,
                    annualDueMonth: nil,
                    currency: "SGD",
                    expectedAmount: 140.0,
                    autopayEnabled: false,
                    autopayNote: "",
                    isActive: true,
                    createdAt: .now,
                    updatedAt: .now
                )
            ],
            cycles: [],
            reminders: [],
            proofs: [],
            providerActions: []
        )

        _ = try await BackupService.restore(
            payload: payload,
            context: context,
            notificationService: notificationService,
            now: .now
        )

        let bills = try context.fetch(FetchDescriptor<BillItem>())
        XCTAssertEqual(bills.count, 1)
        XCTAssertEqual(bills.first?.id, sharedBillID)
        XCTAssertEqual(bills.first?.providerName, "SP Group")
        XCTAssertEqual(bills.first?.nickname, "Utilities")
    }

    func testRestoreFailsPreflightAndPreservesExistingData() async throws {
        let (context, _) = try makeInMemoryContext()
        let notificationService = ReminderNotificationService(center: BackupFakeNotificationCenter())

        let existingBill = BillItem(
            category: .creditCardDue,
            providerName: "DBS",
            nickname: "Existing",
            dueDay: 8
        )
        context.insert(existingBill)
        try context.save()

        let duplicateBillID = UUID()
        let payload = BackupPayload(
            schemaVersion: BackupService.currentSchemaVersion,
            exportedAt: .now,
            users: [],
            bills: [
                BackupPayload.BillRecord(
                    id: duplicateBillID,
                    categoryRaw: BillCategory.utilityBill.rawValue,
                    providerName: "SP Group",
                    nickname: "Utilities A",
                    dueDay: 10,
                    dueDateRuleRaw: DueDateRule.endOfMonthClamp.rawValue,
                    billingCadenceRaw: BillingCadence.monthly.rawValue,
                    annualDueMonth: nil,
                    currency: "SGD",
                    expectedAmount: nil,
                    autopayEnabled: false,
                    autopayNote: "",
                    isActive: true,
                    createdAt: .now,
                    updatedAt: .now
                ),
                BackupPayload.BillRecord(
                    id: duplicateBillID,
                    categoryRaw: BillCategory.telcoBill.rawValue,
                    providerName: "M1",
                    nickname: "Utilities B",
                    dueDay: 11,
                    dueDateRuleRaw: DueDateRule.endOfMonthClamp.rawValue,
                    billingCadenceRaw: BillingCadence.monthly.rawValue,
                    annualDueMonth: nil,
                    currency: "SGD",
                    expectedAmount: nil,
                    autopayEnabled: false,
                    autopayNote: "",
                    isActive: true,
                    createdAt: .now,
                    updatedAt: .now
                )
            ],
            cycles: [],
            reminders: [],
            proofs: [],
            providerActions: []
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await BackupService.restore(
                payload: payload,
                context: context,
                notificationService: notificationService,
                now: .now
            )
        } validateError: { error in
            guard case BackupValidationError.duplicateBillID = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }

        let bills = try context.fetch(FetchDescriptor<BillItem>())
        XCTAssertEqual(bills.count, 1)
        XCTAssertEqual(bills.first?.providerName, "DBS")
    }

    func testRestoreFreeTierDeterministicallyDeactivatesExcessActiveBills() async throws {
        let (context, _) = try makeInMemoryContext()
        let notificationService = ReminderNotificationService(center: BackupFakeNotificationCenter())
        let baseTime = Date(timeIntervalSince1970: 1_700_000_000)

        let billIDs = (0..<10).map { _ in UUID() }
        let billRecords = billIDs.enumerated().map { index, billID in
            BackupPayload.BillRecord(
                id: billID,
                categoryRaw: BillCategory.utilityBill.rawValue,
                providerName: "Provider \(index)",
                nickname: "Bill \(index)",
                dueDay: 12,
                dueDateRuleRaw: DueDateRule.endOfMonthClamp.rawValue,
                billingCadenceRaw: BillingCadence.monthly.rawValue,
                annualDueMonth: nil,
                currency: "SGD",
                expectedAmount: nil,
                autopayEnabled: false,
                autopayNote: "",
                isActive: true,
                createdAt: baseTime.addingTimeInterval(TimeInterval(index)),
                updatedAt: baseTime.addingTimeInterval(TimeInterval(index))
            )
        }

        let payload = BackupPayload(
            schemaVersion: BackupService.currentSchemaVersion,
            exportedAt: .now,
            users: [],
            bills: billRecords,
            cycles: [],
            reminders: [],
            proofs: [],
            providerActions: []
        )

        let report = try await BackupService.restore(
            payload: payload,
            context: context,
            notificationService: notificationService,
            subscriptionTier: .free,
            now: baseTime
        )

        let bills = try context.fetch(FetchDescriptor<BillItem>())
        XCTAssertEqual(bills.count, 10)
        XCTAssertEqual(bills.filter(\.isActive).count, UsageLimitService.freeActiveBillLimit)
        XCTAssertEqual(report.deactivatedBillCount, 2)

        let expectedDeactivatedIDs = [billIDs[1], billIDs[0]]
        XCTAssertEqual(report.deactivatedBillIDs, expectedDeactivatedIDs)

        let deactivatedBills = bills.filter { expectedDeactivatedIDs.contains($0.id) }
        XCTAssertEqual(deactivatedBills.count, 2)
        XCTAssertTrue(deactivatedBills.allSatisfy { !$0.isActive })
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

private func XCTAssertThrowsErrorAsync(
    _ expression: @escaping () async throws -> Void,
    validateError: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        try await expression()
        XCTFail("Expected expression to throw an error", file: file, line: line)
    } catch {
        validateError(error)
    }
}

@MainActor
private final class BackupFakeNotificationCenter: UserNotificationCentering {
    func requestAuthorization(options _: UNAuthorizationOptions) async throws -> Bool { true }
    func add(_: UNNotificationRequest) async throws {}
    func removePendingNotificationRequests(withIdentifiers _: [String]) {}
    func removeAllPendingNotificationRequests() {}
    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
}
