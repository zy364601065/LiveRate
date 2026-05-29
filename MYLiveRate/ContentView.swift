import SwiftUI
import PhotosUI

struct ContentView: View {
    private enum MainTab: Hashable {
        case rates
        case holdings
        case realtime
        case stats
        case settings
    }

    @StateObject private var viewModel = ExchangeRateViewModel()
    @State private var selectedTab: MainTab = .rates
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedHoldingPhotoItem: PhotosPickerItem?
    @AppStorage("myliverate.app_theme") private var appThemeRawValue: String = AppTheme.system.rawValue
    @AppStorage("myliverate.default_landing_tab") private var defaultLandingTabRawValue: String = DefaultLandingTab.rates.rawValue
    private let tabAccentColor = Color(red: 0.95, green: 0.52, blue: 0.16)

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
        TabView(selection: $selectedTab) {
            Tab("汇率", systemImage: "dollarsign.circle", value: .rates) {
                LiveRateTabView(viewModel: viewModel, selectedPhotoItem: $selectedPhotoItem)
            }

            Tab("持仓", systemImage: "briefcase", value: .holdings) {
                HoldingsTabView(viewModel: viewModel, selectedHoldingPhotoItem: $selectedHoldingPhotoItem)
            }

            Tab("实时", systemImage: "chart.line.uptrend.xyaxis", value: .realtime) {
                LiveStockTabView(viewModel: viewModel)
            }

            Tab("统计", systemImage: "calendar", value: .stats) {
                StatsDashboardView(viewModel: viewModel)
            }

            Tab("设置", systemImage: "gearshape", value: .settings) {
                SettingsTabView(viewModel: viewModel)
            }
        }
        .tint(tabAccentColor)
        .preferredColorScheme(preferredScheme)
        .onAppear {
            let configured = DefaultLandingTab(rawValue: defaultLandingTabRawValue) ?? .rates
            selectedTab = mapToMainTab(configured)
        }
        .task {
            await viewModel.refresh()
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
                    return
                }
                await viewModel.recognizeHolding(from: data)
            }
        }
    }

    private func mapToMainTab(_ tab: DefaultLandingTab) -> MainTab {
        switch tab {
        case .rates:
            return .rates
        case .holdings:
            return .holdings
        case .realtime:
            return .realtime
        case .stats:
            return .stats
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
