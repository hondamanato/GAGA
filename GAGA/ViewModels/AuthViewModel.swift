import SwiftUI
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@Observable
@MainActor
final class AuthViewModel {
    var currentUser: AppUser?
    var firebaseUID: String?
    var isLoading = false
    var errorMessage: String?

    var isLoggedIn: Bool { firebaseUID != nil }

    /// username 未設定の場合のみ true
    var needsProfileSetup: Bool {
        guard let user = currentUser else { return false }
        return user.username.isEmpty
    }

    private var authListener: AuthStateDidChangeListenerHandle?
    private var currentNonce: String?

    func start() {
        guard authListener == nil else { return }
        authListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let user {
                    // 匿名アカウントはサポート終了 — 自動ログアウト
                    if user.isAnonymous {
                        try? Auth.auth().signOut()
                        return
                    }
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
            errorMessage = String(localized: "Apple認証情報を取得できませんでした")
            return
        }
        guard let nonce = currentNonce else {
            errorMessage = String(localized: "ログイン状態が不正です。もう一度お試しください")
            return
        }
        guard let identityTokenData = credential.identityToken,
              let idTokenString = String(data: identityTokenData, encoding: .utf8) else {
            errorMessage = String(localized: "Apple IDトークンの取得に失敗しました")
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

    func signUpWithEmail(email: String, password: String, displayName: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            await loadOrCreateUserDoc(uid: result.user.uid, fallbackName: displayName)
            // リスナーが先に "Traveler" で作成した場合に上書き
            if let uid = firebaseUID, currentUser?.displayName != displayName, !displayName.isEmpty {
                let ref = Firestore.firestore().collection("users").document(uid)
                try await ref.updateData(["displayName": displayName])
                currentUser?.displayName = displayName
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithEmail(email: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await loadOrCreateUserDoc(uid: result.user.uid, fallbackName: result.user.displayName)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signInWithUsername(username: String, password: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let email = try await UserService().fetchEmailByUsername(username) else {
                errorMessage = String(localized: "ユーザーネームが見つかりません")
                return
            }
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            await loadOrCreateUserDoc(uid: result.user.uid, fallbackName: result.user.displayName)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(displayName: String, bio: String, username: String? = nil) async {
        guard let uid = firebaseUID else { return }
        errorMessage = nil
        do {
            // 表示名・自己紹介を先に保存
            let ref = Firestore.firestore().collection("users").document(uid)
            try await ref.updateData([
                "displayName": displayName,
                "displayNameLower": displayName.lowercased(),
                "bio": bio,
            ])
            currentUser?.displayName = displayName
            currentUser?.displayNameLower = displayName.lowercased()
            currentUser?.bio = bio

            // ユーザーネーム変更がある場合
            if let username, username != currentUser?.username {
                let service = UserService()
                let available = try await service.isUsernameAvailable(username)
                guard available else {
                    errorMessage = String(localized: "このユーザーネームは既に使われています")
                    return
                }
                try await service.setUsername(username, userId: uid, oldUsername: currentUser?.username)
                currentUser?.username = username.lowercased()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uploadAvatar(imageData: Data) async {
        guard let uid = firebaseUID else { return }
        let ref = Storage.storage().reference().child("users/\(uid)/avatar.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        do {
            _ = try await ref.putDataAsync(imageData, metadata: metadata)
            let url = try await ref.downloadURL()
            let userRef = Firestore.firestore().collection("users").document(uid)
            try await userRef.updateData(["avatarURL": url.absoluteString])
            currentUser?.avatarURL = url.absoluteString
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

    // MARK: - アカウント削除

    /// アカウントと関連データをすべて削除する
    func deleteAccount() async {
        guard let user = Auth.auth().currentUser,
              let uid = firebaseUID else {
            errorMessage = String(localized: "ログインしていません")
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Apple Sign In で再認証（最近のログインが必要）
            if user.providerData.contains(where: { $0.providerID == "apple.com" }) {
                try await reauthenticateWithApple()
            }

            let db = Firestore.firestore()
            let storage = Storage.storage()

            // ユーザーネームの予約を解放
            if let username = currentUser?.username, !username.isEmpty {
                try? await db.collection("usernames").document(username.lowercased()).delete()
            }

            // サブコレクション削除 (following, followers, blocked)
            for sub in ["following", "followers", "blocked"] {
                let docs = try await db.collection("users").document(uid).collection(sub).getDocuments()
                for doc in docs.documents {
                    try? await doc.reference.delete()
                }
            }

            // ユーザーの trips 削除
            let trips = try await db.collection("trips").whereField("userId", isEqualTo: uid).getDocuments()
            for doc in trips.documents {
                // trips のコメントサブコレクション削除
                let comments = try await doc.reference.collection("comments").getDocuments()
                for comment in comments.documents {
                    try? await comment.reference.delete()
                }
                try? await doc.reference.delete()
            }

            // ユーザーの posts 削除
            let posts = try await db.collection("posts").whereField("userId", isEqualTo: uid).getDocuments()
            for doc in posts.documents {
                try? await doc.reference.delete()
            }

            // Storage のユーザー画像を削除
            let storageRef = storage.reference().child("users/\(uid)")
            if let items = try? await storageRef.listAll() {
                for item in items.items {
                    try? await item.delete()
                }
            }
            let tripsStorageRef = storage.reference().child("trips")
            for doc in trips.documents {
                let tripRef = tripsStorageRef.child(doc.documentID)
                if let items = try? await tripRef.listAll() {
                    for item in items.items {
                        try? await item.delete()
                    }
                }
            }

            // ユーザードキュメント削除
            try await db.collection("users").document(uid).delete()

            // Firebase Auth アカウント削除
            try await user.delete()

        } catch {
            errorMessage = String(localized: "アカウント削除に失敗しました: \(error.localizedDescription)")
        }
    }

    /// Apple Sign In で再認証
    private func reauthenticateWithApple() async throws {
        let nonce = AppleSignInNonce.randomNonceString()
        let hashedNonce = AppleSignInNonce.sha256(nonce)

        let result = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = [.fullName, .email]
            request.nonce = hashedNonce

            let delegate = AppleSignInDelegate(continuation: continuation)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.performRequests()

            // delegate を保持
            objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
        }

        guard let appleCredential = result.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = appleCredential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw NSError(domain: "AuthViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "Apple再認証に失敗しました"])
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: nil
        )
        try await Auth.auth().currentUser?.reauthenticate(with: credential)
    }

    var isDeletingAccount = false

    /// Firestore からユーザー情報を再取得して currentUser を更新
    func reloadCurrentUser() async {
        guard let uid = firebaseUID else { return }
        let ref = Firestore.firestore().collection("users").document(uid)
        do {
            let snapshot = try await ref.getDocument()
            if snapshot.exists {
                currentUser = try snapshot.data(as: AppUser.self)
            }
        } catch {
            // サイレントに失敗
        }
    }

    private func loadOrCreateUserDoc(uid: String, fallbackName: String?) async {
        let ref = Firestore.firestore().collection("users").document(uid)
        do {
            let snapshot = try await ref.getDocument()
            if snapshot.exists {
                currentUser = try snapshot.data(as: AppUser.self)
                // メールアドレスが未保存の場合は保存
                if let email = Auth.auth().currentUser?.email,
                   snapshot.data()?["email"] == nil {
                    try? await ref.updateData(["email": email])
                }
            } else {
                let newUser = AppUser(
                    id: uid,
                    displayName: (fallbackName?.isEmpty == false ? fallbackName! : "Traveler")
                )
                try ref.setData(from: newUser)
                // メールアドレスを別フィールドとして保存
                if let email = Auth.auth().currentUser?.email {
                    try? await ref.updateData(["email": email])
                }
                currentUser = newUser
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Apple Sign In Delegate for re-authentication

private class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    private let continuation: CheckedContinuation<ASAuthorization, Error>
    private var hasResumed = false

    init(continuation: CheckedContinuation<ASAuthorization, Error>) {
        self.continuation = continuation
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard !hasResumed else { return }
        hasResumed = true
        continuation.resume(returning: authorization)
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        guard !hasResumed else { return }
        hasResumed = true
        continuation.resume(throwing: error)
    }
}
