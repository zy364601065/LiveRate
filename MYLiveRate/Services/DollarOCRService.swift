import Foundation
import Vision
import UIKit

final class DollarOCRService {
    func extractDollarAmount(from imageData: Data) async throws -> Double? {
        try await Task.detached(priority: .userInitiated) {
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

            let lines = (request.results ?? [])
                .compactMap { $0.topCandidates(1).first?.string }
                .map(Self.normalize)

            guard !lines.isEmpty else { return nil }

            // 优先匹配带 USD/$ 的金额
            let labeledPattern = #"(?i)(?:USD|US\$|\$)\s*([+\-−]?\s*[0-9]{1,3}(?:[,，][0-9]{3})*(?:\.[0-9]+)?|[+\-−]?\s*[0-9]+(?:\.[0-9]+)?)"#
            if let regex = try? NSRegularExpression(pattern: labeledPattern) {
                for line in lines {
                    let range = NSRange(line.startIndex..<line.endIndex, in: line)
                    if let match = regex.firstMatch(in: line, range: range),
                       match.numberOfRanges > 1,
                       let valueRange = Range(match.range(at: 1), in: line),
                       let value = Self.parseAmount(String(line[valueRange])) {
                        return value
                    }
                }
            }

            // 兜底：识别普通数字，返回绝对值最大的一个（通常是截图中的主金额）
            let numberPattern = #"[+\-−]?\s*[0-9]{1,3}(?:[,，][0-9]{3})*(?:\.[0-9]+)?|[+\-−]?\s*[0-9]+(?:\.[0-9]+)?"#
            guard let numberRegex = try? NSRegularExpression(pattern: numberPattern) else {
                return nil
            }

            var candidates: [Double] = []
            for line in lines {
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                numberRegex.matches(in: line, range: range).forEach { match in
                    guard let r = Range(match.range, in: line),
                          let value = Self.parseAmount(String(line[r])) else {
                        return
                    }
                    candidates.append(value)
                }
            }

            return candidates.max(by: { abs($0) < abs($1) })
        }.value
    }

    nonisolated private static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
    }

    nonisolated private static func parseAmount(_ raw: String) -> Double? {
        let normalized = raw
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "−", with: "-")
        return Double(normalized)
    }
}
