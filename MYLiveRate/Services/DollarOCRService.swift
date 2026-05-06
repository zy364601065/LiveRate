import Foundation
import Vision
import UIKit

final class DollarOCRService {
    func extractDollarAmount(from imageData: Data) async throws -> Double? {
        try await Task.detached(priority: .userInitiated) {
            func normalize(_ text: String) -> String {
                text.replacingOccurrences(of: "−", with: "-")
                    .replacingOccurrences(of: "—", with: "-")
                    .replacingOccurrences(of: "–", with: "-")
            }

            func parseAmount(_ raw: String) -> Double? {
                let normalized = raw
                    .replacingOccurrences(of: " ", with: "")
                    .replacingOccurrences(of: ",", with: "")
                    .replacingOccurrences(of: "，", with: "")
                return Double(normalized)
            }

            func firstMatchAmount(in lines: [String], patterns: [String]) -> Double? {
                for line in lines {
                    for pattern in patterns {
                        guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                        let fullRange = NSRange(line.startIndex..<line.endIndex, in: line)
                        guard let match = regex.firstMatch(in: line, range: fullRange),
                              match.numberOfRanges > 1,
                              let range = Range(match.range(at: 1), in: line) else { continue }

                        if let value = parseAmount(String(line[range])) {
                            return value
                        }
                    }
                }
                return nil
            }

            func extractAmount(from lines: [String]) -> Double? {
                let normalizedLines = lines.map { normalize($0) }

                let usdPatterns = [
                    #"\$\s*([+\-−]?\s*[0-9]{1,3}(?:[,，][0-9]{3})*(?:\.[0-9]{1,2})?|[+\-−]?\s*[0-9]+(?:\.[0-9]{1,2})?)"#,
                    #"(?i)\bUSD\b\s*([+\-−]?\s*[0-9]{1,3}(?:[,，][0-9]{3})*(?:\.[0-9]{1,2})?|[+\-−]?\s*[0-9]+(?:\.[0-9]{1,2})?)"#,
                    #"(?i)\bUS\$\s*([+\-−]?\s*[0-9]{1,3}(?:[,，][0-9]{3})*(?:\.[0-9]{1,2})?|[+\-−]?\s*[0-9]+(?:\.[0-9]{1,2})?)"#
                ]

                if let amount = firstMatchAmount(in: normalizedLines, patterns: usdPatterns) {
                    return amount
                }

                let contextKeywords = ["今日盈亏", "盈亏", "收益", "profit", "p/l", "p&l"]
                let signedPatterns = [
                    #"([+\-−]\s*[0-9]{1,3}(?:[,，][0-9]{3})*(?:\.[0-9]{1,2})?)"#,
                    #"([+\-−]\s*[0-9]+(?:\.[0-9]{1,2})?)"#
                ]

                for (index, line) in normalizedLines.enumerated() {
                    let lower = line.lowercased()
                    guard contextKeywords.contains(where: { lower.contains($0.lowercased()) }) else { continue }

                    let end = min(index + 2, normalizedLines.count - 1)
                    let window = Array(normalizedLines[index...end])
                    if let amount = firstMatchAmount(in: window, patterns: signedPatterns) {
                        return amount
                    }
                }

                if let amount = firstMatchAmount(in: normalizedLines, patterns: signedPatterns) {
                    return amount
                }

                return nil
            }

            guard let image = UIImage(data: imageData),
                  let cgImage = image.cgImage else {
                return nil
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "zh-Hans"]

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try handler.perform([request])

            let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
            return extractAmount(from: lines)
        }.value
    }
}
