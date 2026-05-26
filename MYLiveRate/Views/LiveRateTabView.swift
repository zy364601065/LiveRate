import SwiftUI
import Photos
import PhotosUI
import UIKit

struct LiveRateTabView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @AppStorage(showAllExchangeRatesStorageKey) private var showAllExchangeRates = false
    @State private var isShowingImagePreview = false
    @State private var isShowingPhotoPicker = false
    @State private var isShowingPhotoPermissionAlert = false
    @FocusState private var isAmountFieldFocused: Bool

    private let rateTint = Color(red: 0.98, green: 0.20, blue: 0.30)
    private let rateGridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var otherRateRows: [(code: String, rate: Double)] {
        let coreCodes = Set(Currency.displayOrder.map(\.rawValue))
        return viewModel.sortedAllRateRows.filter { !coreCodes.contains($0.code) }
    }

    private var amountValue: Double {
        let normalized = viewModel.amountText
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "−", with: "-")
        return Double(normalized) ?? 0
    }

    private var usdDisplayAmount: String {
        let absValue = abs(amountValue)
        let formatted = viewModel.formatAmount(absValue, code: "USD")
        let trimmed = formatted.replacingOccurrences(of: " USD", with: "")
        return amountValue >= 0 ? "+\(trimmed)" : "-\(trimmed)"
    }

    private var profitLossColor: Color {
        signedAmountColor(amountValue)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    private var chineseCurrencyLocale: Locale {
        Locale(identifier: "zh_Hans_CN")
    }

    private func currencyDisplayName(for code: String) -> String {
        let chineseName = chineseCurrencyLocale.localizedString(forCurrencyCode: code) ?? code
        return "\(chineseName) \(code)"
    }

    private func icon(for code: String) -> String {
        switch code {
        case "CNY": return "🇨🇳"
        case "HKD": return "🇭🇰"
        case "USD": return "🇺🇸"
        default: return "🌐"
        }
    }

    private func signedAmountColor(_ value: Double?) -> Color {
        guard let value else { return .secondary }
        if value < 0 {
            return Color(red: 0.09, green: 0.71, blue: 0.45)
        }
        if value > 0 {
            return rateTint
        }
        return .secondary
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    headerSection
                    heroSection
                    inputSection
                    pairCardsSection

                    if showAllExchangeRates {
                        allRatesSection
                    }

                    if let updatedAt = viewModel.lastUpdatedAt {
                        Text("最后更新：\(dateFormatter.string(from: updatedAt))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 0)
                .padding(.bottom, 16)
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemGray6), Color(.systemBackground)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .contentShape(Rectangle())
            .onTapGesture {
                isAmountFieldFocused = false
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarVisibility(.hidden, for: .navigationBar)
            .sheet(isPresented: $isShowingImagePreview) {
                NavigationStack {
                    ZStack {
                        Color.black.ignoresSafeArea()
                        if let fullData = viewModel.latestUploadImageData ?? viewModel.latestUploadThumbnailData,
                           let fullImage = UIImage(data: fullData) {
                            Image(uiImage: fullImage)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        } else {
                            Text("没有可预览的图片")
                                .foregroundStyle(.white)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("关闭") { isShowingImagePreview = false }
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
            .alert("需要相册权限", isPresented: $isShowingPhotoPermissionAlert) {
                Button("去设置") {
                    openAppSettings()
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("请在系统设置中允许访问相册，才能选择截图并识别金额。")
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("实时汇率")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                    Text("精准换算 · 汇率更新")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("今日盈亏", systemImage: "info.circle")
                    .font(.footnote.weight(.semibold))
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(.primary)

                Spacer()
            }

            Text(usdDisplayAmount)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(profitLossColor)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(9)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("输入美元金额")
                .font(.footnote.weight(.semibold))

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 1.0, green: 0.93, blue: 0.95))
                        .frame(width: 34, height: 34)
                        .overlay {
                            Text("$")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.98, green: 0.20, blue: 0.30))
                        }

                    TextField("2,126.72", text: $viewModel.amountText)
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .foregroundStyle(profitLossColor)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFieldFocused)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    Button {
                        viewModel.amountText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.gray.opacity(0.7))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Button {
                    openPhotoPickerIfPermitted()
                } label: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray6))
                        .frame(width: 40, height: 40)
                        .overlay {
                            Image(systemName: "camera")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color(red: 0.98, green: 0.20, blue: 0.30))
                        }
                }
                .buttonStyle(.plain)
                .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            }

            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(.secondary)
                Text("支持图片识别金额")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let imageData = viewModel.latestUploadThumbnailData,
               let image = UIImage(data: imageData) {
                Button {
                    isShowingImagePreview = true
                } label: {
                    HStack(spacing: 10) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 44, height: 44)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Text(viewModel.ocrMessage ?? "已识别最新截图")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(9)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func openPhotoPickerIfPermitted() {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited:
            isShowingPhotoPicker = true
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    if status == .authorized || status == .limited {
                        isShowingPhotoPicker = true
                    } else {
                        isShowingPhotoPermissionAlert = true
                    }
                }
            }
        case .denied, .restricted:
            isShowingPhotoPermissionAlert = true
        @unknown default:
            isShowingPhotoPermissionAlert = true
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }
        UIApplication.shared.open(settingsURL)
    }

    private var pairCardsSection: some View {
        HStack(spacing: 10) {
            rateCard(code: "CNY")
            rateCard(code: "HKD")
        }
    }

    private func rateCard(code: String) -> some View {
        let amount = viewModel.convertedAmount(for: code)
        let amountText = viewModel.formatAmount(amount, code: code)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(icon(for: code))  \(currencyDisplayName(for: code))")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(amountText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(signedAmountColor(amount))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(viewModel.rateText(for: code))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var allRatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("其他汇率")
                .font(.subheadline.weight(.semibold))

            if otherRateRows.isEmpty {
                Text("暂无更多汇率数据")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: rateGridColumns, spacing: 10) {
                    ForEach(otherRateRows, id: \.code) { row in
                        rateCard(code: row.code)
                    }
                }
            }
        }
    }
}
