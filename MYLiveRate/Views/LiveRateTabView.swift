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

    private let profitColor = Color(red: 0.93, green: 0.19, blue: 0.23)
    private let lossColor = Color(red: 0.12, green: 0.72, blue: 0.67)
    private let navy = Color(uiColor: .label)
    private let accentBlue = Color(red: 0.95, green: 0.52, blue: 0.16)
    private let pageBg = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.04, green: 0.04, blue: 0.05, alpha: 1)
            : UIColor(red: 0.995, green: 0.995, blue: 0.992, alpha: 1)
    })
    private let pageBgMid = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.06, blue: 0.07, alpha: 1)
            : UIColor(red: 0.993, green: 0.993, blue: 0.988, alpha: 1)
    })
    private let pageBgBottom = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1)
            : UIColor(red: 0.989, green: 0.989, blue: 0.982, alpha: 1)
    })
    private let glassStrokeColor = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.12)
            : UIColor(white: 1, alpha: 0.55)
    })
    private let glassFillColor = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 0.50)
            : UIColor(white: 1, alpha: 0.20)
    })
    private let coreRateCodes = ["CNY", "HKD"]
    private let rateGridColumns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    private var highlightRateCodes: [String] {
        var codes = coreRateCodes
        if !codes.contains("EUR") { codes.append("EUR") }
        if !codes.contains("JPY") { codes.append("JPY") }
        return codes
    }

    private var otherRateRows: [(code: String, rate: Double)] {
        let highlighted = Set(highlightRateCodes)
        return viewModel.sortedAllRateRows.filter { !highlighted.contains($0.code) }
    }

    private var amountValue: Double {
        let normalized = viewModel.amountText
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: "−", with: "-")
        return Double(normalized) ?? 0
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

    private func iconName(for code: String) -> String {
        switch code {
        case "CNY": return "yensign.circle.fill"
        case "HKD": return "dollarsign.circle.fill"
        case "USD": return "dollarsign.square.fill"
        case "EUR": return "eurosign.circle.fill"
        case "JPY": return "yensign.square.fill"
        default: return "globe.americas.fill"
        }
    }

    private func signedAmountColor(_ value: Double?) -> Color {
        guard let value else { return .secondary }
        if value < 0 { return lossColor }
        if value > 0 { return profitColor }
        return .secondary
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    headerSection
                    inputSection
                    coreRatesSection

                    if showAllExchangeRates {
                        allRatesSection
                    }

                    statusSection
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)
                .padding(.bottom, 18)
            }
            .background(pageBackground.ignoresSafeArea())
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
            .onAppear {
                enforceUSDBaseIfNeeded()
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("汇率")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(navy)
                    Text("美元基准 · 实时更新")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(accentBlue)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text(viewModel.isLoading ? "刷新中" : "刷新")
                            .font(.footnote.weight(.semibold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(.thinMaterial, in: Capsule())
                    .overlay {
                        Capsule().stroke(glassStrokeColor, lineWidth: 1)
                    }
                    .foregroundStyle(accentBlue)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
            }

            HStack(spacing: 8) {
                statusTag(icon: "clock.badge.checkmark", text: viewModel.lastUpdatedAt.map { "更新 \(dateFormatter.string(from: $0))" } ?? "等待同步")
                statusTag(icon: "photo.badge.plus", text: "记录 \(viewModel.uploadRecords.count) 条")
            }
        }
        .padding(12)
        .background(glassCard(cornerRadius: 18, tint: glassFillColor))
    }

    private func statusTag(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2.weight(.medium))
        .foregroundStyle(Color(uiColor: .secondaryLabel))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("输入美元金额")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(navy)

            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(uiColor: .tertiarySystemFill))
                        .frame(width: 34, height: 34)
                        .overlay {
                            Text("$")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundStyle(profitColor)
                        }

                    TextField("2,126.72", text: $viewModel.amountText)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(profitLossColor)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFieldFocused)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)

                    if !viewModel.amountText.isEmpty {
                        Button {
                            viewModel.amountText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(navy.opacity(0.42))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(glassStrokeColor, lineWidth: 1)
                }

                Button {
                    openPhotoPickerIfPermitted()
                } label: {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(glassFillColor)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .frame(width: 40, height: 40)
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(glassStrokeColor, lineWidth: 1)
                        }
                        .overlay {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(accentBlue)
                        }
                }
                .buttonStyle(.plain)
                .photosPicker(isPresented: $isShowingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            }

            HStack(spacing: 6) {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(.secondary)
                Text("支持图片识别美元金额")
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
                        Image(systemName: "chevron.right")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(glassCard(cornerRadius: 16, tint: glassFillColor))
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

    private func enforceUSDBaseIfNeeded() {
        guard viewModel.baseCurrency != .USD else { return }
        viewModel.updateBaseCurrency(.USD)
        Task {
            await viewModel.refresh()
        }
    }

    private var coreRatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("核心汇率")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(navy)

            LazyVGrid(columns: rateGridColumns, spacing: 10) {
                ForEach(highlightRateCodes, id: \.self) { code in
                    rateCard(code: code, emphasized: coreRateCodes.contains(code))
                }
            }
        }
    }

    private func rateCard(code: String, emphasized: Bool) -> some View {
        let amount = viewModel.convertedAmount(for: code)
        let amountText = viewModel.formatAmount(amount, code: code)

        return VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: iconName(for: code))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(emphasized ? accentBlue : navy.opacity(0.75))
                Text(currencyDisplayName(for: code))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .foregroundStyle(navy)
            }

            Text(amountText)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(signedAmountColor(amount))

            Text(viewModel.rateText(for: code))
                .font(.caption2)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.secondary)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(backgroundForRateCard(emphasized: emphasized))
    }

    @ViewBuilder
    private func backgroundForRateCard(emphasized: Bool) -> some View {
        glassCard(
            cornerRadius: 12,
            tint: emphasized
                ? accentBlue.opacity(0.18)
                : Color(uiColor: .secondarySystemFill).opacity(0.36)
        )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(emphasized ? accentBlue.opacity(0.45) : glassStrokeColor, lineWidth: emphasized ? 1.3 : 1)
            }
    }

    private var allRatesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("更多汇率")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(navy)

            if otherRateRows.isEmpty {
                Text("暂无更多汇率数据")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: rateGridColumns, spacing: 10) {
                    ForEach(otherRateRows, id: \.code) { row in
                        rateCard(code: row.code, emphasized: false)
                    }
                }
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let updatedAt = viewModel.lastUpdatedAt {
                Text("最后更新：\(dateFormatter.string(from: updatedAt))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pageBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    pageBg,
                    pageBgMid,
                    pageBgBottom
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(uiColor: .systemGray5).opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 44)
                .offset(x: -130, y: -300)

            Circle()
                .fill(accentBlue.opacity(0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 48)
                .offset(x: 130, y: -220)
        }
    }

    private func glassCard(cornerRadius: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(tint)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(glassStrokeColor, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}
