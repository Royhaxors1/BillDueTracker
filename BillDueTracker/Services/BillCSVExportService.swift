import Foundation

enum BillCSVExportService {
    static let header = "provider_name,nickname,category,due_day,billing_cadence,expected_amount,is_active,updated_at"

    static func csvString(for bills: [BillItem]) -> String {
        var rows = [header]
        let formatter = ISO8601DateFormatter()
        let orderedBills = bills.sorted { $0.updatedAt > $1.updatedAt }

        for bill in orderedBills {
            let expectedAmount = bill.expectedAmount.map { String(format: "%.2f", $0) } ?? ""
            let columns = [
                csvSafe(bill.providerName),
                csvSafe(bill.nickname),
                csvSafe(bill.category.title),
                "\(bill.dueDay)",
                csvSafe(bill.billingCadence.title),
                expectedAmount,
                bill.isActive ? "true" : "false",
                formatter.string(from: bill.updatedAt)
            ]
            rows.append(columns.joined(separator: ","))
        }

        return rows.joined(separator: "\n")
    }

    static func writeCSV(
        for bills: [BillItem],
        directory: URL = FileManager.default.temporaryDirectory,
        now: Date = .now
    ) throws -> URL {
        let csv = csvString(for: bills)
        let fileURL = directory
            .appendingPathComponent("bill-due-tracker-export-\(Int(now.timeIntervalSince1970)).csv")
        try csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    static func csvSafe(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }
}
