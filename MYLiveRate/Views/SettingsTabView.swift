import SwiftUI
import UIKit

private let appThemeStorageKey = "myliverate.app_theme"
private let defaultLandingTabStorageKey = "myliverate.default_landing_tab"

private let settingsTitleColor = Color(uiColor: .label)
private let settingsAccentColor = Color(red: 0.95, green: 0.52, blue: 0.16)
private let settingsSurfaceColor = Color(uiColor: UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor(red: 0.12, green: 0.12, blue: 0.13, alpha: 1)
        : UIColor.white
})
private let settingsSecondarySurfaceColor = Color(uiColor: UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor(red: 0.16, green: 0.16, blue: 0.17, alpha: 1)
        : UIColor(red: 0.965, green: 0.965, blue: 0.95, alpha: 1)
})
private let settingsDividerColor = Color(uiColor: UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor(white: 1, alpha: 0.09)
        : UIColor(white: 0, alpha: 0.08)
})
private let settingsBackgroundTop = Color(uiColor: UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        : UIColor(red: 0.976, green: 0.974, blue: 0.958, alpha: 1)
})
private let settingsBackgroundBottom = Color(uiColor: UIColor { trait in
    trait.userInterfaceStyle == .dark
        ? UIColor(red: 0.05, green: 0.05, blue: 0.06, alpha: 1)
        : UIColor(red: 0.944, green: 0.94, blue: 0.918, alpha: 1)
})
private struct SettingsPageBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                settingsBackgroundTop,
                settingsBackgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private struct SettingsEntryRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let trailing: String?

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(settingsAccentColor)
                .frame(width: 36, height: 36)
                .background(settingsAccentColor.opacity(0.11), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

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
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .frame(maxWidth: 118, alignment: .trailing)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }
}

private struct SettingsMenuGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 4)
            .background(settingsSurfaceColor, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(settingsDividerColor, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(0.04), radius: 14, x: 0, y: 7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsMenuDivider: View {
    var body: some View {
        Rectangle()
            .fill(settingsDividerColor)
            .frame(height: 1)
            .padding(.leading, 49)
    }
}

private struct SettingsAccountHeader: View {
    @ObservedObject var profileViewModel: UserProfileViewModel

    var body: some View {
        NavigationLink {
            UserProfileSettingsView(profileViewModel: profileViewModel)
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    settingsAccentColor,
                                    Color(red: 0.98, green: 0.68, blue: 0.30)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(profileViewModel.displayNickname.prefix(1))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 5) {
                    Text(profileViewModel.displayNickname)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(settingsTitleColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    Text("个人资料与账号 ID")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if profileViewModel.isLoading {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在同步")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            .background(settingsSurfaceColor, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(settingsDividerColor, lineWidth: 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsCompactOptionRow: View {
    let title: String
    let icon: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(isSelected ? settingsAccentColor : settingsTitleColor.opacity(0.76))
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? settingsAccentColor.opacity(0.12) : settingsSecondarySurfaceColor)
                )

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(settingsTitleColor)

            Spacer(minLength: 8)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(settingsAccentColor)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

struct SettingsTabView: View {
    @ObservedObject var viewModel: ExchangeRateViewModel
    @ObservedObject var userProfileViewModel: UserProfileViewModel
    @ObservedObject var statsMoodViewModel: StatsMoodViewModel
    @AppStorage(appThemeStorageKey) private var appThemeRawValue: String = AppTheme.system.rawValue
    @AppStorage(defaultLandingTabStorageKey) private var defaultLandingTabRawValue: String = DefaultLandingTab.rates.rawValue
    @AppStorage(statsMoodModeStorageKey) private var statsMoodModeRawValue: String = StatsMoodMode.standard.rawValue
    @AppStorage(luluMoodBehaviorStorageKey) private var luluMoodBehaviorRawValue: String = LuluMoodBehavior.random.rawValue
    @AppStorage(customStatsMoodModeIDStorageKey) private var customStatsMoodModeID: String = ""

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }

    private var selectedLanding: DefaultLandingTab {
        DefaultLandingTab(rawValue: defaultLandingTabRawValue) ?? .rates
    }

    private var selectedStatsMoodMode: StatsMoodMode {
        StatsMoodMode(rawValue: statsMoodModeRawValue) ?? .standard
    }

    private var selectedLuluMoodBehavior: LuluMoodBehavior {
        LuluMoodBehavior(rawValue: luluMoodBehaviorRawValue) ?? .random
    }

    private var statsMoodTrailingText: String {
        switch selectedStatsMoodMode {
        case .standard:
            return selectedStatsMoodMode.displayName
        case .lulu:
            return "\(selectedStatsMoodMode.displayName)·\(selectedLuluMoodBehavior.displayName)"
        case .custom:
            return statsMoodViewModel.mode(id: customStatsMoodModeID)?.name ?? "自定义"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    SettingsAccountHeader(profileViewModel: userProfileViewModel)

                    SettingsMenuGroup("偏好") {
                        NavigationLink {
                            GeneralSettingsView()
                        } label: {
                            SettingsEntryRow(
                                icon: "slider.horizontal.3",
                                title: "通用设置",
                                subtitle: "主题、展示与趋势文案",
                                trailing: selectedTheme.displayName
                            )
                        }
                        .buttonStyle(.plain)

                        SettingsMenuDivider()

                        NavigationLink {
                            StatsMoodSettingsView(statsMoodViewModel: statsMoodViewModel)
                        } label: {
                            SettingsEntryRow(
                                icon: "face.smiling",
                                title: "统计表情",
                                subtitle: "噜噜随机、手动与默认表情",
                                trailing: statsMoodTrailingText
                            )
                        }
                        .buttonStyle(.plain)

                        SettingsMenuDivider()

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
                        .buttonStyle(.plain)
                    }

#if DEBUG
                    SettingsMenuGroup("高级") {
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
                        .buttonStyle(.plain)
                    }
#endif
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
            }
            .background(SettingsPageBackground())
            .navigationTitle("设置")
        }
    }
}

private struct UserProfileSettingsView: View {
    @ObservedObject var profileViewModel: UserProfileViewModel
    @State private var draftNickname = ""
    @State private var hasSeededDraft = false

    private var trimmedNickname: String {
        draftNickname.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        UserProfileViewModel.isValidNickname(trimmedNickname)
            && trimmedNickname != (profileViewModel.nickname ?? "")
            && !profileViewModel.isSaving
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SettingsMenuGroup("昵称") {
                    VStack(alignment: .leading, spacing: 12) {
                        Label {
                            Text("显示昵称")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(settingsTitleColor)
                        } icon: {
                            Image(systemName: "pencil.line")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(settingsAccentColor)
                        }
                        .labelStyle(.titleAndIcon)

                        TextField("众安_4839201", text: $draftNickname)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .font(.body)
                            .padding(.horizontal, 12)
                            .frame(minHeight: 48)
                            .background(settingsSecondarySurfaceColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(settingsDividerColor, lineWidth: 1)
                                .allowsHitTesting(false)
                        }
                            .accessibilityLabel("昵称")
                            .accessibilityHint("输入 1 到 24 个字符的昵称")

                        if let errorMessage = profileViewModel.errorMessage {
                            Text(errorMessage)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.red)
                                .accessibilityLabel("错误：\(errorMessage)")
                        }

                        Button {
                            Task {
                                await profileViewModel.updateNickname(draftNickname)
                                seedDraft(force: true)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if profileViewModel.isSaving {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                                Text(profileViewModel.isSaving ? "保存中" : "保存昵称")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 46)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(settingsAccentColor)
                        .disabled(!canSave)
                        .accessibilityHint(canSave ? "保存当前昵称" : "昵称未变化或格式不正确")
                    }
                    .padding(.vertical, 8)
                }

                SettingsMenuGroup("账号") {
                    VStack(alignment: .leading, spacing: 10) {
                        Label {
                            Text("Supabase 用户 ID")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(settingsTitleColor)
                        } icon: {
                            Image(systemName: "key.horizontal.fill")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(settingsAccentColor)
                        }
                        .labelStyle(.titleAndIcon)

                        Text(profileViewModel.userIDText)
                            .font(.footnote.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(3)
                            .minimumScaleFactor(0.82)
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(settingsSecondarySurfaceColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                        if profileViewModel.isLoading {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("正在同步个人信息")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } else if profileViewModel.canRetry {
                            Button {
                                Task {
                                    await profileViewModel.loadOrCreateProfile()
                                    seedDraft(force: true)
                                }
                            } label: {
                                Label("重新同步", systemImage: "arrow.clockwise")
                                    .frame(minHeight: 44)
                            }
                            .buttonStyle(.bordered)
                            .tint(settingsAccentColor)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(SettingsPageBackground())
        .navigationTitle("个人信息")
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            seedDraft()
        }
        .onChange(of: profileViewModel.nickname) {
            seedDraft(force: !hasSeededDraft)
        }
    }

    private func seedDraft(force: Bool = false) {
        guard force || !hasSeededDraft else { return }
        draftNickname = profileViewModel.nickname ?? ""
        hasSeededDraft = true
    }
}

private struct DefaultLandingTabSettingsView: View {
    @AppStorage(defaultLandingTabStorageKey) private var selectedTabRawValue: String = DefaultLandingTab.rates.rawValue

    private func icon(for tab: DefaultLandingTab) -> String {
        switch tab {
        case .rates: return "dollarsign.arrow.trianglehead.counterclockwise.rotate.90"
        case .holdings: return "briefcase.fill"
        case .stats: return "chart.bar.fill"
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            SettingsMenuGroup("启动页面") {
                VStack(spacing: 0) {
                    ForEach(Array(DefaultLandingTab.allCases.enumerated()), id: \.element.id) { index, tab in
                        Button {
                            selectedTabRawValue = tab.rawValue
                        } label: {
                            SettingsCompactOptionRow(
                                title: tab.displayName,
                                icon: icon(for: tab),
                                isSelected: selectedTabRawValue == tab.rawValue
                            )
                        }
                        .foregroundStyle(.primary)
                        .buttonStyle(.plain)

                        if index < DefaultLandingTab.allCases.count - 1 {
                            SettingsMenuDivider()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(SettingsPageBackground())
        .navigationTitle("默认落地")
        .toolbar(.hidden, for: .tabBar)
    }
}

private struct GeneralSettingsView: View {
    @AppStorage(appThemeStorageKey) private var appThemeRawValue: String = AppTheme.system.rawValue
    @AppStorage(showAllExchangeRatesStorageKey) private var showAllExchangeRates = false
    @AppStorage(trendHintToneStorageKey) private var trendHintToneRawValue: String = TrendHintTone.wild.rawValue

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }

    private var selectedHintTone: TrendHintTone {
        TrendHintTone(rawValue: trendHintToneRawValue) ?? .wild
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SettingsMenuGroup("外观") {
                    VStack(spacing: 0) {
                        ForEach(Array(AppTheme.allCases.enumerated()), id: \.element.id) { index, theme in
                            Button {
                                appThemeRawValue = theme.rawValue
                            } label: {
                                SettingsCompactOptionRow(
                                    title: theme.displayName,
                                    icon: themeIcon(for: theme),
                                    isSelected: selectedTheme == theme
                                )
                            }
                            .buttonStyle(.plain)

                            if index < AppTheme.allCases.count - 1 {
                                SettingsMenuDivider()
                            }
                        }
                    }
                }

                SettingsMenuGroup("汇率展示") {
                    Toggle(isOn: $showAllExchangeRates) {
                        Label {
                            Text("显示其他汇率")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(settingsTitleColor)
                        } icon: {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(settingsAccentColor)
                                .frame(width: 34, height: 34)
                                .background(settingsAccentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .toggleStyle(.switch)
                    .frame(minHeight: 52)
                }

                SettingsMenuGroup("统计提示") {
                    VStack(spacing: 0) {
                        ForEach(Array(TrendHintTone.allCases.enumerated()), id: \.element.id) { index, tone in
                            Button {
                                trendHintToneRawValue = tone.rawValue
                            } label: {
                                SettingsCompactOptionRow(
                                    title: tone.displayName,
                                    icon: "waveform.path.ecg",
                                    isSelected: selectedHintTone == tone
                                )
                            }
                            .buttonStyle(.plain)

                            if index < TrendHintTone.allCases.count - 1 {
                                SettingsMenuDivider()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(SettingsPageBackground())
        .navigationTitle("通用设置")
        .toolbar(.hidden, for: .tabBar)
    }

    private func themeIcon(for theme: AppTheme) -> String {
        switch theme {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
}

private struct StatsMoodSettingsView: View {
    @ObservedObject var statsMoodViewModel: StatsMoodViewModel
    @AppStorage(statsMoodModeStorageKey) private var statsMoodModeRawValue: String = StatsMoodMode.standard.rawValue
    @AppStorage(luluMoodBehaviorStorageKey) private var luluMoodBehaviorRawValue: String = LuluMoodBehavior.random.rawValue
    @AppStorage(luluHappyAssetStorageKey) private var luluHappyAssetRawValue: String = LuluHappyAsset.happy1.rawValue
    @AppStorage(luluBadAssetStorageKey) private var luluBadAssetRawValue: String = LuluBadAsset.bad1.rawValue
    @AppStorage(customStatsMoodModeIDStorageKey) private var customStatsMoodModeID: String = ""

    private var selectedStatsMoodMode: StatsMoodMode {
        StatsMoodMode(rawValue: statsMoodModeRawValue) ?? .standard
    }

    private var selectedLuluMoodBehavior: LuluMoodBehavior {
        LuluMoodBehavior(rawValue: luluMoodBehaviorRawValue) ?? .random
    }

    private var selectedHappyAsset: LuluHappyAsset {
        LuluHappyAsset(rawValue: luluHappyAssetRawValue) ?? .happy1
    }

    private var selectedBadAsset: LuluBadAsset {
        LuluBadAsset(rawValue: luluBadAssetRawValue) ?? .bad1
    }

    private var luluMoodBehaviorBinding: Binding<LuluMoodBehavior> {
        Binding {
            selectedLuluMoodBehavior
        } set: { newValue in
            withAnimation(.easeInOut(duration: 0.18)) {
                luluMoodBehaviorRawValue = newValue.rawValue
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SettingsMenuGroup("表情模式") {
                    VStack(spacing: 0) {
                        let builtInModes: [StatsMoodMode] = [.standard, .lulu]
                        ForEach(Array(builtInModes.enumerated()), id: \.element.id) { index, mode in
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    statsMoodModeRawValue = mode.rawValue
                                }
                            } label: {
                                SettingsCompactOptionRow(
                                    title: mode.displayName,
                                    icon: mode == .standard ? "sparkles" : "popcorn.circle.fill",
                                    isSelected: selectedStatsMoodMode == mode
                                )
                            }
                            .buttonStyle(.plain)

                            if index < builtInModes.count - 1 {
                                SettingsMenuDivider()
                            }
                        }
                    }
                }

                if !statsMoodViewModel.customModes.isEmpty {
                    SettingsMenuGroup("后台模式") {
                        VStack(spacing: 0) {
                            ForEach(Array(statsMoodViewModel.customModes.enumerated()), id: \.element.id) { index, mode in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.18)) {
                                        customStatsMoodModeID = mode.id.uuidString
                                        statsMoodModeRawValue = StatsMoodMode.custom.rawValue
                                    }
                                } label: {
                                    SettingsCompactOptionRow(
                                        title: mode.name,
                                        icon: mode.scope == "global" ? "globe.asia.australia.fill" : "person.crop.circle.fill.badge.checkmark",
                                        isSelected: selectedStatsMoodMode == .custom && customStatsMoodModeID == mode.id.uuidString
                                    )
                                }
                                .buttonStyle(.plain)

                                if index < statsMoodViewModel.customModes.count - 1 {
                                    SettingsMenuDivider()
                                }
                            }
                        }
                    }
                }

                if statsMoodViewModel.isLoading {
                    SettingsMenuGroup("同步状态") {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("正在同步后台表情模式")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                } else if let errorMessage = statsMoodViewModel.errorMessage {
                    SettingsMenuGroup("同步状态") {
                        Text(errorMessage)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    }
                }

                if selectedStatsMoodMode == .lulu {
                    SettingsMenuGroup("噜噜玩法") {
                        Picker("噜噜玩法", selection: luluMoodBehaviorBinding) {
                            ForEach(LuluMoodBehavior.allCases) { behavior in
                                Text(behavior.displayName)
                                    .tag(behavior)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(settingsAccentColor)
                        .padding(.vertical, 8)
                    }

                    SettingsMenuGroup("默认表情") {
                        StatsMoodPreviewCard(
                            title: "默认表情",
                            fileName: luluDefaultGIFName
                        )
                    }

                    if selectedLuluMoodBehavior == .manual {
                        SettingsMenuGroup("盈利表情") {
                            StatsMoodAssetGrid(
                                items: LuluHappyAsset.allCases.map { ($0.displayName, $0.fileName, selectedHappyAsset == $0) }
                            ) { index in
                                luluHappyAssetRawValue = LuluHappyAsset.allCases[index].rawValue
                            }
                        }

                        SettingsMenuGroup("亏损表情") {
                            StatsMoodAssetGrid(
                                items: LuluBadAsset.allCases.map { ($0.displayName, $0.fileName, selectedBadAsset == $0) }
                            ) { index in
                                luluBadAssetRawValue = LuluBadAsset.allCases[index].rawValue
                            }
                        }
                    }
                }

            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(SettingsPageBackground())
        .navigationTitle("统计表情")
        .toolbar(.hidden, for: .tabBar)
        .task {
            await statsMoodViewModel.loadModes()
        }
    }
}

private struct StatsMoodPreviewCard: View {
    let title: String
    let fileName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(settingsTitleColor)

            StatsMoodGIFThumbnail(fileName: fileName, style: .hero)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 8)
    }
}

private struct StatsMoodAssetGrid: View {
    let items: [(title: String, fileName: String, isSelected: Bool)]
    let onSelect: (Int) -> Void

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    Button {
                        onSelect(index)
                    } label: {
                        StatsMoodAssetCard(
                            title: item.title,
                            fileName: item.fileName,
                            isSelected: item.isSelected
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct StatsMoodAssetCard: View {
    let title: String
    let fileName: String
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                StatsMoodGIFThumbnail(fileName: fileName, style: .picker)

                if isSelected {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("已选")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(settingsAccentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(settingsAccentColor.opacity(0.28), lineWidth: 1)
                    }
                    .padding(8)
                }
            }

            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(settingsTitleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .padding(.horizontal, 2)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? settingsAccentColor.opacity(0.08) : settingsSecondarySurfaceColor)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? settingsAccentColor.opacity(0.42) : settingsDividerColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityAddTraits(.isButton)
    }
}

private enum StatsMoodThumbnailStyle {
    case hero
    case picker
}

private struct StatsMoodGIFThumbnail: View {
    let fileName: String
    let style: StatsMoodThumbnailStyle

    private var frameSize: CGSize {
        switch style {
        case .hero:
            return CGSize(width: 156, height: 156)
        case .picker:
            return CGSize(width: 146, height: 118)
        }
    }

    private var cornerRadius: CGFloat {
        switch style {
        case .hero:
            return 22
        case .picker:
            return 16
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.94),
                            settingsAccentColor.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            RoundedRectangle(cornerRadius: cornerRadius - 2, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.72))

            KingfisherGIFView(fileName: fileName)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: frameSize.width, height: frameSize.height)
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(settingsDividerColor, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: style == .hero ? 12 : 8, x: 0, y: 4)
    }
}

#if DEBUG
private struct DebugLabSettingsView: View {
    @AppStorage(trendHintLabScenarioStorageKey) private var trendHintLabScenarioRawValue: String = TrendHintLabScenario.none.rawValue

    private var selectedScenario: TrendHintLabScenario {
        TrendHintLabScenario(rawValue: trendHintLabScenarioRawValue) ?? .none
    }

    private var quickScenarios: [TrendHintLabScenario] {
        [.none, .profitStreak4, .lossStreak4, .shortStreak3, .latestZero]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            SettingsMenuGroup("趋势测试场景") {
                VStack(spacing: 0) {
                    ForEach(Array(quickScenarios.enumerated()), id: \.element.id) { index, scenario in
                        Button {
                            trendHintLabScenarioRawValue = scenario.rawValue
                        } label: {
                            SettingsCompactOptionRow(
                                title: scenario.displayName,
                                icon: "waveform.path.badge.plus",
                                isSelected: selectedScenario == scenario
                            )
                        }
                        .buttonStyle(.plain)

                        if index < quickScenarios.count - 1 {
                            SettingsMenuDivider()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 28)
        }
        .background(SettingsPageBackground())
        .navigationTitle("实验室")
        .toolbar(.hidden, for: .tabBar)
    }
}
#endif
