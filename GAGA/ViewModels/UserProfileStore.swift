import SwiftUI

@Observable
@MainActor
final class UserProfileStore {
    var user: AppUser?
    var trips: [Trip] = []
    var isFollowing = false
    var isLoading = false
    var errorMessage: String?

    private let userService = UserService()
    private let tripService = TripService()

    func load(userId: String, currentUserId: String?) async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let userFetch = userService.fetchUser(id: userId)
            async let tripsFetch = tripService.fetchTrips(for: userId)
            user = try await userFetch
            trips = try await tripsFetch

            if let currentUserId, currentUserId != userId {
                isFollowing = (try? await userService.isFollowing(
                    currentUserId: currentUserId,
                    targetUserId: userId
                )) ?? false
            } else {
                isFollowing = false
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleFollow(currentUserId: String) async {
        guard let targetId = user?.id, targetId != currentUserId else { return }
        let wasFollowing = isFollowing

        isFollowing.toggle()
        if var u = user {
            u.followersCount += wasFollowing ? -1 : 1
            if u.followersCount < 0 { u.followersCount = 0 }
            user = u
        }

        do {
            if wasFollowing {
                try await userService.unfollow(currentUserId: currentUserId, targetUserId: targetId)
            } else {
                try await userService.follow(currentUserId: currentUserId, targetUserId: targetId)
            }
        } catch {
            isFollowing = wasFollowing
            if var u = user {
                u.followersCount += wasFollowing ? 1 : -1
                if u.followersCount < 0 { u.followersCount = 0 }
                user = u
            }
            errorMessage = error.localizedDescription
        }
    }
}
