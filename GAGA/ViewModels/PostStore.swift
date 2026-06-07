import SwiftUI

@Observable
@MainActor
final class PostStore {
    var tripPosts: [String: [Post]] = [:]
    var isLoading = false
    var errorMessage: String?

    private let service = PostService()

    func loadPosts(forTripId tripId: String) async {
        do {
            let posts = try await service.fetchPosts(tripId: tripId)
            tripPosts[tripId] = posts
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(
        imageData: Data,
        userId: String,
        tripId: String,
        location: Location,
        caption: String,
        createdAt: Date = .now
    ) async throws {
        let postId = UUID().uuidString
        let imageURL = try await service.uploadImage(imageData, userId: userId, postId: postId)
        let post = Post(
            id: postId,
            userId: userId,
            tripId: tripId,
            imageURL: imageURL,
            location: location,
            caption: caption,
            createdAt: createdAt
        )
        try await service.create(post)
        await loadPosts(forTripId: tripId)
    }

    func update(_ post: Post) async throws {
        try await service.update(post)
        if var posts = tripPosts[post.tripId],
           let idx = posts.firstIndex(where: { $0.id == post.id }) {
            posts[idx] = post
            tripPosts[post.tripId] = posts
        }
    }

    func delete(_ post: Post) async throws {
        try await service.delete(post: post)
        tripPosts[post.tripId]?.removeAll { $0.id == post.id }
    }

    func clear() {
        tripPosts = [:]
    }
}
