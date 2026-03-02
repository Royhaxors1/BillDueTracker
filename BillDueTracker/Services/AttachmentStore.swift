import Foundation

struct AttachmentStore {
    enum StoreError: Error {
        case invalidDirectory
    }

    private let directoryName = "PaymentProofs"
    private let baseDirectoryURL: URL?

    init(baseDirectoryURL: URL? = nil) {
        self.baseDirectoryURL = baseDirectoryURL
    }

    func store(data: Data, fileExtension: String) throws -> URL {
        let directory = try proofDirectoryURL()
        let fileName = "proof-\(UUID().uuidString).\(fileExtension)"
        let destinationURL = directory.appendingPathComponent(fileName)
        try data.write(to: destinationURL, options: [.atomic])
        return destinationURL
    }

    func copy(from sourceURL: URL) throws -> URL {
        let directory = try proofDirectoryURL()
        let extensionPart = sourceURL.pathExtension.isEmpty ? "dat" : sourceURL.pathExtension
        let fileName = "proof-\(UUID().uuidString).\(extensionPart)"
        let destinationURL = directory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    func removeFileIfExists(at fileURL: URL) throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }

    private func proofDirectoryURL() throws -> URL {
        let resolvedBaseURL: URL
        if let baseDirectoryURL {
            resolvedBaseURL = baseDirectoryURL
        } else if let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            resolvedBaseURL = applicationSupportURL
        } else {
            throw StoreError.invalidDirectory
        }
        let directoryURL = resolvedBaseURL.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}
