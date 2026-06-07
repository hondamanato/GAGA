import Foundation

struct AppUser: Identifiable, Codable {
    var id: String
    var username: String
    var displayName: String
    var displayNameLower: String
    var avatarURL: String?
    var coverPhotoURL: String?
    var bio: String
    var followersCount: Int
    var followingCount: Int
    var createdAt: Date

    init(id: String, username: String = "", displayName: String, avatarURL: String? = nil, coverPhotoURL: String? = nil, bio: String = "", followersCount: Int = 0, followingCount: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.displayNameLower = displayName.lowercased()
        self.avatarURL = avatarURL
        self.coverPhotoURL = coverPhotoURL
        self.bio = bio
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        username = try c.decodeIfPresent(String.self, forKey: .username) ?? ""
        displayName = try c.decode(String.self, forKey: .displayName)
        displayNameLower = try c.decodeIfPresent(String.self, forKey: .displayNameLower) ?? displayName.lowercased()
        avatarURL = try c.decodeIfPresent(String.self, forKey: .avatarURL)
        coverPhotoURL = try c.decodeIfPresent(String.self, forKey: .coverPhotoURL)
        bio = try c.decodeIfPresent(String.self, forKey: .bio) ?? ""
        followersCount = try c.decodeIfPresent(Int.self, forKey: .followersCount) ?? 0
        followingCount = try c.decodeIfPresent(Int.self, forKey: .followingCount) ?? 0
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
    }
}
