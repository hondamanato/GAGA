import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore

@Observable
@MainActor
final class AuthViewModel {
    var currentUser: AppUser?
    var firebaseUID: String?
    var isLoading = false
    var errorMessage: String?

    var isLoggedIn: Bool { firebaseUID != nil }

    private var authListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    func start() {
        guard authListener == nil else { return }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let user {
                    self.firebaseUID = user.uid
                    await self.loadOrCreateUserDoc(uid: user.uid, fallbackName: user.displayName)
                } else {
                    self.firebaseUID = nil
                    self.currentUser = nil
                }
            }
        }
    }

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = AppleSignInNonce.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = AppleSignInNonce.sha256(nonce)
    }

    func signInWithApple(authorization: ASAuthorization) async {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            errorMessage = "Apple認証情報を取得できませんでした"
            return
        }
        guard let nonce = currentNonce else {
            errorMessage = "ログイン状態が不正です。もう一度お試しください"
            return
        }
        guard let identityTokenData = credential.identityToken,
              let idTokenString = String(data: identityTokenData, encoding: .utf8) else {
            errorMessage = "Apple IDトークンの取得に失敗しました"
            return
        }

        let fullName = credential.fullName
        let displayName = [fullName?.givenName, fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        isLoading = true
        defer { isLoading = false }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: fullName
        )

        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            await loadOrCreateUserDoc(
                uid: result.user.uid,
                fallbackName: displayName.isEmpty ? result.user.displayName : displayName
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInAnonymously() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Auth.auth().signInAnonymously()
            await loadOrCreateUserDoc(uid: result.user.uid, fallbackName: "ゲスト")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadOrCreateUserDoc(uid: String, fallbackName: String?) async {
        let ref = Firestore.firestore().collection("users").document(uid)
        do {
            let snapshot = try await ref.getDocument()
            if snapshot.exists {
                currentUser = try snapshot.data(as: AppUser.self)
            } else {
                let newUser = AppUser(
                    id: uid,
                    displayName: (fallbackName?.isEmpty == false ? fallbackName! : "Traveler")
                )
                try ref.setData(from: newUser)
                currentUser = newUser
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}
