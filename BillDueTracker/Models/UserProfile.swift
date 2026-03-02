import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var email: String
    var timezoneIdentifier: String
    var createdAt: Date
    var lastReminderReconciledAt: Date?
    var lastReminderScheduleSuccessAt: Date?
    var enabledReminderStagesRaw: String = UserProfile.defaultEnabledReminderStagesRaw
    var customProvidersByCategoryRaw: String = UserProfile.defaultCustomProvidersByCategoryRaw

    init(
        id: UUID = UUID(),
        email: String,
        timezoneIdentifier: String,
        createdAt: Date = .now,
        lastReminderReconciledAt: Date? = nil,
        lastReminderScheduleSuccessAt: Date? = nil,
        enabledReminderStagesRaw: String = UserProfile.defaultEnabledReminderStagesRaw,
        customProvidersByCategoryRaw: String = UserProfile.defaultCustomProvidersByCategoryRaw
    ) {
        self.id = id
        self.email = email
        self.timezoneIdentifier = timezoneIdentifier
        self.createdAt = createdAt
        self.lastReminderReconciledAt = lastReminderReconciledAt
        self.lastReminderScheduleSuccessAt = lastReminderScheduleSuccessAt
        self.enabledReminderStagesRaw = enabledReminderStagesRaw
        self.customProvidersByCategoryRaw = customProvidersByCategoryRaw
    }

    var enabledReminderStages: Set<ReminderStage> {
        get {
            guard let rawStages = UserProfile.decodeStringArray(from: enabledReminderStagesRaw) else {
                return Set(ReminderStage.allCases)
            }
            return Set(rawStages.compactMap(ReminderStage.init(rawValue:)))
        }
        set {
            let orderedStages = ReminderStage.allCases
                .filter { newValue.contains($0) }
                .map(\.rawValue)
            enabledReminderStagesRaw = UserProfile.encodeStringArray(orderedStages)
        }
    }

    var customProvidersByCategory: [BillCategory: [String]] {
        get {
            guard let rawMap = UserProfile.decodeStringMap(from: customProvidersByCategoryRaw) else {
                return [:]
            }

            var providersByCategory: [BillCategory: [String]] = [:]
            for (categoryRaw, providers) in rawMap {
                guard let category = BillCategory(rawValue: categoryRaw) else { continue }
                providersByCategory[category] = UserProfile.normalizedProviderList(providers)
            }
            return providersByCategory
        }
        set {
            var encoded: [String: [String]] = [:]
            for category in BillCategory.allCases {
                let providers = UserProfile.normalizedProviderList(newValue[category] ?? [])
                if !providers.isEmpty {
                    encoded[category.rawValue] = providers
                }
            }
            customProvidersByCategoryRaw = UserProfile.encodeStringMap(encoded)
        }
    }

    func isReminderStageEnabled(_ stage: ReminderStage) -> Bool {
        enabledReminderStages.contains(stage)
    }

    func setReminderStage(_ stage: ReminderStage, isEnabled: Bool) {
        var enabledStages = enabledReminderStages
        if isEnabled {
            enabledStages.insert(stage)
        } else {
            enabledStages.remove(stage)
        }
        enabledReminderStages = enabledStages
    }

    func providers(for category: BillCategory) -> [String] {
        customProvidersByCategory[category] ?? []
    }

    @discardableResult
    func addCustomProvider(_ providerName: String, for category: BillCategory) -> Bool {
        let trimmed = providerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        var providersByCategory = customProvidersByCategory
        var providers = providersByCategory[category] ?? []
        let alreadyExists = providers.contains {
            $0.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        guard !alreadyExists else { return false }

        providers.append(trimmed)
        providersByCategory[category] = UserProfile.normalizedProviderList(providers)
        customProvidersByCategory = providersByCategory
        return true
    }

    private static var defaultEnabledReminderStagesRaw: String {
        encodeStringArray(ReminderStage.allCases.map(\.rawValue))
    }

    private static var defaultCustomProvidersByCategoryRaw: String {
        encodeStringMap([:])
    }

    private static func normalizedProviderList(_ providers: [String]) -> [String] {
        var normalized: [String] = []
        for provider in providers {
            let trimmed = provider.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let alreadyExists = normalized.contains {
                $0.caseInsensitiveCompare(trimmed) == .orderedSame
            }
            if !alreadyExists {
                normalized.append(trimmed)
            }
        }
        return normalized.sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
    }

    private static func encodeStringArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let encoded = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return encoded
    }

    private static func decodeStringArray(from rawValue: String) -> [String]? {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return ReminderStage.allCases.map(\.rawValue)
        }

        guard let data = normalized.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return nil
        }
        return decoded
    }

    private static func encodeStringMap(_ values: [String: [String]]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let encoded = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return encoded
    }

    private static func decodeStringMap(from rawValue: String) -> [String: [String]]? {
        let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.isEmpty {
            return [:]
        }

        guard let data = normalized.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) else {
            return nil
        }
        return decoded
    }
}
