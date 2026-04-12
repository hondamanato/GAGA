import Foundation
import FirebaseFirestore
import FirebaseStorage

struct PostService {
    private var collection: CollectionReference {
        Firestore.firestore().collection("posts")
    }

    func uploadImage(_ data: Data, userId: String, postId: String) async throws -> String {
        let ref = Storage.storage().reference().child("posts/\(userId)/\(postId).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    func create(_ post: Post) async throws {
        try collection.document(post.id).setData(from: post)
    }

    func fetchTimeline(limit: Int = 50) async throws -> [Post] {
        let snapshot = try await collection
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Post.self) }
    }

    func delete(post: Post) async throws {
        try await collection.document(post.id).delete()
        let ref = Storage.storage().reference().child("posts/\(post.userId)/\(post.id).jpg")
        try? await ref.delete()
    }

    // MARK: - Likes

    func likePost(postId: String, userId: String) async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        let likeRef = collection.document(postId).collection("likes").document(userId)
        let postRef = collection.document(postId)
        batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: likeRef)
        batch.updateData(["likesCount": FieldValue.increment(Int64(1))], forDocument: postRef)
        try await batch.commit()
    }

    func unlikePost(postId: String, userId: String) async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        let likeRef = collection.document(postId).collection("likes").document(userId)
        let postRef = collection.document(postId)
        batch.deleteDocument(likeRef)
        batch.updateData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: postRef)
        try await batch.commit()
    }

    func isLiked(postId: String, userId: String) async throws -> Bool {
        let snapshot = try await collection
            .document(postId)
            .collection("likes")
            .document(userId)
            .getDocument()
        return snapshot.exists
    }

    func fetchLikedPostIds(userId: String, postIds: [String]) async throws -> Set<String> {
        guard !postIds.isEmpty else { return [] }
        var liked: Set<String> = []
        // 並列化: 30 件ごとに chunk して each post の likes/{uid} を確認
        // Firestore には collection group で "自分がいいねした post 一覧" を一発取りできないため、
        // post ごとに doc 存在確認を async let で並列化する
        try await withThrowingTaskGroup(of: String?.self) { group in
            for postId in postIds {
                group.addTask {
                    let snap = try await collection
                        .document(postId)
                        .collection("likes")
                        .document(userId)
                        .getDocument()
                    return snap.exists ? postId : nil
                }
            }
            for try await result in group {
                if let id = result { liked.insert(id) }
            }
        }
        return liked
    }

    // MARK: - Comments

    func fetchComments(postId: String) async throws -> [Comment] {
        let snapshot = try await collection
            .document(postId)
            .collection("comments")
            .order(by: "createdAt")
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Comment.self) }
    }

    func addComment(postId: String, comment: Comment) async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        let commentRef = collection.document(postId).collection("comments").document(comment.id)
        let postRef = collection.document(postId)
        try batch.setData(from: comment, forDocument: commentRef)
        batch.updateData(["commentsCount": FieldValue.increment(Int64(1))], forDocument: postRef)
        try await batch.commit()
    }
}
