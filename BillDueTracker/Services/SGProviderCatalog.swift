import Foundation

struct ProviderTemplate: Identifiable, Hashable {
    var id: String { "\(category.rawValue)-\(providerName)-\(actionLabel)" }
    let category: BillCategory
    let providerName: String
    let actionLabel: String
    let urlString: String
}

enum SGProviderCatalog {
    static let templates: [ProviderTemplate] = [
        ProviderTemplate(category: .utilityBill, providerName: "SP Group", actionLabel: "Open SP Utilities Portal", urlString: "https://www.spgroup.com.sg"),
        ProviderTemplate(category: .utilityBill, providerName: "PUB", actionLabel: "Open PUB Portal", urlString: "https://www.pub.gov.sg"),
        ProviderTemplate(category: .utilityBill, providerName: "Senoko Energy", actionLabel: "Open Senoko Portal", urlString: "https://www.senokoenergy.com"),
        ProviderTemplate(category: .utilityBill, providerName: "Geneco", actionLabel: "Open Geneco Portal", urlString: "https://www.geneco.sg"),
        ProviderTemplate(category: .utilityBill, providerName: "Tuas Power", actionLabel: "Open Tuas Portal", urlString: "https://www.tuaspower.com.sg"),

        ProviderTemplate(category: .telcoBill, providerName: "Singtel", actionLabel: "Open Singtel App/Portal", urlString: "https://www.singtel.com"),
        ProviderTemplate(category: .telcoBill, providerName: "StarHub", actionLabel: "Open StarHub App/Portal", urlString: "https://www.starhub.com"),
        ProviderTemplate(category: .telcoBill, providerName: "M1", actionLabel: "Open M1 App/Portal", urlString: "https://www.m1.com.sg"),
        ProviderTemplate(category: .telcoBill, providerName: "SIMBA", actionLabel: "Open SIMBA App/Portal", urlString: "https://www.simba.sg"),
        ProviderTemplate(category: .telcoBill, providerName: "Circles.Life", actionLabel: "Open Circles Portal", urlString: "https://www.circles.life/sg"),

        ProviderTemplate(category: .creditCardDue, providerName: "DBS/POSB", actionLabel: "Open DBS Digibank", urlString: "https://www.dbs.com.sg"),
        ProviderTemplate(category: .creditCardDue, providerName: "UOB", actionLabel: "Open UOB TMRW", urlString: "https://www.uob.com.sg"),
        ProviderTemplate(category: .creditCardDue, providerName: "OCBC", actionLabel: "Open OCBC Digital", urlString: "https://www.ocbc.com"),
        ProviderTemplate(category: .creditCardDue, providerName: "Citi", actionLabel: "Open Citi Mobile", urlString: "https://www.citibank.com.sg"),
        ProviderTemplate(category: .creditCardDue, providerName: "HSBC", actionLabel: "Open HSBC App", urlString: "https://www.hsbc.com.sg"),
        ProviderTemplate(category: .creditCardDue, providerName: "Standard Chartered", actionLabel: "Open SC Mobile", urlString: "https://www.sc.com/sg"),
        ProviderTemplate(category: .creditCardDue, providerName: "Maybank", actionLabel: "Open Maybank2u", urlString: "https://www.maybank2u.com.sg"),
        ProviderTemplate(category: .creditCardDue, providerName: "Trust", actionLabel: "Open Trust App", urlString: "https://trustbank.sg"),

        ProviderTemplate(category: .subscriptionDue, providerName: "Netflix", actionLabel: "Open Netflix Account", urlString: "https://www.netflix.com/account"),
        ProviderTemplate(category: .subscriptionDue, providerName: "Spotify", actionLabel: "Open Spotify Account", urlString: "https://www.spotify.com/account"),
        ProviderTemplate(category: .subscriptionDue, providerName: "YouTube Premium", actionLabel: "Open Google Subscriptions", urlString: "https://payments.google.com"),
        ProviderTemplate(category: .subscriptionDue, providerName: "Apple iCloud+", actionLabel: "Open Apple Subscriptions", urlString: "https://apps.apple.com/account/subscriptions"),
        ProviderTemplate(category: .subscriptionDue, providerName: "Disney+", actionLabel: "Open Disney+ Account", urlString: "https://www.disneyplus.com/account"),
        ProviderTemplate(category: .subscriptionDue, providerName: "Amazon Prime", actionLabel: "Open Prime Membership", urlString: "https://www.amazon.sg/prime"),
        ProviderTemplate(category: .subscriptionDue, providerName: "Adobe Creative Cloud", actionLabel: "Open Adobe Plans", urlString: "https://account.adobe.com/plans"),
        ProviderTemplate(category: .subscriptionDue, providerName: "Notion", actionLabel: "Open Notion Billing", urlString: "https://www.notion.so/my-account")
    ]

    static func providers(for category: BillCategory) -> [String] {
        Array(Set(templates.filter { $0.category == category }.map(\.providerName))).sorted()
    }

    static func actions(for category: BillCategory, providerName: String) -> [ProviderTemplate] {
        templates.filter {
            $0.category == category && $0.providerName.caseInsensitiveCompare(providerName) == .orderedSame
        }
    }

    static var allProviderNames: [String] {
        Array(Set(templates.map(\.providerName))).sorted()
    }
}
