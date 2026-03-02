import Foundation
import SwiftData

struct BackupPayload: Codable {
    let schemaVersion: Int
    let exportedAt: Date
    let users: [UserRecord]
    let bills: [BillRecord]
    let cycles: [CycleRecord]
    let reminders: [ReminderRecord]
    let proofs: [ProofRecord]
    let providerActions: [ProviderActionRecord]

    struct UserRecord: Codable {
        let id: UUID
        let email: String
        let timezoneIdentifier: String
        let createdAt: Date
        let enabledReminderStagesRaw: String
        let customProvidersByCategoryRaw: String
    }

    struct BillRecord: Codable {
        let id: UUID
        let categoryRaw: String
        let providerName: String
        let nickname: String
        let dueDay: Int
        let dueDateRuleRaw: String
        let billingCadenceRaw: String
        let annualDueMonth: Int?
        let currency: String
        let expectedAmount: Double?
        let autopayEnabled: Bool
        let autopayNote: String
        let isActive: Bool
        let createdAt: Date
        let updatedAt: Date
    }

    struct CycleRecord: Codable {
        let id: UUID
        let cycleMonth: String
        let dueDate: Date
        let reminderStateRaw: String
        let paymentStateRaw: String
        let paidAt: Date?
        let overdueStartedAt: Date?
        let billID: UUID
    }

    struct ReminderRecord: Codable {
        let id: UUID
        let stageRaw: String
        let scheduledAt: Date
        let sentAt: Date?
        let deliveryStatusRaw: String
        let cycleID: UUID
    }

    struct ProofRecord: Codable {
        let id: UUID
        let fileURLString: String
        let fileType: String
        let uploadedAt: Date
        let cycleID: UUID
    }

    struct ProviderActionRecord: Codable {
        let id: UUID
        let categoryRaw: String
        let providerName: String
        let countryCode: String
        let actionLabel: String
        let urlString: String
        let isActive: Bool
        let updatedAt: Date
    }
}

struct BackupRestoreReport {
    let users: Int
    let bills: Int
    let cycles: Int
    let reminders: Int
    let proofs: Int
    let providerActions: Int
    let deactivatedBillIDs: [UUID]

    var deactivatedBillCount: Int {
        deactivatedBillIDs.count
    }
}

enum BackupValidationError: LocalizedError {
    case unsupportedSchema(version: Int)
    case duplicateUserID(userID: UUID)
    case duplicateBillID(billID: UUID)
    case duplicateCycleID(cycleID: UUID)
    case duplicateReminderID(reminderID: UUID)
    case duplicateProofID(proofID: UUID)
    case duplicateProviderActionID(actionID: UUID)
    case missingBillReference(cycleID: UUID, billID: UUID)
    case missingCycleReference(reminderID: UUID, cycleID: UUID)
    case missingProofCycleReference(proofID: UUID, cycleID: UUID)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            return "Unsupported backup schema version: \(version)."
        case let .duplicateUserID(userID):
            return "Backup contains duplicate user id \(userID.uuidString)."
        case let .duplicateBillID(billID):
            return "Backup contains duplicate bill id \(billID.uuidString)."
        case let .duplicateCycleID(cycleID):
            return "Backup contains duplicate cycle id \(cycleID.uuidString)."
        case let .duplicateReminderID(reminderID):
            return "Backup contains duplicate reminder id \(reminderID.uuidString)."
        case let .duplicateProofID(proofID):
            return "Backup contains duplicate proof id \(proofID.uuidString)."
        case let .duplicateProviderActionID(actionID):
            return "Backup contains duplicate provider action id \(actionID.uuidString)."
        case let .missingBillReference(cycleID, billID):
            return "Backup cycle \(cycleID.uuidString) references missing bill \(billID.uuidString)."
        case let .missingCycleReference(reminderID, cycleID):
            return "Backup reminder \(reminderID.uuidString) references missing cycle \(cycleID.uuidString)."
        case let .missingProofCycleReference(proofID, cycleID):
            return "Backup proof \(proofID.uuidString) references missing cycle \(cycleID.uuidString)."
        }
    }
}

@MainActor
enum BackupService {
    static let currentSchemaVersion = 2

    static func buildPayload(context: ModelContext, exportedAt: Date = .now) throws -> BackupPayload {
        let users = try context.fetch(FetchDescriptor<UserProfile>())
        let bills = try context.fetch(FetchDescriptor<BillItem>())
        let cycles = try context.fetch(FetchDescriptor<BillCycle>())
        let reminders = try context.fetch(FetchDescriptor<ReminderEvent>())
        let proofs = try context.fetch(FetchDescriptor<PaymentProof>())
        let providerActions = try context.fetch(FetchDescriptor<ProviderAction>())

        return BackupPayload(
            schemaVersion: currentSchemaVersion,
            exportedAt: exportedAt,
            users: users.map {
                BackupPayload.UserRecord(
                    id: $0.id,
                    email: $0.email,
                    timezoneIdentifier: $0.timezoneIdentifier,
                    createdAt: $0.createdAt,
                    enabledReminderStagesRaw: $0.enabledReminderStagesRaw,
                    customProvidersByCategoryRaw: $0.customProvidersByCategoryRaw
                )
            },
            bills: bills.map {
                BackupPayload.BillRecord(
                    id: $0.id,
                    categoryRaw: $0.categoryRaw,
                    providerName: $0.providerName,
                    nickname: $0.nickname,
                    dueDay: $0.dueDay,
                    dueDateRuleRaw: $0.dueDateRuleRaw,
                    billingCadenceRaw: $0.billingCadenceRaw,
                    annualDueMonth: $0.annualDueMonth,
                    currency: $0.currency,
                    expectedAmount: $0.expectedAmount,
                    autopayEnabled: $0.autopayEnabled,
                    autopayNote: $0.autopayNote,
                    isActive: $0.isActive,
                    createdAt: $0.createdAt,
                    updatedAt: $0.updatedAt
                )
            },
            cycles: cycles.compactMap { cycle in
                guard let billID = cycle.billItem?.id else { return nil }
                return BackupPayload.CycleRecord(
                    id: cycle.id,
                    cycleMonth: cycle.cycleMonth,
                    dueDate: cycle.dueDate,
                    reminderStateRaw: cycle.reminderStateRaw,
                    paymentStateRaw: cycle.paymentStateRaw,
                    paidAt: cycle.paidAt,
                    overdueStartedAt: cycle.overdueStartedAt,
                    billID: billID
                )
            },
            reminders: reminders.compactMap { reminder in
                guard let cycleID = reminder.billCycle?.id else { return nil }
                return BackupPayload.ReminderRecord(
                    id: reminder.id,
                    stageRaw: reminder.stageRaw,
                    scheduledAt: reminder.scheduledAt,
                    sentAt: reminder.sentAt,
                    deliveryStatusRaw: reminder.deliveryStatusRaw,
                    cycleID: cycleID
                )
            },
            proofs: proofs.compactMap { proof in
                guard let cycleID = proof.billCycle?.id else { return nil }
                return BackupPayload.ProofRecord(
                    id: proof.id,
                    fileURLString: proof.fileURLString,
                    fileType: proof.fileType,
                    uploadedAt: proof.uploadedAt,
                    cycleID: cycleID
                )
            },
            providerActions: providerActions.map {
                BackupPayload.ProviderActionRecord(
                    id: $0.id,
                    categoryRaw: $0.categoryRaw,
                    providerName: $0.providerName,
                    countryCode: $0.countryCode,
                    actionLabel: $0.actionLabel,
                    urlString: $0.urlString,
                    isActive: $0.isActive,
                    updatedAt: $0.updatedAt
                )
            }
        )
    }

    static func data(for payload: BackupPayload) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }

    static func payload(from data: Data) throws -> BackupPayload {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let payload = try decoder.decode(BackupPayload.self, from: data)
        try validate(payload: payload)
        return payload
    }

    static func payload(from fileURL: URL) throws -> BackupPayload {
        let data = try Data(contentsOf: fileURL)
        return try payload(from: data)
    }

    static func writeBackup(
        payload: BackupPayload,
        directory: URL = FileManager.default.temporaryDirectory
    ) throws -> URL {
        let fileName = "bill-due-tracker-backup-\(Int(payload.exportedAt.timeIntervalSince1970)).json"
        let fileURL = directory.appendingPathComponent(fileName)
        let payloadData = try data(for: payload)
        try payloadData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    static func exportBackup(
        context: ModelContext,
        directory: URL = FileManager.default.temporaryDirectory,
        exportedAt: Date = .now
    ) throws -> URL {
        let payload = try buildPayload(context: context, exportedAt: exportedAt)
        return try writeBackup(payload: payload, directory: directory)
    }

    static func restore(
        payload: BackupPayload,
        context: ModelContext,
        notificationService: ReminderNotificationService,
        subscriptionTier: SubscriptionTier = .free,
        now: Date = .now
    ) async throws -> BackupRestoreReport {
        try validate(payload: payload)
        let restorePlan = try prepareRestorePlan(
            payload: payload,
            subscriptionTier: subscriptionTier,
            now: now
        )

        try deleteCurrentData(context: context)

        for user in restorePlan.users {
            context.insert(user)
        }
        for bill in restorePlan.bills {
            context.insert(bill)
        }
        for cycle in restorePlan.cycles {
            context.insert(cycle)
        }
        for reminder in restorePlan.reminders {
            context.insert(reminder)
        }
        for proof in restorePlan.proofs {
            context.insert(proof)
        }
        for action in restorePlan.providerActions {
            context.insert(action)
        }

        try ProviderActionSeeder.seedIfNeeded(context: context, saveChanges: false)
        try context.save()

        notificationService.cancelAll()

        for reminder in restorePlan.remindersToSchedule {
            guard let bill = reminder.billCycle?.billItem, bill.isActive else {
                continue
            }
            await notificationService.schedule(event: reminder, for: bill)
        }

        try context.save()
        return restorePlan.report
    }

    static func validate(payload: BackupPayload) throws {
        guard payload.schemaVersion == currentSchemaVersion else {
            throw BackupValidationError.unsupportedSchema(version: payload.schemaVersion)
        }

        if let duplicate = firstDuplicateID(in: payload.users.map(\.id)) {
            throw BackupValidationError.duplicateUserID(userID: duplicate)
        }
        if let duplicate = firstDuplicateID(in: payload.bills.map(\.id)) {
            throw BackupValidationError.duplicateBillID(billID: duplicate)
        }
        if let duplicate = firstDuplicateID(in: payload.cycles.map(\.id)) {
            throw BackupValidationError.duplicateCycleID(cycleID: duplicate)
        }
        if let duplicate = firstDuplicateID(in: payload.reminders.map(\.id)) {
            throw BackupValidationError.duplicateReminderID(reminderID: duplicate)
        }
        if let duplicate = firstDuplicateID(in: payload.proofs.map(\.id)) {
            throw BackupValidationError.duplicateProofID(proofID: duplicate)
        }
        if let duplicate = firstDuplicateID(in: payload.providerActions.map(\.id)) {
            throw BackupValidationError.duplicateProviderActionID(actionID: duplicate)
        }

        let billIDs = Set(payload.bills.map(\.id))
        let cycleIDs = Set(payload.cycles.map(\.id))

        for cycle in payload.cycles where !billIDs.contains(cycle.billID) {
            throw BackupValidationError.missingBillReference(cycleID: cycle.id, billID: cycle.billID)
        }

        for reminder in payload.reminders where !cycleIDs.contains(reminder.cycleID) {
            throw BackupValidationError.missingCycleReference(reminderID: reminder.id, cycleID: reminder.cycleID)
        }

        for proof in payload.proofs where !cycleIDs.contains(proof.cycleID) {
            throw BackupValidationError.missingProofCycleReference(proofID: proof.id, cycleID: proof.cycleID)
        }
    }

    private static func prepareRestorePlan(
        payload: BackupPayload,
        subscriptionTier: SubscriptionTier,
        now: Date
    ) throws -> RestorePlan {
        let gatedBills = gatedBillRecords(payload.bills, subscriptionTier: subscriptionTier)
        let deactivatedBillIDs = Set(gatedBills.deactivatedBillIDs)

        let users: [UserProfile]
        if payload.users.isEmpty {
            users = [
                UserProfile(
                    email: "local-user@billduetracker.local",
                    timezoneIdentifier: TimeZone.current.identifier,
                    createdAt: now
                )
            ]
        } else {
            users = payload.users.map {
                UserProfile(
                    id: $0.id,
                    email: $0.email,
                    timezoneIdentifier: $0.timezoneIdentifier,
                    createdAt: $0.createdAt,
                    enabledReminderStagesRaw: $0.enabledReminderStagesRaw,
                    customProvidersByCategoryRaw: $0.customProvidersByCategoryRaw
                )
            }
        }

        var billByID: [UUID: BillItem] = [:]
        let bills = gatedBills.records.map { billRecord in
            let bill = BillItem(
                id: billRecord.id,
                category: BillCategory(rawValue: billRecord.categoryRaw) ?? .utilityBill,
                providerName: billRecord.providerName,
                nickname: billRecord.nickname,
                dueDay: billRecord.dueDay,
                dueDateRule: DueDateRule(rawValue: billRecord.dueDateRuleRaw) ?? .endOfMonthClamp,
                billingCadence: BillingCadence(rawValue: billRecord.billingCadenceRaw) ?? .monthly,
                annualDueMonth: billRecord.annualDueMonth,
                currency: billRecord.currency,
                expectedAmount: billRecord.expectedAmount,
                autopayEnabled: billRecord.autopayEnabled,
                autopayNote: billRecord.autopayNote,
                isActive: billRecord.isActive,
                createdAt: billRecord.createdAt,
                updatedAt: billRecord.updatedAt
            )
            billByID[billRecord.id] = bill
            return bill
        }

        var cycleByID: [UUID: BillCycle] = [:]
        var billIDByCycleID: [UUID: UUID] = [:]
        var cycles: [BillCycle] = []
        cycles.reserveCapacity(payload.cycles.count)
        for cycleRecord in payload.cycles {
            guard let bill = billByID[cycleRecord.billID] else {
                throw BackupValidationError.missingBillReference(cycleID: cycleRecord.id, billID: cycleRecord.billID)
            }
            let cycle = BillCycle(
                id: cycleRecord.id,
                cycleMonth: cycleRecord.cycleMonth,
                dueDate: cycleRecord.dueDate,
                reminderState: ReminderStage(rawValue: cycleRecord.reminderStateRaw) ?? .sevenDay,
                paymentState: PaymentState(rawValue: cycleRecord.paymentStateRaw) ?? .unpaid,
                paidAt: cycleRecord.paidAt,
                overdueStartedAt: cycleRecord.overdueStartedAt,
                billItem: bill
            )
            cycles.append(cycle)
            cycleByID[cycleRecord.id] = cycle
            billIDByCycleID[cycleRecord.id] = cycleRecord.billID
        }

        var reminders: [ReminderEvent] = []
        reminders.reserveCapacity(payload.reminders.count)
        for reminderRecord in payload.reminders {
            guard let cycle = cycleByID[reminderRecord.cycleID] else {
                throw BackupValidationError.missingCycleReference(
                    reminderID: reminderRecord.id,
                    cycleID: reminderRecord.cycleID
                )
            }
            let reminder = ReminderEvent(
                id: reminderRecord.id,
                stage: ReminderStage(rawValue: reminderRecord.stageRaw) ?? .dueDay,
                scheduledAt: reminderRecord.scheduledAt,
                sentAt: reminderRecord.sentAt,
                deliveryStatus: ReminderDeliveryStatus(rawValue: reminderRecord.deliveryStatusRaw) ?? .pending,
                billCycle: cycle
            )
            if reminder.deliveryStatus == .pending,
               let billID = billIDByCycleID[reminderRecord.cycleID],
               deactivatedBillIDs.contains(billID) {
                reminder.deliveryStatus = .cancelled
            }
            reminders.append(reminder)
        }

        var proofs: [PaymentProof] = []
        proofs.reserveCapacity(payload.proofs.count)
        for proofRecord in payload.proofs {
            guard let cycle = cycleByID[proofRecord.cycleID] else {
                throw BackupValidationError.missingProofCycleReference(
                    proofID: proofRecord.id,
                    cycleID: proofRecord.cycleID
                )
            }
            proofs.append(
                PaymentProof(
                    id: proofRecord.id,
                    fileURLString: proofRecord.fileURLString,
                    fileType: proofRecord.fileType,
                    uploadedAt: proofRecord.uploadedAt,
                    billCycle: cycle
                )
            )
        }

        let providerActions = payload.providerActions.map { actionRecord in
            ProviderAction(
                id: actionRecord.id,
                category: BillCategory(rawValue: actionRecord.categoryRaw) ?? .utilityBill,
                providerName: actionRecord.providerName,
                countryCode: actionRecord.countryCode,
                actionLabel: actionRecord.actionLabel,
                urlString: actionRecord.urlString,
                isActive: actionRecord.isActive,
                updatedAt: actionRecord.updatedAt
            )
        }

        let remindersToSchedule = reminders.filter {
            guard $0.deliveryStatus == .pending, $0.scheduledAt >= now else {
                return false
            }
            return $0.billCycle?.billItem?.isActive == true
        }

        return RestorePlan(
            users: users,
            bills: bills,
            cycles: cycles,
            reminders: reminders,
            proofs: proofs,
            providerActions: providerActions,
            remindersToSchedule: remindersToSchedule,
            report: BackupRestoreReport(
                users: users.count,
                bills: bills.count,
                cycles: cycles.count,
                reminders: reminders.count,
                proofs: proofs.count,
                providerActions: providerActions.count,
                deactivatedBillIDs: gatedBills.deactivatedBillIDs
            )
        )
    }

    private static func gatedBillRecords(
        _ records: [BackupPayload.BillRecord],
        subscriptionTier: SubscriptionTier
    ) -> (records: [BackupPayload.BillRecord], deactivatedBillIDs: [UUID]) {
        guard subscriptionTier == .free else {
            return (records, [])
        }

        let active = records.filter(\.isActive)
        let limit = UsageLimitService.freeActiveBillLimit
        guard active.count > limit else {
            return (records, [])
        }

        let sortedActive = active.sorted { lhs, rhs in
            if lhs.updatedAt != rhs.updatedAt {
                return lhs.updatedAt > rhs.updatedAt
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }

        let keepActiveIDs = Set(sortedActive.prefix(limit).map(\.id))
        let deactivatedBillIDs = sortedActive
            .dropFirst(limit)
            .map(\.id)

        let gatedRecords = records.map { record in
            guard record.isActive, !keepActiveIDs.contains(record.id) else {
                return record
            }
            return BackupPayload.BillRecord(
                id: record.id,
                categoryRaw: record.categoryRaw,
                providerName: record.providerName,
                nickname: record.nickname,
                dueDay: record.dueDay,
                dueDateRuleRaw: record.dueDateRuleRaw,
                billingCadenceRaw: record.billingCadenceRaw,
                annualDueMonth: record.annualDueMonth,
                currency: record.currency,
                expectedAmount: record.expectedAmount,
                autopayEnabled: record.autopayEnabled,
                autopayNote: record.autopayNote,
                isActive: false,
                createdAt: record.createdAt,
                updatedAt: record.updatedAt
            )
        }
        return (gatedRecords, deactivatedBillIDs)
    }

    private static func firstDuplicateID(in ids: [UUID]) -> UUID? {
        var seen: Set<UUID> = []
        for id in ids {
            if !seen.insert(id).inserted {
                return id
            }
        }
        return nil
    }

    private static func deleteCurrentData(context: ModelContext) throws {
        let reminders = try context.fetch(FetchDescriptor<ReminderEvent>())
        let proofs = try context.fetch(FetchDescriptor<PaymentProof>())
        let cycles = try context.fetch(FetchDescriptor<BillCycle>())
        let bills = try context.fetch(FetchDescriptor<BillItem>())
        let actions = try context.fetch(FetchDescriptor<ProviderAction>())
        let users = try context.fetch(FetchDescriptor<UserProfile>())

        for entity in reminders { context.delete(entity) }
        for entity in proofs { context.delete(entity) }
        for entity in cycles { context.delete(entity) }
        for entity in bills { context.delete(entity) }
        for entity in actions { context.delete(entity) }
        for entity in users { context.delete(entity) }
    }

    private struct RestorePlan {
        let users: [UserProfile]
        let bills: [BillItem]
        let cycles: [BillCycle]
        let reminders: [ReminderEvent]
        let proofs: [PaymentProof]
        let providerActions: [ProviderAction]
        let remindersToSchedule: [ReminderEvent]
        let report: BackupRestoreReport
    }
}
