import Foundation
import SwiftData

@MainActor
enum ProviderActionSeeder {
    static func seedIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<ProviderAction>()
        let existing = (try? context.fetch(descriptor)) ?? []
        let existingKeys = Set(existing.map(\.seedKey))

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
        }

        try? context.save()
    }
}
