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

    func fetchPosts(tripId: String) async throws -> [Post] {
        let snapshot = try await collection
            .whereField("tripId", isEqualTo: tripId)
            .order(by: "createdAt")
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Post.self) }
    }

    func update(_ post: Post) async throws {
        try collection.document(post.id).setData(from: post)
    }

    func delete(post: Post) async throws {
        try await collection.document(post.id).delete()
        let ref = Storage.storage().reference().child("posts/\(post.userId)/\(post.id).jpg")
        do {
            try await ref.delete()
        } catch {
            // silently ignore deletion failure
        }
    }

    func fetchPosts(locationName: String, limit: Int = 30) async throws -> [Post] {
        let snapshot = try await collection
            .whereField("location.name", isEqualTo: locationName)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Post.self) }
    }

    func fetchPosts(country: String, limit: Int = 30) async throws -> [Post] {
        let snapshot = try await collection
            .whereField("location.country", isEqualTo: country)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Post.self) }
    }
}
