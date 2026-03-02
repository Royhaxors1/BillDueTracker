import Foundation
import SwiftData

@Model
final class PaymentProof {
    @Attribute(.unique) var id: UUID
    var fileURLString: String
    var fileType: String
    var uploadedAt: Date

    var billCycle: BillCycle?

    init(
        id: UUID = UUID(),
        fileURLString: String,
        fileType: String,
        uploadedAt: Date = .now,
        billCycle: BillCycle? = nil
    ) {
        self.id = id
        self.fileURLString = fileURLString
        self.fileType = fileType
        self.uploadedAt = uploadedAt
        self.billCycle = billCycle
    }

    var fileURL: URL? {
        URL(string: fileURLString)
    }
}
