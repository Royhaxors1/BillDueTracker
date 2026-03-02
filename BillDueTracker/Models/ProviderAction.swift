import Foundation
import SwiftData

@Model
final class ProviderAction {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String
    var providerName: String
    var countryCode: String
    var actionLabel: String
    var urlString: String
    var isActive: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        category: BillCategory,
        providerName: String,
        countryCode: String = "SG",
        actionLabel: String,
        urlString: String,
        isActive: Bool = true,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.categoryRaw = category.rawValue
        self.providerName = providerName
        self.countryCode = countryCode
        self.actionLabel = actionLabel
        self.urlString = urlString
        self.isActive = isActive
        self.updatedAt = updatedAt
    }

    var category: BillCategory {
        get { BillCategory(rawValue: categoryRaw) ?? .utilityBill }
        set { categoryRaw = newValue.rawValue }
    }

    var url: URL? {
        URL(string: urlString)
    }

    var seedKey: String {
        Self.seedKey(
            categoryRaw: categoryRaw,
            providerName: providerName,
            actionLabel: actionLabel,
            urlString: urlString
        )
    }

    static func seedKey(
        categoryRaw: String,
        providerName: String,
        actionLabel: String,
        urlString: String
    ) -> String {
        [categoryRaw, providerName, actionLabel, urlString].joined(separator: "|")
    }
}
