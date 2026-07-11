import Foundation
import Combine
import Lottie
import Supabase
import SwiftUI
import UIKit

let statsFullscreenAnimationBucketName = "stats-fullscreen-animations"

struct StatsFullscreenAnimation: Identifiable, Equatable {
    let id: UUID
    let scope: String
    let userID: UUID?
    let name: String
    let triggerType: String
    let storagePath: String
    let contentType: String
    let fileType: String
    let isEnabled: Bool
    let createdAt: Date
    let signedURL: URL?
}

struct StatsFullscreenAnimationService {
    private struct AnimationRow: Codable {
        let id: UUID
        let scope: String
        let userId: UUID?
        let name: String
        let triggerType: String
        let storagePath: String
        let contentType: String
        let fileType: String
        let isEnabled: Bool
        let createdAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case scope
            case userId = "user_id"
            case name
            case triggerType = "trigger_type"
            case storagePath = "storage_path"
            case contentType = "content_type"
            case fileType = "file_type"
            case isEnabled = "is_enabled"
            case createdAt = "created_at"
        }
    }

    private let tableName = "stats_fullscreen_animations"

    func fetchAnimations(triggerType: String = "max_profit_day") async throws -> [StatsFullscreenAnimation] {
        let currentUserID = try await supabase.auth.session.user.id

        let rows: [AnimationRow] = try await supabase
            .from(tableName)
            .select()
            .eq("trigger_type", value: triggerType)
            .eq("is_enabled", value: true)
            .order("created_at", ascending: false)
            .execute()
            .value

        var animations: [StatsFullscreenAnimation] = []
        for row in rows {
            let signedURL = try? await supabase.storage
                .from(statsFullscreenAnimationBucketName)
                .createSignedURL(path: row.storagePath, expiresIn: 60 * 60 * 24 * 7)

            animations.append(
                StatsFullscreenAnimation(
                    id: row.id,
                    scope: row.scope,
                    userID: row.userId,
                    name: row.name,
                    triggerType: row.triggerType,
                    storagePath: row.storagePath,
                    contentType: row.contentType,
                    fileType: row.fileType,
                    isEnabled: row.isEnabled,
                    createdAt: row.createdAt,
                    signedURL: signedURL
                )
            )
        }

        return animations.sorted { lhs, rhs in
            let lhsPriority = lhs.userID == currentUserID ? 0 : 1
            let rhsPriority = rhs.userID == currentUserID ? 0 : 1
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.createdAt > rhs.createdAt
        }
    }
}

@MainActor
final class StatsFullscreenAnimationViewModel: ObservableObject {
    @Published private(set) var animations: [StatsFullscreenAnimation] = []
    @Published private(set) var birthdayHomeAnimations: [StatsFullscreenAnimation] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let service = StatsFullscreenAnimationService()

    var preferredAnimation: StatsFullscreenAnimation? {
        animations.first { $0.signedURL != nil }
    }

    var preferredBirthdayHomeAnimation: StatsFullscreenAnimation? {
        birthdayHomeAnimations.first { $0.signedURL != nil }
    }

    func loadAnimations() async {
        isLoading = true
        errorMessage = nil
        do {
            async let maxProfitAnimations = service.fetchAnimations(triggerType: "max_profit_day")
            async let birthdayAnimations = service.fetchAnimations(triggerType: "birthday_home")
            animations = try await maxProfitAnimations
            birthdayHomeAnimations = try await birthdayAnimations
            log("loadAnimations: loaded \(animations.count) max profit animations, \(birthdayHomeAnimations.count) birthday animations")
        } catch {
            errorMessage = error.localizedDescription
            animations = []
            birthdayHomeAnimations = []
            log("loadAnimations failed: \(error)")
        }
        isLoading = false
    }

    private func log(_ message: String) {
        print("[StatsFullscreen] \(message)")
    }
}

struct FullscreenDotLottieOverlay: View {
    let animation: StatsFullscreenAnimation
    let onPlaybackStarted: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let signedURL = animation.signedURL {
                DotLottiePlayerView(url: signedURL) {
                    onPlaybackStarted()
                } onFinished: {
                    onDismiss()
                } onError: { error in
                    print("[StatsFullscreen][Error] playback failed: \(error)")
                    onDismiss()
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityLabel(animation.name)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.42), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .padding(.trailing, 18)
            .accessibilityLabel("关闭全屏动画")
        }
    }
}

private struct DotLottiePlayerView: UIViewRepresentable {
    let url: URL
    let onStarted: () -> Void
    let onFinished: () -> Void
    let onError: (Error) -> Void

    func makeUIView(context: Context) -> LottieAnimationView {
        let animationView = LottieAnimationView(dotLottieUrl: url) { view, error in
            if let error {
                onError(error)
                return
            }

            view.contentMode = .scaleAspectFit
            view.loopMode = .playOnce
            onStarted()
            view.play { _ in
                onFinished()
            }
        }
        animationView.backgroundColor = .clear
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .playOnce
        return animationView
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        uiView.contentMode = .scaleAspectFit
    }
}
