import SwiftUI

private let appThemeStorageKey = "myliverate.app_theme"

struct SettingsTabView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("通用设置") {
                    GeneralSettingsView()
                }

                NavigationLink("接口密钥") {
                    APIKeySettingsView(viewModel: viewModel)
                }
            }
            .navigationTitle("设置")
        }
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(appThemeStorageKey) private var appThemeRawValue: String = AppTheme.system.rawValue

    private var selectedThemeBinding: Binding<AppTheme> {
        Binding(
            get: { AppTheme(rawValue: appThemeRawValue) ?? .system },
            set: { appThemeRawValue = $0.rawValue }
        )
    }

    var body: some View {
        List {
            Section("通用设置") {
                Picker("主题模式", selection: selectedThemeBinding) {
                    ForEach(AppTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.inline)
            }
        }
        .navigationTitle("通用设置")
    }
}

private struct APIKeySettingsView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel
    @State private var hasRefreshedSuccessfully = false
    @State private var refreshSuccessMessage: String?
    @State private var refreshFailureMessage: String?

    private var alphaVantageKeyBinding: Binding<String> {
        Binding(
            get: { viewModel.alphaVantageAPIKey },
            set: { viewModel.updateAlphaVantageAPIKey($0) }
        )
    }

    private func refreshWithFeedback() {
        Task {
            await viewModel.refreshStocksOnly()
            if viewModel.stockErrorMessage == nil {
                hasRefreshedSuccessfully = true
                refreshSuccessMessage = "刷新成功"
                refreshFailureMessage = nil
            } else {
                hasRefreshedSuccessfully = false
                refreshSuccessMessage = nil
                if let stockErrorMessage = viewModel.stockErrorMessage, !stockErrorMessage.isEmpty {
                    refreshFailureMessage = stockErrorMessage
                } else if let holdingStockErrorMessage = viewModel.holdingStockErrorMessage, !holdingStockErrorMessage.isEmpty {
                    refreshFailureMessage = holdingStockErrorMessage
                } else {
                    refreshFailureMessage = "刷新失败，请稍后重试"
                }
            }
        }
    }

    var body: some View {
        List {
            Section("接口密钥") {
                TextField("请输入接口密钥", text: alphaVantageKeyBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .onSubmit {
                        refreshWithFeedback()
                    }

                if !hasRefreshedSuccessfully {
                    Button("立即刷新股票行情") {
                        refreshWithFeedback()
                    }
                    .disabled(viewModel.isLoading)
                }

                if let refreshSuccessMessage {
                    Text(refreshSuccessMessage)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }

                if let refreshFailureMessage {
                    Text(refreshFailureMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Text("可先使用演示密钥 demo 测试；正式使用建议替换为你自己的密钥。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("接口密钥")
        .onChange(of: viewModel.alphaVantageAPIKey) { _, _ in
            hasRefreshedSuccessfully = false
            refreshSuccessMessage = nil
            refreshFailureMessage = nil
        }
    }
}
