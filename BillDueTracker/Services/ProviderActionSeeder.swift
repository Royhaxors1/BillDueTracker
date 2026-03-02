import Foundation
import SwiftData

@MainActor
enum ProviderActionSeeder {
    static func seedIfNeeded(context: ModelContext, saveChanges: Bool = true) throws {
        let descriptor = FetchDescriptor<ProviderAction>()
        let existing = try context.fetch(descriptor)
        var existingKeys = Set(existing.map(\.seedKey))
        var insertedCount = 0

        for template in SGProviderCatalog.templates {
            let key = ProviderAction.seedKey(
                categoryRaw: template.category.rawValue,
                providerName: template.providerName,
                actionLabel: template.actionLabel,
                urlString: template.urlString
            )
            guard !existingKeys.contains(key) else { continue }

            let action = ProviderAction(
                category: template.category,
                providerName: template.providerName,
                actionLabel: template.actionLabel,
                urlString: template.urlString
            )
            context.insert(action)
            existingKeys.insert(key)
            insertedCount += 1
        }

        if saveChanges, insertedCount > 0 {
            try context.save()
        }
    }
}
