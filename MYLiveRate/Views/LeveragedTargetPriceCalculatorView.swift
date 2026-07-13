import SwiftUI
import UIKit

struct LeveragedTargetPriceCalculatorView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel

    @State private var underlyingCurrentPriceText = ""
    @State private var leveragedCurrentPriceText = ""
    @State private var underlyingTargetPriceText = ""
    @State private var underlyingHoldingName: String?
    @State private var leveragedHoldingName: String?
    @State private var holdingInputTarget: LeveragedTargetPriceInput?
    @FocusState private var isInputFocused: Bool

    private let profitColor = Color(red: 0.93, green: 0.19, blue: 0.23)
    private let lossColor = Color(red: 0.12, green: 0.72, blue: 0.67)
    private let accentColor = Color(red: 0.95, green: 0.52, blue: 0.16)
    private let cardStroke = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.13)
            : UIColor(white: 0.78, alpha: 0.52)
    })

    private var availableHoldings: [HoldingRecord] {
        viewModel.holdingRecords.filter { ($0.currentPrice ?? 0) > 0 }
    }

    private var parsedInputs: (underlyingCurrent: Double, leveragedCurrent: Double, target: Double)? {
        guard let underlyingCurrent = parsePrice(underlyingCurrentPriceText),
              let leveragedCurrent = parsePrice(leveragedCurrentPriceText),
              let target = parsePrice(underlyingTargetPriceText) else {
            return nil
        }
        return (underlyingCurrent, leveragedCurrent, target)
    }

    private var calculation: LeveragedTargetPriceResult? {
        guard let inputs = parsedInputs else { return nil }
        return LeveragedTargetPriceCalculator.calculate(
            underlyingCurrentPrice: inputs.underlyingCurrent,
            leveragedCurrentPrice: inputs.leveragedCurrent,
            underlyingTargetPrice: inputs.target
        )
    }

    private var hasInvalidInput: Bool {
        let values = [
            underlyingCurrentPriceText,
            leveragedCurrentPriceText,
            underlyingTargetPriceText
        ]
        return values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            && parsedInputs == nil
    }

    private var isOutsideModelRange: Bool {
        guard let inputs = parsedInputs else { return false }
        let underlyingChange = (inputs.target - inputs.underlyingCurrent) / inputs.underlyingCurrent
        let estimatedPrice = inputs.leveragedCurrent * (1 + 2 * underlyingChange)
        return estimatedPrice <= 0
    }

    var body: some View {
        ScrollView {
            calculatorCard
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(pageBackground.ignoresSafeArea())
        .navigationTitle("目标价换算")
        .navigationBarTitleDisplayMode(.inline)
        .background {
            Button {
                isInputFocused = false
            } label: {
                Color.clear
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
        .sheet(item: $holdingInputTarget) { target in
            holdingPicker(for: target)
        }
    }

    private var calculatorCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            inputSection

            if let calculation {
                resultSection(calculation)
            } else if isOutsideModelRange {
                modelRangeWarning
            } else if hasInvalidInput {
                Text("请输入有效的正数价格")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("仅用于当天估算，不含每日复位、费用和跟踪误差。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(
            Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 0.46)
                    : UIColor(white: 1, alpha: 0.76)
            }),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.055), radius: 14, y: 6)
    }

    private var pageBackground: some View {
        LinearGradient(
            colors: [
                Color(uiColor: UIColor { trait in
                    trait.userInterfaceStyle == .dark
                        ? UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)
                        : UIColor(red: 0.995, green: 0.995, blue: 0.992, alpha: 1)
                }),
                Color(uiColor: UIColor { trait in
                    trait.userInterfaceStyle == .dark
                        ? UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
                        : UIColor(red: 0.989, green: 0.989, blue: 0.982, alpha: 1)
                })
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("目标价换算")
                    .font(.headline.weight(.semibold))

                Text("2 倍做多 · 当天估算 · 两个现价可从持仓带入")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)
        }
    }

    private var inputSection: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10, alignment: .top),
                GridItem(.flexible(), spacing: 10, alignment: .top)
            ],
            spacing: 10
        ) {
            priceInput(
                title: "正股当前价",
                placeholder: "160.00",
                text: $underlyingCurrentPriceText,
                importedFrom: underlyingHoldingName,
                onImport: { holdingInputTarget = .underlyingCurrent }
            )

            priceInput(
                title: "2 倍做多当前价",
                placeholder: "20.00",
                text: $leveragedCurrentPriceText,
                importedFrom: leveragedHoldingName,
                onImport: { holdingInputTarget = .leveragedCurrent }
            )

            priceInput(
                title: "正股目标价",
                placeholder: "180.00",
                text: $underlyingTargetPriceText
            )
            .gridCellColumns(2)
        }
    }

    private func priceInput(
        title: String,
        placeholder: String,
        text: Binding<String>,
        importedFrom: String? = nil,
        onImport: (() -> Void)? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer(minLength: 4)

                if let onImport {
                    Button("带入", action: onImport)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accentColor)
                        .buttonStyle(.plain)
                        .disabled(availableHoldings.isEmpty)
                        .accessibilityLabel("从持仓带入\(title)")
                        .accessibilityHint(availableHoldings.isEmpty ? "当前没有可用的持仓现价" : "选择一条持仓并填入此价格")
                }
            }

            TextField(placeholder, text: text)
                .font(.body.weight(.semibold).monospacedDigit())
                .keyboardType(.decimalPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .accessibilityLabel(title)
                .accessibilityValue(text.wrappedValue.isEmpty ? "未输入" : text.wrappedValue)

            if let importedFrom {
                Text("来自：\(importedFrom)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color(uiColor: UIColor { trait in
                trait.userInterfaceStyle == .dark
                    ? UIColor(white: 1, alpha: 0.07)
                    : UIColor(white: 0.96, alpha: 0.78)
            }),
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(cardStroke.opacity(0.8), lineWidth: 1)
        }
    }

    private func resultSection(_ result: LeveragedTargetPriceResult) -> some View {
        let resultColor = signedColor(result.estimatedLeveragedChangePercent)

        return VStack(alignment: .leading, spacing: 8) {
            Text("预计 2 倍做多价")
                .font(.caption.weight(.medium))
                .foregroundStyle(resultColor.opacity(0.82))

            Text(formattedPrice(result.estimatedLeveragedPrice))
                .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(resultColor)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .accessibilityLabel("预计 2 倍做多价格")
                .accessibilityValue(formattedPrice(result.estimatedLeveragedPrice))

            HStack(spacing: 14) {
                changePill(title: "正股", value: result.underlyingChangePercent)
                changePill(title: "产品估算", value: result.estimatedLeveragedChangePercent)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            resultColor.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(resultColor.opacity(0.20), lineWidth: 1)
        }
    }

    private func changePill(title: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(.secondary)
            Text(formattedPercent(value))
                .foregroundStyle(signedColor(value))
        }
        .font(.caption.weight(.semibold).monospacedDigit())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title)涨跌幅")
        .accessibilityValue(formattedPercent(value))
    }

    private var modelRangeWarning: some View {
        Label("目标跌幅超出当前简化模型范围", systemImage: "exclamationmark.triangle")
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .combine)
    }

    private func holdingPicker(for target: LeveragedTargetPriceInput) -> some View {
        NavigationStack {
            List(availableHoldings) { record in
                Button {
                    applyHolding(record, to: target)
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(primaryName(record))
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)

                            if let code = record.stockCode, !code.isEmpty {
                                Text(code)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()

                        Text(formattedPrice(record.currentPrice ?? 0))
                            .font(.body.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("选择\(primaryName(record))")
                .accessibilityValue("现价 \(formattedPrice(record.currentPrice ?? 0))")
            }
            .navigationTitle("带入\(target.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        holdingInputTarget = nil
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func applyHolding(_ record: HoldingRecord, to target: LeveragedTargetPriceInput) {
        guard let currentPrice = record.currentPrice else { return }
        switch target {
        case .underlyingCurrent:
            underlyingCurrentPriceText = formattedPrice(currentPrice)
            underlyingHoldingName = primaryName(record)
        case .leveragedCurrent:
            leveragedCurrentPriceText = formattedPrice(currentPrice)
            leveragedHoldingName = primaryName(record)
        }
        holdingInputTarget = nil
    }

    private func parsePrice(_ text: String) -> Double? {
        let normalized = text
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "−", with: "-")
        guard let value = Double(normalized), value.isFinite, value > 0 else { return nil }
        return value
    }

    private func formattedPrice(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func formattedPercent(_ value: Double) -> String {
        String(format: "%+.2f%%", value)
    }

    private func signedColor(_ value: Double) -> Color {
        if value > 0 { return profitColor }
        if value < 0 { return lossColor }
        return .secondary
    }

    private func primaryName(_ record: HoldingRecord) -> String {
        if record.stockName.contains("\n") {
            return record.stockName.components(separatedBy: "\n").first ?? record.stockName
        }
        return record.stockName
    }
}
