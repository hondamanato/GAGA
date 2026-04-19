import Foundation
import FirebaseFirestore
import FirebaseStorage

struct TripService {
    private var collection: CollectionReference {
        Firestore.firestore().collection("trips")
    }

    func create(_ trip: Trip) async throws {
        try collection.document(trip.id).setData(from: trip)
    }

    func fetchTrips(for userId: String) async throws -> [Trip] {
        let snapshot = try await collection
            .whereField("userId", isEqualTo: userId)
            .order(by: "departureDate", descending: true)
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Trip.self) }
    }

    func update(_ trip: Trip) async throws {
        try collection.document(trip.id).setData(from: trip)
    }

    func delete(tripId: String) async throws {
        try await collection.document(tripId).delete()
    }

    // MARK: - Timeline

    func fetchAllTrips(limit: Int = 20, after lastDocument: DocumentSnapshot? = nil) async throws -> (trips: [Trip], lastDoc: DocumentSnapshot?) {
        var query = collection
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
        if let lastDocument {
            query = query.start(afterDocument: lastDocument)
        }
        let snapshot = try await query.getDocuments()
        let trips = try snapshot.documents.compactMap { try $0.data(as: Trip.self) }
        return (trips, snapshot.documents.last)
    }

    // MARK: - Cover Image

    func uploadCoverImage(_ data: Data, tripId: String) async throws -> String {
        let ref = Storage.storage().reference().child("trips/\(tripId)/cover.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        try await collection.document(tripId).updateData(["coverImageURL": url.absoluteString])
        return url.absoluteString
    }

    func uploadLocationCoverImage(_ data: Data, tripId: String, locationId: String) async throws -> String {
        let storageKey = locationId.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? locationId
        let ref = Storage.storage().reference().child("trips/\(tripId)/locations/\(storageKey).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    // MARK: - Likes

    func likeTrip(tripId: String, userId: String) async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        let likeRef = collection.document(tripId).collection("likes").document(userId)
        let tripRef = collection.document(tripId)
        batch.setData(["createdAt": FieldValue.serverTimestamp()], forDocument: likeRef)
        batch.updateData(["likesCount": FieldValue.increment(Int64(1))], forDocument: tripRef)
        try await batch.commit()
    }

    func unlikeTrip(tripId: String, userId: String) async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        let likeRef = collection.document(tripId).collection("likes").document(userId)
        let tripRef = collection.document(tripId)
        batch.deleteDocument(likeRef)
        batch.updateData(["likesCount": FieldValue.increment(Int64(-1))], forDocument: tripRef)
        try await batch.commit()
    }

    func isLiked(tripId: String, userId: String) async throws -> Bool {
        let snapshot = try await collection
            .document(tripId)
            .collection("likes")
            .document(userId)
            .getDocument()
        return snapshot.exists
    }

    func fetchLikedTripIds(userId: String, tripIds: [String]) async throws -> Set<String> {
        guard !tripIds.isEmpty else { return [] }
        var liked: Set<String> = []
        try await withThrowingTaskGroup(of: String?.self) { group in
            for tripId in tripIds {
                group.addTask {
                    let snap = try await collection
                        .document(tripId)
                        .collection("likes")
                        .document(userId)
                        .getDocument()
                    return snap.exists ? tripId : nil
                }
            }
            for try await result in group {
                if let id = result { liked.insert(id) }
            }
        }
        return liked
    }

    // MARK: - Comments

    func fetchComments(tripId: String) async throws -> [Comment] {
        let snapshot = try await collection
            .document(tripId)
            .collection("comments")
            .order(by: "createdAt")
            .getDocuments()
        return try snapshot.documents.compactMap { try $0.data(as: Comment.self) }
    }

    func addComment(tripId: String, comment: Comment) async throws {
        let db = Firestore.firestore()
        let batch = db.batch()
        let commentRef = collection.document(tripId).collection("comments").document(comment.id)
        let tripRef = collection.document(tripId)
        try batch.setData(from: comment, forDocument: commentRef)
        batch.updateData(["commentsCount": FieldValue.increment(Int64(1))], forDocument: tripRef)
        try await batch.commit()
    }
}
