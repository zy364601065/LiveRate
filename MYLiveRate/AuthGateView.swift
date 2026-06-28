import SwiftUI

struct AuthGateView: View {
    @StateObject private var authViewModel = AuthSessionViewModel()

    var body: some View {
        Group {
            switch authViewModel.sessionState {
            case .checking:
                AuthCheckingView()
            case .signedOut:
                LoginView(authViewModel: authViewModel)
            case .signedIn:
                ContentView()
            }
        }
        .animation(.easeInOut(duration: 0.22), value: authViewModel.sessionState)
        .task {
            await authViewModel.restoreSession()
        }
    }
}

private struct AuthCheckingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(Color(red: 0.95, green: 0.52, blue: 0.16))
                    .accessibilityHidden(true)

                ProgressView()
                    .tint(Color(red: 0.95, green: 0.52, blue: 0.16))
                    .accessibilityLabel("正在检查登录状态")
            }
        }
    }
}
