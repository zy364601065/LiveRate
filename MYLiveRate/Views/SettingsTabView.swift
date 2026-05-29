import SwiftUI

private let appThemeStorageKey = "myliverate.app_theme"
private let defaultLandingTabStorageKey = "myliverate.default_landing_tab"

private let settingsTitleColor = Color(red: 0.10, green: 0.16, blue: 0.24)
private let settingsAccentColor = Color(red: 0.72, green: 0.46, blue: 0.22)

private struct SettingsPageBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.99, green: 0.97, blue: 0.93),
                    Color(red: 0.99, green: 0.98, blue: 0.95)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Color(red: 0.98, green: 0.87, blue: 0.68).opacity(0.26))
                .frame(width: 260, height: 260)
                .blur(radius: 40)
                .offset(x: -120, y: -320)

            Circle()
                .fill(Color(red: 0.99, green: 0.93, blue: 0.80).opacity(0.22))
                .frame(width: 300, height: 300)
                .blur(radius: 48)
                .offset(x: 140, y: -250)
        }
        .ignoresSafeArea()
    }
}

private struct SettingsGlassRowBackground: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.white.opacity(0.20))
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.58), lineWidth: 1)
            }
    }
}

private struct SettingsEntryRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let trailing: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(settingsAccentColor)
                .frame(width: 32, height: 32)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(settingsTitleColor)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(settingsAccentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

private struct SettingsTagChip: View {
    let text: String
    let isSelected: Bool

    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(isSelected ? settingsAccentColor : settingsTitleColor.opacity(0.82))
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? settingsAccentColor.opacity(0.16) : Color.white.opacity(0.2))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? settingsAccentColor.opacity(0.34) : .white.opacity(0.48), lineWidth: 1)
            }
    }
}

private struct SettingsSubpageIntroCard: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(settingsAccentColor)
                .frame(width: 30, height: 30)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(settingsTitleColor)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(settingsTitleColor.opacity(0.72))
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}

private struct SettingsSelectionRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(settingsAccentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(settingsTitleColor)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(settingsAccentColor)
            }
        }
        .padding(.vertical, 5)
    }
}

struct SettingsTabView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel
    @AppStorage(appThemeStorageKey) private var appThemeRawValue: String = AppTheme.system.rawValue
    @AppStorage(defaultLandingTabStorageKey) private var defaultLandingTabRawValue: String = DefaultLandingTab.rates.rawValue

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }

    private var selectedLanding: DefaultLandingTab {
        DefaultLandingTab(rawValue: defaultLandingTabRawValue) ?? .rates
    }

    var body: some View {
        NavigationStack {
            List {
                Section("基础") {
                    NavigationLink {
                        GeneralSettingsView()
                    } label: {
                        SettingsEntryRow(
                            icon: "slider.horizontal.3",
                            title: "通用设置",
                            subtitle: "主题、展示与趋势文案模式",
                            trailing: selectedTheme.displayName
                        )
                    }

                    NavigationLink {
                        DefaultLandingTabSettingsView()
                    } label: {
                        SettingsEntryRow(
                            icon: "rectangle.on.rectangle",
                            title: "默认落地",
                            subtitle: "应用启动时默认进入页面",
                            trailing: selectedLanding.displayName
                        )
                    }
                }
                .listRowBackground(SettingsGlassRowBackground())

                Section("高级") {

                    NavigationLink {
                        APIKeySettingsView(viewModel: viewModel)
                    } label: {
                        SettingsEntryRow(
                            icon: "key.fill",
                            title: "接口密钥",
                            subtitle: "Finnhub token 保存与校验",
                            trailing: nil
                        )
                    }

#if DEBUG
                    NavigationLink {
                        DebugLabSettingsView()
                    } label: {
                        SettingsEntryRow(
                            icon: "flask.fill",
                            title: "实验室",
                            subtitle: "趋势提示测试场景",
                            trailing: nil
                        )
                    }
#endif
                }
                .listRowBackground(SettingsGlassRowBackground())
            }
            .scrollContentBackground(.hidden)
            .background(SettingsPageBackground())
            .listStyle(.insetGrouped)
            .navigationTitle("设置")
        }
    }
}

private struct DefaultLandingTabSettingsView: View {
    @AppStorage(defaultLandingTabStorageKey) private var selectedTabRawValue: String = DefaultLandingTab.rates.rawValue

    private func icon(for tab: DefaultLandingTab) -> String {
        switch tab {
        case .rates: return "dollarsign.arrow.trianglehead.counterclockwise.rotate.90"
        case .holdings: return "briefcase.fill"
        case .realtime: return "dot.radiowaves.left.and.right"
        case .stats: return "chart.bar.fill"
        }
    }

    var body: some View {
        List {
            Section {
                SettingsSubpageIntroCard(
                    title: "默认落地",
                    subtitle: "应用启动后自动进入你最常用的页面。",
                    icon: "rectangle.on.rectangle.angled"
                )
            }
            .listRowBackground(SettingsGlassRowBackground())
            .listRowSeparator(.hidden)

            Section("启动页面") {
                ForEach(DefaultLandingTab.allCases) { tab in
                    Button {
                        selectedTabRawValue = tab.rawValue
                    } label: {
                        SettingsSelectionRow(
                            title: tab.displayName,
                            subtitle: "设为打开应用后的默认页面",
                            icon: icon(for: tab),
                            isSelected: selectedTabRawValue == tab.rawValue
                        )
                    }
                    .foregroundStyle(.primary)
                    .buttonStyle(.plain)
                }
            }
            .listRowBackground(SettingsGlassRowBackground())
        }
        .scrollContentBackground(.hidden)
        .background(SettingsPageBackground())
        .navigationTitle("默认落地")
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(appThemeStorageKey) private var appThemeRawValue: String = AppTheme.system.rawValue
    @AppStorage(showAllExchangeRatesStorageKey) private var showAllExchangeRates = false
    @AppStorage(trendHintToneStorageKey) private var trendHintToneRawValue: String = TrendHintTone.wild.rawValue
    @State private var isHintToneDialogPresented = false

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }

    private var selectedHintTone: TrendHintTone {
        TrendHintTone(rawValue: trendHintToneRawValue) ?? .wild
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("通用设置")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(settingsTitleColor)
                    Text("调整主题外观、汇率展示范围与统计提示风格。")
                        .font(.subheadline)
                        .foregroundStyle(settingsTitleColor.opacity(0.72))
                        .lineSpacing(2)
                }
                .padding(.vertical, 4)
            }
            .listRowBackground(SettingsGlassRowBackground())
            .listRowSeparator(.hidden)

            Section("外观") {
                VStack(alignment: .leading, spacing: 11) {
                    Label {
                        Text("主题模式")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(settingsTitleColor)
                    } icon: {
                        Image(systemName: "sparkles")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(settingsAccentColor)
                    }
                    .labelStyle(.titleAndIcon)

                    Text("建议根据环境光线选择，视觉会更舒适。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(AppTheme.allCases) { theme in
                            Button {
                                appThemeRawValue = theme.rawValue
                            } label: {
                                SettingsTagChip(text: theme.displayName, isSelected: selectedTheme == theme)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(SettingsGlassRowBackground())

            Section("汇率展示") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(isOn: $showAllExchangeRates) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("显示其他汇率")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(settingsTitleColor)
                                Text("在汇率页追加更多币种卡片")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(settingsAccentColor)
                        }
                    }
                    .toggleStyle(.switch)

                    Text("关闭时只展示核心币种，界面更聚焦。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(SettingsGlassRowBackground())

            Section("统计提示") {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        isHintToneDialogPresented = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(settingsAccentColor)

                            Text("趋势文案模式")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(settingsTitleColor)

                            Spacer()

                            SettingsTagChip(text: selectedHintTone.displayName, isSelected: true)
                        }
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 8) {
                        ForEach(TrendHintTone.allCases) { tone in
                            Button {
                                trendHintToneRawValue = tone.rawValue
                            } label: {
                                SettingsTagChip(text: tone.displayName, isSelected: selectedHintTone == tone)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("默认模式：狂野。也可点击“趋势文案模式”弹窗选择。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(SettingsGlassRowBackground())
        }
        .scrollContentBackground(.hidden)
        .background(SettingsPageBackground())
        .navigationTitle("通用设置")
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog("选择趋势文案模式", isPresented: $isHintToneDialogPresented, titleVisibility: .visible) {
            ForEach(TrendHintTone.allCases) { tone in
                Button(tone.displayName) {
                    trendHintToneRawValue = tone.rawValue
                }
            }
            Button("取消", role: .cancel) {}
        }
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
            Section {
                SettingsSubpageIntroCard(
                    title: "接口密钥",
                    subtitle: "填写并校验 Finnhub Token，保证实时数据更新稳定。",
                    icon: "key.fill"
                )
            }
            .listRowBackground(SettingsGlassRowBackground())
            .listRowSeparator(.hidden)

            Section("Token 设置") {
                VStack(alignment: .leading, spacing: 10) {
                    Label {
                        Text("Finnhub Token")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(settingsTitleColor)
                    } icon: {
                        Image(systemName: "lock.shield")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(settingsAccentColor)
                    }

                    TextField("请输入 Finnhub 接口密钥", text: finnhubKeyBinding)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .submitLabel(.done)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.55), lineWidth: 1)
                        }
                        .onSubmit {
                            saveTokenWithFeedback()
                        }

                    if !hasRefreshedSuccessfully {
                        Button {
                            saveTokenWithFeedback()
                        } label: {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(settingsAccentColor)
                                } else {
                                    Image(systemName: "checkmark.shield")
                                        .font(.footnote.weight(.semibold))
                                }
                                Text(viewModel.isLoading ? "校验中..." : "保存并校验")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(settingsTitleColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(settingsAccentColor.opacity(0.16))
                            )
                        }
                        .buttonStyle(.plain)
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

                    Text("Token 不会上传到第三方服务，仅用于本地请求行情。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(SettingsGlassRowBackground())
        }
        .scrollContentBackground(.hidden)
        .background(SettingsPageBackground())
        .navigationTitle("接口密钥")
        .toolbar(.hidden, for: .tabBar)
        .onChange(of: viewModel.finnhubAPIKey) { _, _ in
            hasRefreshedSuccessfully = false
            refreshSuccessMessage = nil
            refreshFailureMessage = nil
        }
    }
}

#if DEBUG
private struct DebugLabSettingsView: View {
    @AppStorage(trendHintLabScenarioStorageKey) private var trendHintLabScenarioRawValue: String = TrendHintLabScenario.none.rawValue
    @State private var isScenarioDialogPresented = false

    private var selectedScenario: TrendHintLabScenario {
        TrendHintLabScenario(rawValue: trendHintLabScenarioRawValue) ?? .none
    }

    private var quickScenarios: [TrendHintLabScenario] {
        [.none, .profitStreak4, .lossStreak4, .shortStreak3, .latestZero]
    }

    var body: some View {
        List {
            Section {
                SettingsSubpageIntroCard(
                    title: "实验室",
                    subtitle: "仅用于调试统计趋势文案，不会修改真实业务记录。",
                    icon: "flask.fill"
                )
            }
            .listRowBackground(SettingsGlassRowBackground())
            .listRowSeparator(.hidden)

            Section("趋势测试场景") {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        isScenarioDialogPresented = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "waveform.path.badge.plus")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(settingsAccentColor)

                            Text("场景选择")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(settingsTitleColor)

                            Spacer()

                            SettingsTagChip(text: selectedScenario.displayName, isSelected: true)
                        }
                    }
                    .buttonStyle(.plain)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                        ForEach(quickScenarios) { scenario in
                            Button {
                                trendHintLabScenarioRawValue = scenario.rawValue
                            } label: {
                                SettingsTagChip(
                                    text: scenario.displayName,
                                    isSelected: selectedScenario == scenario
                                )
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("需要更快切换时可直接点上方标签。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
            .listRowBackground(SettingsGlassRowBackground())
        }
        .scrollContentBackground(.hidden)
        .background(SettingsPageBackground())
        .navigationTitle("实验室")
        .toolbar(.hidden, for: .tabBar)
        .confirmationDialog("选择测试场景", isPresented: $isScenarioDialogPresented, titleVisibility: .visible) {
            Button(TrendHintLabScenario.profitStreak4.displayName) {
                trendHintLabScenarioRawValue = TrendHintLabScenario.profitStreak4.rawValue
            }
            Button(TrendHintLabScenario.lossStreak4.displayName) {
                trendHintLabScenarioRawValue = TrendHintLabScenario.lossStreak4.rawValue
            }
            Button(TrendHintLabScenario.shortStreak3.displayName) {
                trendHintLabScenarioRawValue = TrendHintLabScenario.shortStreak3.rawValue
            }
            Button(TrendHintLabScenario.latestZero.displayName) {
                trendHintLabScenarioRawValue = TrendHintLabScenario.latestZero.rawValue
            }
            Button("恢复真实数据") {
                trendHintLabScenarioRawValue = TrendHintLabScenario.none.rawValue
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("仅影响统计页的连续趋势提示文案，不会写入真实业务数据。")
        }
    }
}
#endif
