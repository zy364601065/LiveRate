import AuthenticationServices
import Combine
import CryptoKit
import Foundation
import os
import Security
import Supabase

@MainActor
final class AuthSessionViewModel: ObservableObject {
    enum SessionState: Equatable {
        case checking
        case signedOut
        case signedIn
    }

    @Published private(set) var sessionState: SessionState = .checking
    @Published private(set) var isSigningIn = false
    @Published var errorMessage: String?

    private var currentNonce: String?
    private let logger = Logger(subsystem: "zy.MYLiveRate", category: "Auth")

    func restoreSession() async {
        log("restoreSession: checking stored Supabase session")
        do {
            let session = try await supabase.auth.session
            sessionState = .signedIn
            errorMessage = nil
            log("restoreSession: signed in userID=\(session.user.id.uuidString), email=\(session.user.email ?? "nil"), isAnonymous=\(session.user.isAnonymous.description)")
        } catch {
            sessionState = .signedOut
            logError("restoreSession: no valid session", error: error)
        }
    }

    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        log("configureAppleRequest: scopes=[fullName,email], nonceLength=\(nonce.count), hashedNonceLength=\(request.nonce?.count ?? 0)")
    }

    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) {
        log("handleAppleCompletion: received Apple authorization result")
        Task {
            await signInWithApple(result)
        }
    }

    private func signInWithApple(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            log("signInWithApple: Apple authorization succeeded")

            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                log("signInWithApple: missing ASAuthorizationAppleIDCredential")
                errorMessage = "Apple ID 登录信息不完整，请再试一次。"
                return
            }

            log("signInWithApple: credential user=\(credential.user), email=\(credential.email ?? "nil"), hasFullName=\((credential.fullName != nil).description), realUserStatus=\(credential.realUserStatus.rawValue)")

            guard let identityToken = credential.identityToken else {
                log("signInWithApple: missing identityToken")
                errorMessage = "Apple ID 登录信息不完整，请再试一次。"
                return
            }

            guard let idToken = String(data: identityToken, encoding: .utf8) else {
                log("signInWithApple: identityToken is not UTF-8, bytes=\(identityToken.count)")
                errorMessage = "Apple ID 登录信息不完整，请再试一次。"
                return
            }

            guard let nonce = currentNonce else {
                log("signInWithApple: missing stored nonce")
                errorMessage = "Apple ID 登录信息不完整，请再试一次。"
                return
            }

            log("signInWithApple: idTokenLength=\(idToken.count), nonceLength=\(nonce.count)")
            logJWTMetadata(idToken)

            isSigningIn = true
            defer {
                isSigningIn = false
                currentNonce = nil
                log("signInWithApple: finished sign-in attempt")
            }

            do {
                log("signInWithApple: exchanging Apple id token with Supabase")
                let session = try await supabase.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: idToken,
                        nonce: nonce
                    )
                )
                sessionState = .signedIn
                errorMessage = nil
                log("signInWithApple: Supabase sign-in succeeded userID=\(session.user.id.uuidString), email=\(session.user.email ?? "nil"), isAnonymous=\(session.user.isAnonymous.description)")
            } catch {
                errorMessage = "Apple ID 登录失败，请稍后重试。"
                sessionState = .signedOut
                logError("signInWithApple: Supabase sign-in failed", error: error)
            }

        case .failure(let error):
            currentNonce = nil
            if let authorizationError = error as? ASAuthorizationError,
               authorizationError.code == .canceled {
                errorMessage = nil
                log("signInWithApple: Apple authorization canceled by user")
            } else {
                errorMessage = "Apple ID 登录未完成，请再试一次。"
                logError("signInWithApple: Apple authorization failed", error: error)
            }
            sessionState = .signedOut
        }
    }

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess {
                fatalError("Unable to generate secure random bytes.")
            }

            if random < charset.count {
                result.append(charset[Int(random)])
                remainingLength -= 1
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.map { String(format: "%02x", $0) }.joined()
    }

    private func log(_ message: String) {
        logger.info("\(message, privacy: .public)")
        print("[Auth] \(message)")
    }

    private func logError(_ message: String, error: Error) {
        let nsError = error as NSError
        let detail = "\(message): domain=\(nsError.domain), code=\(nsError.code), localized=\(nsError.localizedDescription), debug=\(String(describing: error))"
        logger.error("\(detail, privacy: .public)")
        print("[Auth][Error] \(detail)")
    }

    private func logJWTMetadata(_ token: String) {
        let parts = token.split(separator: ".")
        log("idToken: jwtParts=\(parts.count)")

        guard parts.count >= 2 else {
            return
        }

        logJWTPart(String(parts[0]), label: "header")
        logJWTPart(String(parts[1]), label: "payload")
    }

    private func logJWTPart(_ encodedPart: String, label: String) {
        guard let data = base64URLDecodedData(encodedPart),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            log("idToken \(label): unable to decode")
            return
        }

        let allowedKeys = ["alg", "kid", "typ", "iss", "aud", "exp", "iat", "sub", "nonce", "email", "email_verified", "is_private_email"]
        let metadata = allowedKeys.reduce(into: [String: String]()) { result, key in
            if let value = object[key] {
                result[key] = String(describing: value)
            }
        }
        log("idToken \(label): \(metadata)")
    }

    private func base64URLDecodedData(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let paddingLength = 4 - base64.count % 4
        if paddingLength < 4 {
            base64.append(String(repeating: "=", count: paddingLength))
        }

        return Data(base64Encoded: base64)
    }
}
