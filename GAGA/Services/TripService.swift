import Foundation
import FirebaseFirestore

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

    func delete(tripId: String) async throws {
        try await collection.document(tripId).delete()
    }
}
