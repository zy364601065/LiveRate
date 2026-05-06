import SwiftUI
import PhotosUI
import UIKit

struct LiveRateTabView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel
    @Binding var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingImagePreview = false
    @FocusState private var isAmountFieldFocused: Bool

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("实时汇率")
                    .font(.largeTitle.bold())

                VStack(alignment: .leading, spacing: 10) {
                    Text("输入金额")
                        .font(.headline)

                    TextField("例如 100", text: $viewModel.amountText)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.roundedBorder)
                        .focused($isAmountFieldFocused)

                    HStack(alignment: .top, spacing: 12) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("上传图片识别美元金额", systemImage: "photo.on.rectangle")
                                .font(.subheadline.weight(.semibold))
                        }

                        Spacer()

                        if let imageData = viewModel.latestUploadThumbnailData,
                           let image = UIImage(data: imageData) {
                            Button {
                                isShowingImagePreview = true
                            } label: {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if viewModel.isRecognizingAmount {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("正在识别图片中的美元金额...")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let ocrMessage = viewModel.ocrMessage {
                        Text(ocrMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Picker(
                        "基准货币",
                        selection: Binding(
                            get: { viewModel.baseCurrency },
                            set: { viewModel.updateBaseCurrency($0) }
                        )
                    ) {
                        ForEach(Currency.allCases) { currency in
                            Text(currency.displayName).tag(currency)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("实时等价值")
                        .font(.headline)

                    ForEach(viewModel.targetCurrencies) { currency in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(currency.displayName)
                                .font(.headline)

                            Text(viewModel.rateText(for: currency))
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Text(viewModel.formatAmount(
                                viewModel.convertedAmount(for: currency),
                                currency: currency
                            ))
                            .font(.system(size: 32, weight: .bold))
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    }
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

                Spacer()
            }
            .padding()
            .contentShape(Rectangle())
            .onTapGesture {
                isAmountFieldFocused = false
            }
            .navigationTitle("实时汇率")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新") {
                        Task {
                            await viewModel.refresh()
                        }
                    }
                    .disabled(viewModel.isLoading)
                }
            }
            .overlay(alignment: .topTrailing) {
                if viewModel.isLoading {
                    ProgressView()
                        .padding(.top, 8)
                        .padding(.trailing, 76)
                }
            }
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
                            Button("关闭") {
                                isShowingImagePreview = false
                            }
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }
}
