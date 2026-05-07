import Foundation

struct AppUser: Identifiable, Codable {
    var id: String
    var displayName: String
    var avatarURL: String?
    var coverPhotoURL: String?
    var bio: String
    var followersCount: Int
    var followingCount: Int
    var createdAt: Date

    init(id: String, displayName: String, avatarURL: String? = nil, coverPhotoURL: String? = nil, bio: String = "", followersCount: Int = 0, followingCount: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.coverPhotoURL = coverPhotoURL
        self.bio = bio
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.createdAt = createdAt
    }
}
