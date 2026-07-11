import Foundation
import Vision
import UIKit

final class HoldingsOCRService {
    private struct RecognizedLine {
        let text: String
        let box: CGRect
    }

    private struct ParsedHoldingPayload {
        let stockName: String
        let stockCode: String?
        let marketValue: Double?
        let quantity: Double?
        let currentPrice: Double?
        let costPrice: Double?
        let todayPnL: Double?
        let todayPnLPercent: Double?
        let holdingPnL: Double?
        let holdingPnLPercent: Double?
    }

    func extractHoldings(from imageData: Data) async throws -> [HoldingRecord] {
        let payloads = try await Task.detached(priority: .userInitiated) { () -> [ParsedHoldingPayload] in
            guard let image = UIImage(data: imageData),
                  let cgImage = image.cgImage else {
                return []
            }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "en-US"]

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try handler.perform([request])

            let recognizedLines = (request.results ?? [])
                .compactMap { observation -> RecognizedLine? in
                    guard let candidate = observation.topCandidates(1).first else { return nil }
                    let text = Self.normalize(candidate.string)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return nil }
                    return RecognizedLine(text: text, box: observation.boundingBox)
                }
                .sorted {
                    let verticalDifference = abs($0.box.midY - $1.box.midY)
                    if verticalDifference < 0.018 { return $0.box.minX < $1.box.minX }
                    return $0.box.midY > $1.box.midY
                }

            let lines = recognizedLines.map(\.text)

            guard !lines.isEmpty else { return [] }

            let spatialPayloads = Self.extractSpatialCardHoldings(from: recognizedLines)
            if !spatialPayloads.isEmpty {
                return spatialPayloads
            }

            let blockPayloads = Self.extractBlockHoldings(from: lines)
            if !blockPayloads.isEmpty {
                return blockPayloads
            }

            let rowPayloads = Self.extractRowHoldings(from: lines)
            if !rowPayloads.isEmpty {
                return rowPayloads
            }

            if let single = Self.extractSingleHolding(from: lines) {
                return [single]
            }

            return []
        }.value

        let now = Date()
        return payloads.enumerated().map { index, payload in
            HoldingRecord(
                // The list is sorted newest-first. Give records from the same image
                // stable descending timestamps so their visual top-to-bottom order
                // survives dictionary merging and persistence.
                timestamp: now.addingTimeInterval(-Double(index) * 0.001),
                stockName: payload.stockName,
                stockCode: payload.stockCode,
                marketValue: payload.marketValue,
                quantity: payload.quantity,
                currentPrice: payload.currentPrice,
                costPrice: payload.costPrice,
                todayPnL: payload.todayPnL,
                todayPnLPercent: payload.todayPnLPercent,
                holdingPnL: payload.holdingPnL,
                holdingPnLPercent: payload.holdingPnLPercent
            )
        }
    }

    nonisolated private static func extractSpatialCardHoldings(
        from lines: [RecognizedLine]
    ) -> [ParsedHoldingPayload] {
        let anchors = lines
            .filter { $0.text.contains("市值") && $0.text.contains("数量") }
            .sorted { $0.box.midY > $1.box.midY }

        guard !anchors.isEmpty else { return [] }
        if anchors.count == 1 {
            return extractSpatialCardHolding(from: lines).map { [$0] } ?? []
        }

        return anchors.enumerated().compactMap { index, anchor in
            let typicalGap: CGFloat = 0.24
            let upperY: CGFloat
            let lowerY: CGFloat

            if index == 0 {
                let nextGap = anchor.box.midY - anchors[index + 1].box.midY
                upperY = min(1, anchor.box.midY + max(nextGap / 2, typicalGap / 2))
            } else {
                let previousGap = anchors[index - 1].box.midY - anchor.box.midY
                upperY = anchor.box.midY + previousGap * 0.35
            }

            if index == anchors.count - 1 {
                let previousGap = anchors[index - 1].box.midY - anchor.box.midY
                lowerY = max(0, anchor.box.midY - max(previousGap / 2, typicalGap / 2))
            } else {
                let nextGap = anchor.box.midY - anchors[index + 1].box.midY
                lowerY = anchors[index + 1].box.midY + nextGap * 0.35
            }

            let cardLines = lines.filter {
                $0.box.midY <= upperY && $0.box.midY > lowerY
            }
            return extractSpatialCardHolding(from: cardLines)
        }
    }

    nonisolated private static func extractSpatialCardHolding(
        from lines: [RecognizedLine]
    ) -> ParsedHoldingPayload? {
        guard ["市值", "数量", "现价", "成本", "今日盈亏", "持仓盈亏"].allSatisfy({ keyword in
            lines.contains(where: { $0.text.contains(keyword) })
        }) else { return nil }

        func valueText(for keywords: [String]) -> String? {
            guard let label = lines.first(where: { line in
                keywords.allSatisfy { line.text.contains($0) }
            }) else { return nil }

            if !extractNumbersExcludingPercent(from: label.text).isEmpty || !extractPercentages(from: label.text).isEmpty {
                return label.text
            }

            let candidates = lines.filter { candidate in
                candidate.box.midY < label.box.midY &&
                label.box.midY - candidate.box.midY < 0.18 &&
                abs(candidate.box.midX - label.box.midX) < 0.22
            }
            .sorted {
                let firstDistance = label.box.midY - $0.box.midY
                let secondDistance = label.box.midY - $1.box.midY
                if abs(firstDistance - secondDistance) < 0.018 { return $0.box.minX < $1.box.minX }
                return firstDistance < secondDistance
            }

            guard let first = candidates.first else { return nil }
            var result = first.text

            // Vision occasionally returns a minus sign as a separate box immediately to the left.
            if !result.hasPrefix("-") {
                let sign = lines.first { candidate in
                    candidate.text == "-" &&
                    abs(candidate.box.midY - first.box.midY) < 0.025 &&
                    candidate.box.maxX <= first.box.minX + 0.02
                }
                if sign != nil { result = "-" + result }
            }
            return result
        }

        guard let marketText = valueText(for: ["市值", "数量"]),
              let priceText = valueText(for: ["现价", "成本"]),
              let todayText = valueText(for: ["今日盈亏"]),
              let holdingText = valueText(for: ["持仓盈亏"]) else { return nil }

        let marketValues = extractNumbersExcludingPercent(from: marketText)
        let priceValues = extractNumbersExcludingPercent(from: priceText)
        let todayValues = extractNumbersExcludingPercent(from: todayText)
        let holdingValues = extractNumbersExcludingPercent(from: holdingText)
        guard marketValues.count >= 2, priceValues.count >= 2 else { return nil }

        let firstMetricY = lines
            .filter { $0.text.contains("市值") || $0.text.contains("今日盈亏") }
            .map(\.box.midY)
            .max() ?? 0
        let identityLines = lines.filter {
            $0.box.midY > firstMetricY && !isHeaderLike($0.text.replacingOccurrences(of: " ", with: ""))
        }
        let nameLine = identityLines
            .filter { $0.text.range(of: #"[\u4e00-\u9fa5]"#, options: .regularExpression) != nil }
            .max(by: { $0.text.count < $1.text.count })
            ?? identityLines.first(where: { extractTicker(from: $0.text) == nil })
        let name = nameLine?.text ?? "未识别股票"

        let codeCandidates = identityLines.filter {
            $0.text.range(of: #"^[A-Z]{2,6}(?:\.[A-Z])?$"#, options: .regularExpression) != nil
        }
        // A logo/avatar letter is commonly recognized as a ticker. Prefer text directly
        // below and horizontally aligned with the security name instead.
        let alignedCode = nameLine.flatMap { nameLine in
            codeCandidates
                .filter {
                    $0.box.midY < nameLine.box.midY &&
                    nameLine.box.midY - $0.box.midY < 0.16 &&
                    abs($0.box.minX - nameLine.box.minX) < 0.12
                }
                .min(by: { nameLine.box.midY - $0.box.midY < nameLine.box.midY - $1.box.midY })
        }
        let code = alignedCode?.text
            ?? codeCandidates.first(where: { $0.text.count >= 2 })?.text

        return ParsedHoldingPayload(
            stockName: name,
            stockCode: code,
            marketValue: marketValues[0],
            quantity: marketValues[1],
            currentPrice: priceValues[0],
            costPrice: priceValues[1],
            todayPnL: todayValues.first,
            todayPnLPercent: extractPercentages(from: todayText).first,
            holdingPnL: holdingValues.first,
            holdingPnLPercent: extractPercentages(from: holdingText).first
        )
    }

    nonisolated private static func extractBlockHoldings(from lines: [String]) -> [ParsedHoldingPayload] {
        guard lines.count > 1 else { return [] }

        var markerIndices: [Int] = []
        for index in lines.indices where isPotentialStockMarker(lines[index]) {
            markerIndices.append(index)
        }

        guard !markerIndices.isEmpty else { return [] }

        var payloads: [ParsedHoldingPayload] = []

        for (position, startIndex) in markerIndices.enumerated() {
            let endIndex = position + 1 < markerIndices.count ? markerIndices[position + 1] : lines.count
            guard startIndex < endIndex else { continue }

            let block = Array(lines[startIndex..<endIndex])
            let joined = block.joined(separator: " ")

            let numbers = extractNumbersExcludingPercent(from: joined)
            let percents = extractPercentages(from: joined)

            guard numbers.count >= 4 else { continue }
            if numbers.count < 6 && percents.isEmpty { continue }

            let identity = extractStockIdentityFromBlock(block)
            let stockName = identity.name ?? "未识别股票"

            payloads.append(
                ParsedHoldingPayload(
                    stockName: stockName,
                    stockCode: identity.code,
                    marketValue: numbers.count > 0 ? numbers[0] : nil,
                    quantity: numbers.count > 1 ? numbers[1] : nil,
                    currentPrice: numbers.count > 2 ? numbers[2] : nil,
                    costPrice: numbers.count > 3 ? numbers[3] : nil,
                    todayPnL: numbers.count > 4 ? numbers[4] : nil,
                    todayPnLPercent: percents.count > 0 ? percents[0] : nil,
                    holdingPnL: numbers.count > 5 ? numbers[5] : nil,
                    holdingPnLPercent: percents.count > 1 ? percents[1] : nil
                )
            )
        }

        return payloads
    }

    nonisolated private static func extractRowHoldings(from lines: [String]) -> [ParsedHoldingPayload] {
        func value(at index: Int, from numbers: [Double]) -> Double? {
            guard numbers.indices.contains(index) else { return nil }
            return numbers[index]
        }

        var payloads: [ParsedHoldingPayload] = []

        for line in lines {
            let compact = line.replacingOccurrences(of: " ", with: "")
            if compact.isEmpty { continue }

            let headerKeywords = ["名称", "市值", "数量", "现价", "成本", "今日盈亏", "持仓盈亏"]
            if headerKeywords.allSatisfy({ compact.contains($0) }) { continue }

            let percents = extractPercentages(from: line)
            let numbers = extractNumbersExcludingPercent(from: line)
            let name = extractStockNameFromRow(line)
            let code = extractTicker(from: line)

            guard let stockName = name, numbers.count >= 4 else { continue }
            guard numbers.count >= 6 || percents.count >= 1 else { continue }

            let payload = ParsedHoldingPayload(
                stockName: stockName,
                stockCode: code,
                marketValue: value(at: 0, from: numbers),
                quantity: value(at: 1, from: numbers),
                currentPrice: value(at: 2, from: numbers),
                costPrice: value(at: 3, from: numbers),
                todayPnL: value(at: 4, from: numbers),
                todayPnLPercent: value(at: 0, from: percents),
                holdingPnL: value(at: 5, from: numbers),
                holdingPnLPercent: value(at: 1, from: percents)
            )
            payloads.append(payload)
        }

        return payloads
    }

    nonisolated private static func extractStockIdentityFromBlock(_ block: [String]) -> (name: String?, code: String?) {
        var chineseOrName: String?
        var ticker: String?

        for line in block {
            let compact = line.replacingOccurrences(of: " ", with: "")
            if isHeaderLike(compact) { continue }

            if ticker == nil, let t = extractTicker(from: line) {
                ticker = t
            }

            if chineseOrName == nil {
                let candidate = extractStockNameFromRow(line)
                if let candidate, !candidate.isEmpty {
                    chineseOrName = candidate
                }
            }
        }

        return (name: chineseOrName ?? ticker, code: ticker)
    }

    nonisolated private static func extractSingleHolding(from lines: [String]) -> ParsedHoldingPayload? {
        let stockName = extractStockName(from: lines) ?? "未识别股票"
        let stockCode = lines.compactMap { extractTicker(from: $0) }.first
        let marketValueQuantity = extractPair(from: lines, keywords: ["市值", "数量"])
        let currentCost = extractPair(from: lines, keywords: ["现价", "成本"])
        let today = extractSingleValueAndPercent(from: lines, keywords: ["今日盈亏"])
        let holding = extractSingleValueAndPercent(from: lines, keywords: ["持仓盈亏", "累计盈亏"])

        if marketValueQuantity == nil,
           currentCost == nil,
           today == nil,
           holding == nil,
           stockName == "未识别股票" {
            return nil
        }

        return ParsedHoldingPayload(
            stockName: stockName,
            stockCode: stockCode,
            marketValue: marketValueQuantity?.0,
            quantity: marketValueQuantity?.1,
            currentPrice: currentCost?.0,
            costPrice: currentCost?.1,
            todayPnL: today?.0,
            todayPnLPercent: today?.1,
            holdingPnL: holding?.0,
            holdingPnLPercent: holding?.1
        )
    }

    nonisolated private static func extractStockName(from lines: [String]) -> String? {
        for line in lines {
            if line.contains("股票名称") || line.contains("名称") {
                if let after = valueAfterLabel(line: line, label: "股票名称") ?? valueAfterLabel(line: line, label: "名称") {
                    let cleaned = after.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty { return cleaned }
                }
            }
        }

        let ignoredKeywords = ["市值", "数量", "现价", "成本", "盈亏", "持仓", "今日", "收益"]
        for line in lines {
            let compact = line.replacingOccurrences(of: " ", with: "")
            if compact.count < 2 || compact.count > 80 { continue }
            if ignoredKeywords.contains(where: { compact.contains($0) }) { continue }
            if compact.range(of: #"[\u4e00-\u9fa5A-Za-z]{2,}"#, options: .regularExpression) != nil {
                return compact
            }
        }
        return nil
    }

    nonisolated private static func extractPair(from lines: [String], keywords: [String]) -> (Double, Double)? {
        for (index, line) in lines.enumerated() {
            guard keywords.allSatisfy({ line.contains($0) }) else { continue }
            let combined = line + " " + (index + 1 < lines.count ? lines[index + 1] : "")
            let numbers = extractNumbersExcludingPercent(from: combined)
            if numbers.count >= 2 {
                return (numbers[0], numbers[1])
            }
        }
        return nil
    }

    nonisolated private static func extractSingleValueAndPercent(from lines: [String], keywords: [String]) -> (Double?, Double?)? {
        for (index, line) in lines.enumerated() {
            guard keywords.contains(where: { line.contains($0) }) else { continue }

            let numbers = extractNumbersExcludingPercent(from: line)
            let percents = extractPercentages(from: line)
            let nextLine = index + 1 < lines.count ? lines[index + 1] : ""

            let value = numbers.first ?? extractNumbersExcludingPercent(from: nextLine).first
            let percent = percents.first ?? extractPercentages(from: nextLine).first
            return (value, percent)
        }
        return nil
    }

    nonisolated private static func extractNumbersExcludingPercent(from text: String) -> [Double] {
        let withoutPercent = text.replacingOccurrences(
            of: #"[+\-−]?\s*[0-9]+(?:\.[0-9]+)?\s*%"#,
            with: " ",
            options: .regularExpression
        )
        let pattern = #"[+\-−]?\s*[0-9]{1,3}(?:[,，][0-9]{3})*(?:\.[0-9]+)?|[+\-−]?\s*[0-9]+(?:\.[0-9]+)?"#
        return extractDoubles(by: pattern, from: withoutPercent)
    }

    nonisolated private static func extractPercentages(from text: String) -> [Double] {
        let pattern = #"([+\-−]?\s*[0-9]+(?:\.[0-9]+)?)\s*%"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        return regex.matches(in: text, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let r = Range(match.range(at: 1), in: text) else { return nil }
            let raw = String(text[r])
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: "−", with: "-")
            return Double(raw)
        }
    }

    nonisolated private static func extractDoubles(by pattern: String, from text: String) -> [Double] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        return regex.matches(in: text, range: range).compactMap { match in
            guard let r = Range(match.range, in: text) else { return nil }
            let raw = String(text[r])
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "，", with: "")
                .replacingOccurrences(of: "−", with: "-")
            return Double(raw)
        }
    }

    nonisolated private static func extractStockNameFromRow(_ line: String) -> String? {
        let cleanLine = line
            .replacingOccurrences(of: #"[+\-−]?\s*[0-9]+(?:\.[0-9]+)?\s*%"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"[+\-−]?\s*[0-9]{1,3}(?:[,，][0-9]{3})*(?:\.[0-9]+)?|[+\-−]?\s*[0-9]+(?:\.[0-9]+)?"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: "|", with: " ")

        let tokens = cleanLine
            .components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }

        let ignored = ["市值", "数量", "现价", "成本", "今日盈亏", "持仓盈亏", "累计盈亏", "盈亏"]
        for token in tokens {
            if ignored.contains(where: { token.contains($0) }) { continue }
            if token.range(of: #"[\u4e00-\u9fa5A-Za-z]{2,}"#, options: .regularExpression) != nil {
                return token
            }
        }

        return nil
    }

    nonisolated private static func isPotentialStockMarker(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: " ", with: "")
        if compact.isEmpty || isHeaderLike(compact) { return false }

        let numberCount = extractNumbersExcludingPercent(from: line).count
        if numberCount >= 3 { return false }

        if extractTicker(from: line) != nil {
            return true
        }

        if compact.range(of: #"[\u4e00-\u9fa5A-Za-z]{2,}"#, options: .regularExpression) != nil {
            return true
        }

        return false
    }

    nonisolated private static func extractTicker(from line: String) -> String? {
        // Holdings screenshots often contain a one-letter logo/avatar. Requiring at
        // least two letters prevents that decorative glyph from becoming the ticker.
        let pattern = #"\b[A-Z]{2,6}(?:\.[A-Z])?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, range: range),
              let r = Range(match.range, in: line) else {
            return nil
        }

        let candidate = String(line[r])
        let blacklist = ["USD", "HKD", "CNY", "PNL"]
        if blacklist.contains(candidate) {
            return nil
        }
        return candidate
    }

    nonisolated private static func isHeaderLike(_ compact: String) -> Bool {
        let headerKeywords = ["名称", "股票", "市值", "数量", "现价", "成本", "今日盈亏", "持仓盈亏", "累计盈亏", "代码"]
        return headerKeywords.contains(where: { compact.contains($0) })
    }

    nonisolated private static func valueAfterLabel(line: String, label: String) -> String? {
        guard let range = line.range(of: label) else { return nil }
        let suffix = line[range.upperBound...]
        return String(suffix)
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "：", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .replacingOccurrences(of: "–", with: "-")
    }
}
