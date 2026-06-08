import Foundation
import FirebaseFirestore

struct UserService {
    private var users: CollectionReference {
        Firestore.firestore().collection("users")
    }

    private var posts: CollectionReference {
        Firestore.firestore().collection("posts")
    }

    func fetchUser(id: String) async throws -> AppUser {
        let snapshot = try await users.document(id).getDocument()
        return try snapshot.data(as: AppUser.self)
    }

    func fetchUsers(ids: [String]) async throws -> [String: AppUser] {
        guard !ids.isEmpty else { return [:] }
        var result: [String: AppUser] = [:]
        for chunk in ids.chunked(into: 30) {
            let snapshot = try await users
                .whereField(FieldPath.documentID(), in: chunk)
                .getDocuments()
            for doc in snapshot.documents {
                if let user = try? doc.data(as: AppUser.self) {
                    result[user.id] = user
                }
            }
        }
        return result
    }

    func fetchPosts(by userId: String, limit: Int = 50) async throws -> [Post] {
        let snapshot = try await posts
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Post.self) }
    }

    func isFollowing(currentUserId: String, targetUserId: String) async throws -> Bool {
        let snapshot = try await users
            .document(currentUserId)
            .collection("following")
            .document(targetUserId)
            .getDocument()
        return snapshot.exists
    }

    func follow(currentUserId: String, targetUserId: String) async throws {
        guard currentUserId != targetUserId else { return }
        let db = Firestore.firestore()
        let batch = db.batch()
        let followingRef = users.document(currentUserId).collection("following").document(targetUserId)
        let followerRef = users.document(targetUserId).collection("followers").document(currentUserId)
        let currentRef = users.document(currentUserId)
        let targetRef = users.document(targetUserId)

        batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: followingRef)
        batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: followerRef)
        batch.updateData(["followingCount": FieldValue.increment(Int64(1))], forDocument: currentRef)
        batch.updateData(["followersCount": FieldValue.increment(Int64(1))], forDocument: targetRef)
        try await batch.commit()
    }

    func fetchFollowers(userId: String) async throws -> [AppUser] {
        let snapshot = try await users.document(userId)
            .collection("followers")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        let ids = snapshot.documents.map(\.documentID)
        guard !ids.isEmpty else { return [] }
        return try await fetchUsers(ids: ids)
            .values.sorted { ($0.displayName) < ($1.displayName) }
    }

    func fetchFollowing(userId: String) async throws -> [AppUser] {
        let snapshot = try await users.document(userId)
            .collection("following")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        let ids = snapshot.documents.map(\.documentID)
        guard !ids.isEmpty else { return [] }
        return try await fetchUsers(ids: ids)
            .values.sorted { ($0.displayName) < ($1.displayName) }
    }

    // MARK: - Block

    func blockUser(currentUserId: String, targetUserId: String) async throws {
        guard currentUserId != targetUserId else { return }
        let ref = users.document(currentUserId).collection("blocked").document(targetUserId)
        try await ref.setData(["createdAt": FieldValue.serverTimestamp()])
    }

    func unblockUser(currentUserId: String, targetUserId: String) async throws {
        let ref = users.document(currentUserId).collection("blocked").document(targetUserId)
        try await ref.delete()
    }

    func fetchBlockedUsers(userId: String) async throws -> [AppUser] {
        let snapshot = try await users.document(userId)
            .collection("blocked")
            .order(by: "createdAt", descending: true)
            .getDocuments()
        let ids = snapshot.documents.map(\.documentID)
        guard !ids.isEmpty else { return [] }
        return try await fetchUsers(ids: ids)
            .values.sorted { $0.displayName < $1.displayName }
    }

    func isBlocked(currentUserId: String, targetUserId: String) async throws -> Bool {
        let snapshot = try await users
            .document(currentUserId)
            .collection("blocked")
            .document(targetUserId)
            .getDocument()
        return snapshot.exists
    }

    func unfollow(currentUserId: String, targetUserId: String) async throws {
        guard currentUserId != targetUserId else { return }
        let db = Firestore.firestore()
        let batch = db.batch()
        let followingRef = users.document(currentUserId).collection("following").document(targetUserId)
        let followerRef = users.document(targetUserId).collection("followers").document(currentUserId)
        let currentRef = users.document(currentUserId)
        let targetRef = users.document(targetUserId)

        batch.deleteDocument(followingRef)
        batch.deleteDocument(followerRef)
        batch.updateData(["followingCount": FieldValue.increment(Int64(-1))], forDocument: currentRef)
        batch.updateData(["followersCount": FieldValue.increment(Int64(-1))], forDocument: targetRef)
        try await batch.commit()
    }

    // MARK: - Username

    private var usernames: CollectionReference {
        Firestore.firestore().collection("usernames")
    }

    func isUsernameAvailable(_ username: String) async throws -> Bool {
        let doc = try await usernames.document(username.lowercased()).getDocument()
        return !doc.exists
    }

    func fetchEmailByUsername(_ username: String) async throws -> String? {
        let lower = username.lowercased()
        let doc = try await usernames.document(lower).getDocument()
        guard let userId = doc.data()?["userId"] as? String else { return nil }
        let userDoc = try await users.document(userId).getDocument()
        return userDoc.data()?["email"] as? String
    }

    func setUsername(_ username: String, userId: String, oldUsername: String?) async throws {
        let lower = username.lowercased()
        let db = Firestore.firestore()
        let batch = db.batch()

        // 古いユーザーネームを削除
        if let old = oldUsername, !old.isEmpty {
            batch.deleteDocument(usernames.document(old.lowercased()))
        }

        // 新しいユーザーネームを予約
        batch.setData(["userId": userId], forDocument: usernames.document(lower))

        // ユーザードキュメントを更新
        batch.updateData(["username": lower], forDocument: users.document(userId))

        try await batch.commit()
    }

    // MARK: - Stickers

    func saveStickers(_ stickers: [PlacedSticker], userId: String) async throws {
        let encoded = try stickers.map { try Firestore.Encoder().encode($0) }
        try await users.document(userId).setData(["stickers": encoded], merge: true)
    }

    func fetchStickers(userId: String) async throws -> [PlacedSticker] {
        let doc = try await users.document(userId).getDocument()
        guard let array = doc.data()?["stickers"] as? [[String: Any]] else { return [] }
        return try array.map { try Firestore.Decoder().decode(PlacedSticker.self, from: $0) }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
