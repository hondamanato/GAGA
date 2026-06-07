import Foundation
import FirebaseFirestore

struct SearchService {
    private var users: CollectionReference {
        Firestore.firestore().collection("users")
    }

    private var posts: CollectionReference {
        Firestore.firestore().collection("posts")
    }

    func searchUsers(prefix: String, limit: Int = 15) async throws -> [AppUser] {
        let lower = prefix.lowercased()
        let end = lower + "\u{f8ff}"
        let snapshot = try await users
            .whereField("displayNameLower", isGreaterThanOrEqualTo: lower)
            .whereField("displayNameLower", isLessThan: end)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: AppUser.self) }
    }

    func searchUsersByUsername(prefix: String, limit: Int = 15) async throws -> [AppUser] {
        let lower = prefix.lowercased()
        let end = lower + "\u{f8ff}"
        let snapshot = try await users
            .whereField("username", isGreaterThanOrEqualTo: lower)
            .whereField("username", isLessThan: end)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: AppUser.self) }
    }

    func searchPostsByCountry(prefix: String, limit: Int = 20) async throws -> [Post] {
        let end = prefix + "\u{f8ff}"
        let snapshot = try await posts
            .whereField("location.country", isGreaterThanOrEqualTo: prefix)
            .whereField("location.country", isLessThan: end)
            .order(by: "location.country")
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Post.self) }
    }

    func searchPostsByLocationName(prefix: String, limit: Int = 20) async throws -> [Post] {
        let end = prefix + "\u{f8ff}"
        let snapshot = try await posts
            .whereField("location.name", isGreaterThanOrEqualTo: prefix)
            .whereField("location.name", isLessThan: end)
            .order(by: "location.name")
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Post.self) }
    }
}
