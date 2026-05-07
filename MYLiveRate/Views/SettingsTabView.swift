import SwiftUI

private let appThemeStorageKey = "myliverate.app_theme"
private let defaultLandingTabStorageKey = "myliverate.default_landing_tab"

struct SettingsTabView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("通用设置") {
                    GeneralSettingsView()
                }

                NavigationLink("默认落地") {
                    DefaultLandingTabSettingsView()
                }

                NavigationLink("接口密钥") {
                    APIKeySettingsView(viewModel: viewModel)
                }
            }
            .navigationTitle("设置")
        }
    }
}

private struct DefaultLandingTabSettingsView: View {
    @AppStorage(defaultLandingTabStorageKey) private var selectedTabRawValue: String = DefaultLandingTab.rates.rawValue

    var body: some View {
        List {
            Section("默认落地") {
                ForEach(DefaultLandingTab.allCases) { tab in
                    Button {
                        selectedTabRawValue = tab.rawValue
                    } label: {
                        HStack {
                            Text(tab.displayName)
                            Spacer()
                            if selectedTabRawValue == tab.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .navigationTitle("默认落地")
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

    private var finnhubKeyBinding: Binding<String> {
        Binding(
            get: { viewModel.finnhubAPIKey },
            set: { viewModel.updateFinnhubAPIKey($0) }
        )
    }

    private func saveTokenWithFeedback() {
        let trimmed = viewModel.finnhubAPIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hasRefreshedSuccessfully = false
            refreshSuccessMessage = nil
            refreshFailureMessage = "接口密钥不能为空"
            return
        }

        viewModel.updateFinnhubAPIKey(trimmed)
        Task {
            let validationError = await viewModel.validateFinnhubTokenWithDefaultSymbol()
            if let validationError {
                hasRefreshedSuccessfully = false
                refreshSuccessMessage = nil
                refreshFailureMessage = validationError
            } else {
                hasRefreshedSuccessfully = true
                refreshSuccessMessage = "token 有效（AAPL 校验通过）"
                refreshFailureMessage = nil
            }
        }
    }

    var body: some View {
        List {
            Section("接口密钥") {
                TextField("请输入 Finnhub 接口密钥", text: finnhubKeyBinding)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .submitLabel(.done)
                    .onSubmit {
                        saveTokenWithFeedback()
                    }

                if !hasRefreshedSuccessfully {
                    Button("保存并校验") {
                        saveTokenWithFeedback()
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

                Text("请填写 Finnhub 的 token。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("接口密钥")
        .onChange(of: viewModel.finnhubAPIKey) { _, _ in
            hasRefreshedSuccessfully = false
            refreshSuccessMessage = nil
            refreshFailureMessage = nil
        }
    }
}
