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
}

enum BackupValidationError: LocalizedError {
    case unsupportedSchema(version: Int)
    case missingBillReference(cycleID: UUID, billID: UUID)
    case missingCycleReference(reminderID: UUID, cycleID: UUID)
    case missingProofCycleReference(proofID: UUID, cycleID: UUID)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSchema(version):
            return "Unsupported backup schema version: \(version)."
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
        now: Date = .now
    ) async throws -> BackupRestoreReport {
        try validate(payload: payload)

        notificationService.cancelAll()
        try deleteCurrentData(context: context)

        if payload.users.isEmpty {
            let user = UserProfile(
                email: "local-user@billduetracker.local",
                timezoneIdentifier: TimeZone.current.identifier,
                createdAt: now
            )
            context.insert(user)
        } else {
            for user in payload.users {
                context.insert(
                    UserProfile(
                        id: user.id,
                        email: user.email,
                        timezoneIdentifier: user.timezoneIdentifier,
                        createdAt: user.createdAt,
                        enabledReminderStagesRaw: user.enabledReminderStagesRaw,
                        customProvidersByCategoryRaw: user.customProvidersByCategoryRaw
                    )
                )
            }
        }

        var billByID: [UUID: BillItem] = [:]
        for bill in payload.bills {
            let billModel = BillItem(
                id: bill.id,
                category: BillCategory(rawValue: bill.categoryRaw) ?? .utilityBill,
                providerName: bill.providerName,
                nickname: bill.nickname,
                dueDay: bill.dueDay,
                dueDateRule: DueDateRule(rawValue: bill.dueDateRuleRaw) ?? .endOfMonthClamp,
                billingCadence: BillingCadence(rawValue: bill.billingCadenceRaw) ?? .monthly,
                annualDueMonth: bill.annualDueMonth,
                currency: bill.currency,
                expectedAmount: bill.expectedAmount,
                autopayEnabled: bill.autopayEnabled,
                autopayNote: bill.autopayNote,
                isActive: bill.isActive,
                createdAt: bill.createdAt,
                updatedAt: bill.updatedAt
            )
            context.insert(billModel)
            billByID[bill.id] = billModel
        }

        var cycleByID: [UUID: BillCycle] = [:]
        for cycle in payload.cycles {
            let cycleModel = BillCycle(
                id: cycle.id,
                cycleMonth: cycle.cycleMonth,
                dueDate: cycle.dueDate,
                reminderState: ReminderStage(rawValue: cycle.reminderStateRaw) ?? .sevenDay,
                paymentState: PaymentState(rawValue: cycle.paymentStateRaw) ?? .unpaid,
                paidAt: cycle.paidAt,
                overdueStartedAt: cycle.overdueStartedAt,
                billItem: billByID[cycle.billID]
            )
            context.insert(cycleModel)
            cycleByID[cycle.id] = cycleModel
        }

        var restoredReminders: [ReminderEvent] = []
        for reminder in payload.reminders {
            let reminderModel = ReminderEvent(
                id: reminder.id,
                stage: ReminderStage(rawValue: reminder.stageRaw) ?? .dueDay,
                scheduledAt: reminder.scheduledAt,
                sentAt: reminder.sentAt,
                deliveryStatus: ReminderDeliveryStatus(rawValue: reminder.deliveryStatusRaw) ?? .pending,
                billCycle: cycleByID[reminder.cycleID]
            )
            context.insert(reminderModel)
            restoredReminders.append(reminderModel)
        }

        for proof in payload.proofs {
            context.insert(
                PaymentProof(
                    id: proof.id,
                    fileURLString: proof.fileURLString,
                    fileType: proof.fileType,
                    uploadedAt: proof.uploadedAt,
                    billCycle: cycleByID[proof.cycleID]
                )
            )
        }

        for action in payload.providerActions {
            context.insert(
                ProviderAction(
                    id: action.id,
                    category: BillCategory(rawValue: action.categoryRaw) ?? .utilityBill,
                    providerName: action.providerName,
                    countryCode: action.countryCode,
                    actionLabel: action.actionLabel,
                    urlString: action.urlString,
                    isActive: action.isActive,
                    updatedAt: action.updatedAt
                )
            )
        }

        try context.save()

        for reminder in restoredReminders {
            guard reminder.deliveryStatus == .pending,
                  reminder.scheduledAt >= now,
                  let bill = reminder.billCycle?.billItem else {
                continue
            }
            await notificationService.schedule(event: reminder, for: bill)
        }

        ProviderActionSeeder.seedIfNeeded(context: context)
        try context.save()

        return BackupRestoreReport(
            users: payload.users.count,
            bills: payload.bills.count,
            cycles: payload.cycles.count,
            reminders: payload.reminders.count,
            proofs: payload.proofs.count,
            providerActions: payload.providerActions.count
        )
    }

    static func validate(payload: BackupPayload) throws {
        guard payload.schemaVersion == currentSchemaVersion else {
            throw BackupValidationError.unsupportedSchema(version: payload.schemaVersion)
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

        try context.save()
    }
}
