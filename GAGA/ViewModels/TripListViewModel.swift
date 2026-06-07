import SwiftUI
import FirebaseFirestore

@Observable
@MainActor
final class TripStore {
    // 自分のTrip
    var trips: [Trip] = []

    // タイムライン（全ユーザーのTrip）
    var timeline: [Trip] = []
    var likedTripIds: Set<String> = []
    var isLoading = false
    var isLoadingMore = false
    var hasMoreTrips = true
    var errorMessage: String?

    private let service = TripService()
    private var lastDocument: DocumentSnapshot?
    private var tripsListener: ListenerRegistration?
    private var timelineListener: ListenerRegistration?

    // MARK: - リアルタイムリスナー

    func startListening(userId: String?) {
        stopListening()
        guard let userId else {
            trips = []
            return
        }

        tripsListener = service.listenTrips(for: userId) { [weak self] trips in
            Task { @MainActor in
                self?.trips = trips
            }
        }

        isLoading = true
        timelineListener = service.listenTimeline { [weak self] trips, lastDoc in
            Task { @MainActor in
                guard let self else { return }
                self.timeline = trips
                self.lastDocument = lastDoc
                self.hasMoreTrips = trips.count >= 20
                self.isLoading = false

                let newIds = Set(trips.map(\.id)).subtracting(self.likedTripIds)
                if !newIds.isEmpty {
                    let liked = (try? await self.service.fetchLikedTripIds(
                        userId: userId,
                        tripIds: Array(newIds)
                    )) ?? []
                    self.likedTripIds.formUnion(liked)
                }
            }
        }
    }

    func stopListening() {
        tripsListener?.remove()
        tripsListener = nil
        timelineListener?.remove()
        timelineListener = nil
    }

    // MARK: - 自分のTrip（フォールバック）

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

    // MARK: - タイムライン

    func loadTimeline(currentUserId: String? = nil) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await service.fetchAllTrips()
            timeline = result.trips
            lastDocument = result.lastDoc
            hasMoreTrips = result.trips.count >= 20
            if let uid = currentUserId {
                likedTripIds = try await service.fetchLikedTripIds(
                    userId: uid,
                    tripIds: result.trips.map(\.id)
                )
            } else {
                likedTripIds = []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(currentUserId: String? = nil) async {
        guard hasMoreTrips, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let result = try await service.fetchAllTrips(after: lastDocument)
            timeline.append(contentsOf: result.trips)
            lastDocument = result.lastDoc
            hasMoreTrips = result.trips.count >= 20
            if let uid = currentUserId, !result.trips.isEmpty {
                let newLiked = try await service.fetchLikedTripIds(
                    userId: uid,
                    tripIds: result.trips.map(\.id)
                )
                likedTripIds.formUnion(newLiked)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - いいね

    func toggleLike(trip: Trip, userId: String) async {
        let tripId = trip.id
        let wasLiked = likedTripIds.contains(tripId)

        applyLikeLocally(tripId: tripId, liked: !wasLiked)

        do {
            if wasLiked {
                try await service.unlikeTrip(tripId: tripId, userId: userId)
            } else {
                try await service.likeTrip(tripId: tripId, userId: userId)
            }
        } catch {
            applyLikeLocally(tripId: tripId, liked: wasLiked)
            errorMessage = error.localizedDescription
        }
    }

    private func applyLikeLocally(tripId: String, liked: Bool) {
        if liked {
            likedTripIds.insert(tripId)
        } else {
            likedTripIds.remove(tripId)
        }
        if let idx = timeline.firstIndex(where: { $0.id == tripId }) {
            timeline[idx].likesCount += liked ? 1 : -1
            if timeline[idx].likesCount < 0 { timeline[idx].likesCount = 0 }
        }
    }

    // MARK: - コメント

    func addComment(to trip: Trip, userId: String, text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let comment = Comment(userId: userId, text: trimmed)
        try await service.addComment(tripId: trip.id, comment: comment)
        if let idx = timeline.firstIndex(where: { $0.id == trip.id }) {
            timeline[idx].commentsCount += 1
        }
    }

    func applyUpdate(_ trip: Trip) {
        if let idx = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[idx] = trip
        }
        if let idx = timeline.firstIndex(where: { $0.id == trip.id }) {
            timeline[idx] = trip
        }
    }

    func clear() {
        trips = []
        timeline = []
        likedTripIds = []
        lastDocument = nil
        hasMoreTrips = true
    }
}
