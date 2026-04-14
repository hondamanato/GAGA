import SwiftUI
import FirebaseFirestore

@Observable
@MainActor
final class PostStore {
    var timeline: [Post] = []
    var tripPosts: [String: [Post]] = [:]
    var likedPostIds: Set<String> = []
    var isLoading = false
    var isLoadingMore = false
    var hasMorePosts = true
    var errorMessage: String?

    private let service = PostService()
    private var lastDocument: DocumentSnapshot?

    func loadTimeline(currentUserId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await service.fetchTimeline()
            timeline = result.posts
            lastDocument = result.lastDoc
            hasMorePosts = result.posts.count >= 20
            if let uid = currentUserId {
                likedPostIds = try await service.fetchLikedPostIds(
                    userId: uid,
                    postIds: result.posts.map(\.id)
                )
            } else {
                likedPostIds = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(currentUserId: String? = nil) async {
        guard hasMorePosts, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await service.fetchTimeline(after: lastDocument)
            timeline.append(contentsOf: result.posts)
            lastDocument = result.lastDoc
            hasMorePosts = result.posts.count >= 20
            if let uid = currentUserId, !result.posts.isEmpty {
                let newLiked = try await service.fetchLikedPostIds(
                    userId: uid,
                    postIds: result.posts.map(\.id)
                )
                likedPostIds.formUnion(newLiked)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func create(
        imageData: Data,
        userId: String,
        tripId: String?,
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
        await loadTimeline(currentUserId: userId)
    }

    func update(_ post: Post) async throws {
        try await service.update(post)
        if let idx = timeline.firstIndex(where: { $0.id == post.id }) {
            timeline[idx] = post
        }
    }

    func delete(_ post: Post) async throws {
        try await service.delete(post: post)
        timeline.removeAll { $0.id == post.id }
    }

    func toggleLike(post: Post, userId: String) async {
        let postId = post.id
        let wasLiked = likedPostIds.contains(postId)

        // 楽観更新
        applyLikeLocally(postId: postId, liked: !wasLiked)

        do {
            if wasLiked {
                try await service.unlikePost(postId: postId, userId: userId)
            } else {
                try await service.likePost(postId: postId, userId: userId)
            }
        } catch {
            // ロールバック
            applyLikeLocally(postId: postId, liked: wasLiked)
            errorMessage = error.localizedDescription
        }
    }

    private func applyLikeLocally(postId: String, liked: Bool) {
        if liked {
            likedPostIds.insert(postId)
        } else {
            likedPostIds.remove(postId)
        }
        if let idx = timeline.firstIndex(where: { $0.id == postId }) {
            timeline[idx].likesCount += liked ? 1 : -1
            if timeline[idx].likesCount < 0 { timeline[idx].likesCount = 0 }
        }
    }

    func addComment(to post: Post, userId: String, text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let comment = Comment(userId: userId, text: trimmed)
        try await service.addComment(postId: post.id, comment: comment)
        if let idx = timeline.firstIndex(where: { $0.id == post.id }) {
            timeline[idx].commentsCount += 1
        }
    }

    func loadPosts(forTripId tripId: String) async {
        do {
            let posts = try await service.fetchPosts(tripId: tripId)
            tripPosts[tripId] = posts
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        timeline = []
        tripPosts = [:]
        likedPostIds = []
        lastDocument = nil
        hasMorePosts = true
    }
}
