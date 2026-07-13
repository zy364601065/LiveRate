import Foundation

struct LeveragedTargetPriceResult: Equatable {
    let estimatedLeveragedPrice: Double
    let underlyingChangePercent: Double
    let estimatedLeveragedChangePercent: Double
}

enum LeveragedTargetPriceInput: String, CaseIterable, Identifiable {
    case underlyingCurrent
    case leveragedCurrent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .underlyingCurrent:
            return "正股当前价"
        case .leveragedCurrent:
            return "2 倍做多当前价"
        }
    }
}

enum LeveragedTargetPriceCalculator {
    static let leverage = 2.0

    static func calculate(
        underlyingCurrentPrice: Double,
        leveragedCurrentPrice: Double,
        underlyingTargetPrice: Double
    ) -> LeveragedTargetPriceResult? {
        let inputs = [underlyingCurrentPrice, leveragedCurrentPrice, underlyingTargetPrice]
        guard inputs.allSatisfy({ $0.isFinite && $0 > 0 }) else {
            return nil
        }

        let underlyingChangePercent =
            (underlyingTargetPrice - underlyingCurrentPrice) / underlyingCurrentPrice * 100
        let estimatedLeveragedChangePercent = underlyingChangePercent * leverage
        let estimatedLeveragedPrice =
            leveragedCurrentPrice * (1 + estimatedLeveragedChangePercent / 100)

        guard estimatedLeveragedPrice.isFinite, estimatedLeveragedPrice > 0 else {
            return nil
        }

        return LeveragedTargetPriceResult(
            estimatedLeveragedPrice: estimatedLeveragedPrice,
            underlyingChangePercent: underlyingChangePercent,
            estimatedLeveragedChangePercent: estimatedLeveragedChangePercent
        )
    }
}
