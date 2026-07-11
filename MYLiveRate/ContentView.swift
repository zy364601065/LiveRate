import SwiftUI
import PhotosUI

struct ContentView: View {
    private enum MainTab: Hashable {
        case rates
        case holdings
        case stats
        case settings
    }

    @StateObject private var viewModel: ExchangeRateViewModel
    @StateObject private var userProfileViewModel = UserProfileViewModel()
    @StateObject private var statsMoodViewModel = StatsMoodViewModel()
    @StateObject private var statsFullscreenAnimationViewModel = StatsFullscreenAnimationViewModel()
    @StateObject private var statsTrendMessageViewModel = StatsTrendMessageViewModel()
    @State private var selectedTab: MainTab = .rates
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedHoldingPhotoItem: PhotosPickerItem?
    @State private var birthdayAnimationToPlay: StatsFullscreenAnimation?
    @State private var isRateImportPromptPresented = false
    @AppStorage("myliverate.app_theme") private var appThemeRawValue: String = AppTheme.system.rawValue
    @AppStorage("myliverate.default_landing_tab") private var defaultLandingTabRawValue: String = DefaultLandingTab.rates.rawValue
    private let tabAccentColor = Color(red: 0.95, green: 0.52, blue: 0.16)

    @MainActor
    init() {
        _viewModel = StateObject(wrappedValue: ExchangeRateViewModel(localRecordsStore: .shared))
    }

    init(localRecordsStore: LocalRecordsStore) {
        _viewModel = StateObject(wrappedValue: ExchangeRateViewModel(localRecordsStore: localRecordsStore))
    }

    private var preferredScheme: ColorScheme? {
        switch AppTheme(rawValue: appThemeRawValue) ?? .system {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                Tab("汇率", systemImage: "dollarsign.circle", value: .rates) {
                    LiveRateTabView(viewModel: viewModel, selectedPhotoItem: $selectedPhotoItem)
                }

                Tab("持仓", systemImage: "briefcase", value: .holdings) {
                    HoldingsTabView(viewModel: viewModel, selectedHoldingPhotoItem: $selectedHoldingPhotoItem)
                }

                Tab("统计", systemImage: "calendar", value: .stats) {
                    StatsDashboardView(
                        viewModel: viewModel,
                        statsMoodViewModel: statsMoodViewModel,
                        statsFullscreenAnimationViewModel: statsFullscreenAnimationViewModel,
                        statsTrendMessageViewModel: statsTrendMessageViewModel
                    )
                }

                Tab("设置", systemImage: "gearshape", value: .settings) {
                    SettingsTabView(
                        viewModel: viewModel,
                        userProfileViewModel: userProfileViewModel,
                        statsMoodViewModel: statsMoodViewModel
                    )
                }
            }

            if let animation = birthdayAnimationToPlay {
                FullscreenDotLottieOverlay(animation: animation) {
                    markBirthdayAnimationPlayed(animation)
                } onDismiss: {
                    markBirthdayAnimationPlayed(animation)
                    birthdayAnimationToPlay = nil
                }
            }

            if isRateImportPromptPresented {
                FirstRateImportPrompt(
                    onSkip: { completeRateImportPrompt(goToHoldings: false) },
                    onUpload: { completeRateImportPrompt(goToHoldings: true) }
                )
                .zIndex(20)
            }
        }
        .tint(tabAccentColor)
        .preferredColorScheme(preferredScheme)
        .onAppear {
            let configured = DefaultLandingTab(rawValue: defaultLandingTabRawValue) ?? .rates
            selectedTab = mapToMainTab(configured)
        }
        .task {
            await userProfileViewModel.loadOrCreateProfile()
            await statsMoodViewModel.loadModes()
            await statsFullscreenAnimationViewModel.loadAnimations()
            await statsTrendMessageViewModel.loadMessages()
            await viewModel.syncStatUploadRecords()
            await viewModel.syncHoldings()
            await viewModel.refresh()
            evaluateBirthdayAnimationTrigger()
        }
        .onChange(of: userProfileViewModel.profile) { _, _ in
            evaluateBirthdayAnimationTrigger()
            evaluateRateImportPrompt()
        }
        .onChange(of: selectedTab) { _, _ in
            evaluateRateImportPrompt()
        }
        .onChange(of: statsFullscreenAnimationViewModel.birthdayHomeAnimations) { _, _ in
            evaluateBirthdayAnimationTrigger()
        }
        .onChange(of: selectedPhotoItem) {
            Task {
                guard let item = selectedPhotoItem,
                      let data = try? await item.loadTransferable(type: Data.self) else {
                    return
                }
                await viewModel.recognizeUSDAmount(from: data)
            }
        }
        .onChange(of: viewModel.baseCurrency) { _, _ in
            Task {
                await viewModel.refresh()
            }
        }
        .onChange(of: selectedHoldingPhotoItem) {
            Task {
                guard let item = selectedHoldingPhotoItem,
                      let data = try? await item.loadTransferable(type: Data.self) else {
                    selectedHoldingPhotoItem = nil
                    return
                }
                await viewModel.recognizeHolding(from: data)
                // Clear the picker selection so choosing the same screenshot again
                // always triggers a fresh OCR request.
                selectedHoldingPhotoItem = nil
            }
        }
    }

    private func mapToMainTab(_ tab: DefaultLandingTab) -> MainTab {
        switch tab {
        case .rates:
            return .rates
        case .holdings:
            return .holdings
        case .stats:
            return .stats
        }
    }

    private func evaluateRateImportPrompt() {
        guard selectedTab == .rates,
              let userID = userProfileViewModel.profile?.id else {
            isRateImportPromptPresented = false
            return
        }
        isRateImportPromptPresented = !UserDefaults.standard.bool(forKey: rateImportPromptKey(userID: userID))
    }

    private func completeRateImportPrompt(goToHoldings: Bool) {
        guard let userID = userProfileViewModel.profile?.id else { return }
        UserDefaults.standard.set(true, forKey: rateImportPromptKey(userID: userID))
        isRateImportPromptPresented = false
        if goToHoldings {
            selectedTab = .holdings
        }
    }

    private func rateImportPromptKey(userID: UUID) -> String {
        "myliverate.rate_import_prompt.handled.v1.\(userID.uuidString)"
    }

    private func evaluateBirthdayAnimationTrigger() {
        guard birthdayAnimationToPlay == nil else { return }
        guard let profile = userProfileViewModel.profile else { return }
        guard isBirthdayToday(profile.birthday) else { return }
        guard let animation = statsFullscreenAnimationViewModel.preferredBirthdayHomeAnimation else {
            print("[BirthdayAnimation] no enabled birthday_home animation")
            return
        }
        guard !hasPlayedBirthdayAnimation(animation, userID: profile.id) else { return }

        print("[BirthdayAnimation] presenting birthday animation id=\(animation.id)")
        birthdayAnimationToPlay = animation
    }

    private func isBirthdayToday(_ birthday: String?) -> Bool {
        guard let birthday, birthday.count >= 10 else { return false }
        let birthdayMonthDay = String(birthday.suffix(5))
        return birthdayMonthDay == Self.monthDayFormatter.string(from: Date())
    }

    private func markBirthdayAnimationPlayed(_ animation: StatsFullscreenAnimation) {
        guard let userID = userProfileViewModel.profile?.id else { return }
        UserDefaults.standard.set(true, forKey: birthdayAnimationPlaybackKey(animation, userID: userID))
    }

    private func hasPlayedBirthdayAnimation(_ animation: StatsFullscreenAnimation, userID: UUID) -> Bool {
        UserDefaults.standard.bool(forKey: birthdayAnimationPlaybackKey(animation, userID: userID))
    }

    private func birthdayAnimationPlaybackKey(_ animation: StatsFullscreenAnimation, userID: UUID) -> String {
        let day = Self.dateKeyFormatter.string(from: Date())
        return "myliverate.birthday_home_animation.played.\(userID.uuidString).\(day).\(animation.id.uuidString)"
    }

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MM-dd"
        return formatter
    }()

    private static let dateKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct FirstRateImportPrompt: View {
    let onSkip: () -> Void
    let onUpload: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "tray.and.arrow.down.fill")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.orange)
                    .frame(width: 58, height: 58)
                    .background(.orange.opacity(0.12), in: Circle())

                VStack(spacing: 8) {
                    Text("快速导入，精准记账")
                        .font(.title2.bold())
                    Text("上传您的当前持仓，我们将自动为您换算多币种汇率并实时更新资产大盘。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(spacing: 10) {
                    Button("去上传持仓", action: onUpload)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)

                    Button("暂不上传", action: onSkip)
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(24)
            .frame(maxWidth: 360)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.24), radius: 30, y: 14)
            .padding(24)
        }
        .accessibilityAddTraits(.isModal)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
