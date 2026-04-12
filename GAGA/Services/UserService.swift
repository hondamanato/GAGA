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
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
