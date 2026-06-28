import AuthenticationServices
import SwiftUI

struct LoginView: View {
    @ObservedObject var authViewModel: AuthSessionViewModel
    @Environment(\.colorScheme) private var colorScheme

    private let accentColor = Color(red: 0.95, green: 0.52, blue: 0.16)
    private let deepInk = Color(red: 0.06, green: 0.09, blue: 0.16)

    var body: some View {
        ZStack {
            background

            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 42)

                    VStack(alignment: .leading, spacing: 28) {
                        brandHeader
                        valueStatement
                        trustRows
                    }
                    .frame(maxWidth: 420, alignment: .leading)

                    Spacer(minLength: 44)

                    VStack(spacing: 14) {
                        appleButton

                        if authViewModel.isSigningIn {
                            ProgressView()
                                .tint(accentColor)
                                .accessibilityLabel("正在登录")
                        }

                        if let message = authViewModel.errorMessage {
                            Text(message)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 360)
                                .accessibilityAddTraits(.isStaticText)
                        }
                    }
                    .frame(maxWidth: 420)

                    Spacer(minLength: 26)

                    Text("仅使用 Apple ID 登录")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)
                .padding(.vertical, 28)
                .frame(minHeight: UIScreen.main.bounds.height)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var background: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground)
                .ignoresSafeArea()

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            accentColor.opacity(colorScheme == .dark ? 0.24 : 0.18),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 220)
                .ignoresSafeArea(edges: .top)
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "chart.line.uptrend.xyaxis.circle.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(accentColor)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("众安助手")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)

                Text("统计资产变化，保留你的节奏")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var valueStatement: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("你的统计面板，只和你关联")
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .lineSpacing(3)
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.82)

            Text("登录后，上传记录会绑定到你的用户 ID，并在安全策略下同步。")
                .font(.body)
                .lineSpacing(4)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var trustRows: some View {
        VStack(alignment: .leading, spacing: 14) {
            LoginTrustRow(icon: "person.crop.circle.badge.checkmark", title: "Apple ID", detail: "只保留这一种登录方式")
            LoginTrustRow(icon: "lock.shield", title: "数据隔离", detail: "统计记录按用户 ID 分开")
            LoginTrustRow(icon: "arrow.triangle.2.circlepath", title: "自动恢复", detail: "下次启动直接进入应用")
        }
    }

    private var appleButton: some View {
        SignInWithAppleButton(.signIn) { request in
            authViewModel.configureAppleRequest(request)
        } onCompletion: { result in
            authViewModel.handleAppleCompletion(result)
        }
        .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
        .frame(height: 54)
        .clipShape(.rect(cornerRadius: 12))
        .allowsHitTesting(!authViewModel.isSigningIn)
        .opacity(authViewModel.isSigningIn ? 0.65 : 1)
        .accessibilityLabel("使用 Apple ID 登录")
    }
}

private struct LoginTrustRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(Color(red: 0.95, green: 0.52, blue: 0.16))
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(authViewModel: AuthSessionViewModel())
    }
}
