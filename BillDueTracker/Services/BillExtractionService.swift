import Foundation
import PDFKit
@preconcurrency import Vision
import UIKit

struct BillExtractionResult {
    var dueDay: Int?
    var amount: Double?
    var providerHint: String?
    var confidence: ExtractionConfidence
    var rawText: String
}

enum BillExtractionService {
    static func extractFromImageData(_ data: Data) async throws -> BillExtractionResult {
        guard let image = UIImage(data: data), let cgImage = image.cgImage else {
            return extractFromText("")
        }

        let text = try await recognizeText(cgImage: cgImage)
        return extractFromText(text)
    }

    static func extractFromPDF(url: URL) -> BillExtractionResult {
        guard let document = PDFDocument(url: url) else {
            return extractFromText("")
        }
        var aggregate = ""
        for index in 0..<document.pageCount {
            aggregate += document.page(at: index)?.string ?? ""
            aggregate += "\n"
        }
        return extractFromText(aggregate)
    }

    static func extractFromText(_ text: String) -> BillExtractionResult {
        let normalized = text.replacingOccurrences(of: "\n", with: " ")
        let dueDay = parseDueDay(text: normalized)
        let amount = parseAmount(text: normalized)
        let provider = parseProvider(text: normalized)

        let confidence: ExtractionConfidence
        if dueDay != nil, amount != nil {
            confidence = .high
        } else if dueDay != nil || amount != nil {
            confidence = .medium
        } else {
            confidence = .low
        }

        return BillExtractionResult(
            dueDay: dueDay,
            amount: amount,
            providerHint: provider,
            confidence: confidence,
            rawText: normalized
        )
    }

    private static func recognizeText(cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let handler = VNImageRequestHandler(cgImage: cgImage)
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func parseDueDay(text: String) -> Int? {
        let dueRegexPatterns = [
            "(?i)due\\s*(?:date)?\\s*[:\\-]?\\s*(\\d{1,2})",
            "(?i)due\\s*on\\s*(\\d{1,2})",
            "(?i)pay\\s*by\\s*(\\d{1,2})"
        ]

        for pattern in dueRegexPatterns {
            if let value = firstIntMatch(pattern: pattern, text: text), (1...31).contains(value) {
                return value
            }
        }

        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = detector?.matches(in: text, options: [], range: range) ?? []

        for match in matches {
            if let date = match.date {
                let day = Calendar.gregorian.component(.day, from: date)
                if (1...31).contains(day) {
                    return day
                }
            }
        }

        return nil
    }

    private static func parseAmount(text: String) -> Double? {
        let pattern = "(?i)(?:s\\$|sgd\\s*)?(\\d{1,5}(?:\\.\\d{1,2})?)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(location: 0, length: text.utf16.count)
        let matches = regex.matches(in: text, options: [], range: range)

        let values: [Double] = matches.compactMap { match in
            guard match.numberOfRanges > 1,
                  let amountRange = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return Double(String(text[amountRange]))
        }

        return values.max()
    }

    private static func parseProvider(text: String) -> String? {
        SGProviderCatalog.allProviderNames.first { provider in
            text.localizedCaseInsensitiveContains(provider)
        }
    }

    private static func firstIntMatch(pattern: String, text: String) -> Int? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(location: 0, length: text.utf16.count)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let valueRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return Int(String(text[valueRange]))
    }
}
