import SwiftUI

@Observable
@MainActor
final class TripStore {
    var trips: [Trip] = []
    var isLoading = false
    var errorMessage: String?

    private let service = TripService()

    func load(userId: String?) async {
        guard let userId else {
            trips = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            trips = try await service.fetchTrips(for: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(at offsets: IndexSet, userId: String) async {
        let targets = offsets.map { trips[$0] }
        do {
            for trip in targets {
                try await service.delete(tripId: trip.id)
            }
            await load(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clear() {
        trips = []
    }
}
