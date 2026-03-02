import XCTest
@testable import BillDueTracker

final class AttachmentStoreTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AttachmentStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempDirectory, FileManager.default.fileExists(atPath: tempDirectory.path) {
            try FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        try super.tearDownWithError()
    }

    func testStoreWritesDataToPaymentProofDirectory() throws {
        let store = AttachmentStore(baseDirectoryURL: tempDirectory)
        let payload = Data("proof-data".utf8)

        let storedURL = try store.store(data: payload, fileExtension: "txt")

        XCTAssertTrue(FileManager.default.fileExists(atPath: storedURL.path))
        XCTAssertTrue(storedURL.path.contains("PaymentProofs"))
        XCTAssertEqual(try Data(contentsOf: storedURL), payload)
    }

    func testCopyCreatesIndependentFileInPaymentProofDirectory() throws {
        let store = AttachmentStore(baseDirectoryURL: tempDirectory)
        let sourceURL = tempDirectory.appendingPathComponent("source.pdf")
        let sourcePayload = Data("source-pdf".utf8)
        try sourcePayload.write(to: sourceURL, options: .atomic)

        let copiedURL = try store.copy(from: sourceURL)

        XCTAssertNotEqual(copiedURL, sourceURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: copiedURL.path))
        XCTAssertTrue(copiedURL.path.contains("PaymentProofs"))
        XCTAssertEqual(try Data(contentsOf: copiedURL), sourcePayload)
    }

    func testRemoveFileIfExistsIsIdempotent() throws {
        let store = AttachmentStore(baseDirectoryURL: tempDirectory)
        let storedURL = try store.store(data: Data("delete-me".utf8), fileExtension: "tmp")

        try store.removeFileIfExists(at: storedURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: storedURL.path))

        XCTAssertNoThrow(try store.removeFileIfExists(at: storedURL))
    }
}
