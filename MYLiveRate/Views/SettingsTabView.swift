import SwiftUI

private let appThemeStorageKey = "myliverate.app_theme"

struct SettingsTabView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("通用设置") {
                    GeneralSettingsView()
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
            Section("外观") {
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
