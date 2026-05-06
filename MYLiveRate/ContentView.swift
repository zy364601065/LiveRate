import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = ExchangeRateViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedHoldingPhotoItem: PhotosPickerItem?
    @AppStorage("myliverate.app_theme") private var appThemeRawValue: String = AppTheme.system.rawValue

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
        TabView {
            Tab("汇率", systemImage: "dollarsign.circle") {
                LiveRateTabView(viewModel: viewModel, selectedPhotoItem: $selectedPhotoItem)
            }

            Tab("持仓", systemImage: "briefcase") {
                HoldingsTabView(viewModel: viewModel, selectedHoldingPhotoItem: $selectedHoldingPhotoItem)
            }

            Tab("实时", systemImage: "chart.line.uptrend.xyaxis") {
                LiveStockTabView(viewModel: viewModel)
            }

            Tab("统计", systemImage: "calendar") {
                StatsDashboardView(viewModel: viewModel)
            }

            Tab("设置", systemImage: "gearshape") {
                SettingsTabView(viewModel: viewModel)
            }
        }
        .preferredColorScheme(preferredScheme)
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
