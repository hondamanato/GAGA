import SwiftUI
import MapboxMaps

struct TimelineView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TripStore.self) private var tripStore

    @State private var userCache: [String: AppUser] = [:]

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("タイムライン")
                .refreshable {
                    await tripStore.loadTimeline(currentUserId: authViewModel.firebaseUID)
                    await loadUsers(for: tripStore.timeline)
                }
                .navigationDestination(for: String.self) { userId in
                    UserProfileView(userId: userId)
                }
                .navigationDestination(for: Trip.self) { trip in
                    TripDetailView(trip: trip)
                }
                .alert(
                    "読み込みに失敗しました",
                    isPresented: Binding(
                        get: { tripStore.errorMessage != nil },
                        set: { if !$0 { tripStore.errorMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) { tripStore.errorMessage = nil }
                } message: {
                    Text(tripStore.errorMessage ?? "")
                }
                .task {
                    if userCache.isEmpty, !tripStore.timeline.isEmpty {
                        await loadUsers(for: tripStore.timeline)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if tripStore.isLoading && tripStore.timeline.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tripStore.timeline.isEmpty {
            ContentUnavailableView(
                "旅行プランがまだありません",
                systemImage: "airplane",
                description: Text("旅行タブから最初のプランを作ってみましょう")
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(tripStore.timeline) { trip in
                        NavigationLink(value: trip) {
                            TimelineTripCard(
                                trip: trip,
                                user: userCache[trip.userId]
                            )
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if trip.id == tripStore.timeline.last?.id {
                                Task {
                                    await tripStore.loadMore(currentUserId: authViewModel.firebaseUID)
                                    await loadUsers(for: tripStore.timeline)
                                }
                            }
                        }
                    }

                    if tripStore.isLoadingMore {
                        ProgressView()
                            .padding()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    private func loadUsers(for trips: [Trip]) async {
        let ids = Set(trips.map(\.userId)).subtracting(userCache.keys)
        guard !ids.isEmpty else { return }
        if let fetched = try? await UserService().fetchUsers(ids: Array(ids)) {
            for (key, value) in fetched {
                userCache[key] = value
            }
        }
    }
}

// MARK: - Timeline Trip Card

private struct TimelineTripCard: View {
    let trip: Trip
    let user: AppUser?

    private var routeText: String {
        let names = ([trip.origin] + trip.destinations).map {
            flagEmoji(for: $0.country) + " " + $0.name
        }
        return names.joined(separator: " → ")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            cardBackground
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()

            // Dark gradient
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Top-left: user avatar
            VStack {
                HStack {
                    GAGAAvatar(url: user?.avatarURL, size: 32)
                        .shadow(color: .black.opacity(0.4), radius: 3)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(user?.displayName ?? "Traveler")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Text(trip.createdAt.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Text(trip.status.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(GAGATheme.tripStatusColor(trip.status).opacity(0.3), in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding(12)
                Spacer()
            }

            // Bottom: trip info
            VStack(alignment: .leading, spacing: 6) {
                Spacer()
                Text(trip.title)
                    .font(GAGATheme.headlineFont)
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.caption2)
                    Text(routeText)
                        .font(GAGATheme.captionFont)
                        .lineLimit(1)
                }
                .foregroundStyle(.white.opacity(0.85))

                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("\(Self.dateFormatter.string(from: trip.departureDate)) - \(Self.dateFormatter.string(from: trip.returnDate))")
                        .font(GAGATheme.captionFont)
                }
                .foregroundStyle(.white.opacity(0.7))
            }
            .padding(14)
        }
        .clipShape(RoundedRectangle(cornerRadius: GAGATheme.cardRadius))
    }

    @ViewBuilder
    private var cardBackground: some View {
        if let urlStr = trip.coverImageURL, let url = URL(string: urlStr) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackBackground
            }
        } else if let dest = trip.destinations.first,
                  let asset = LocationPostsView.heroAssets[dest.country] {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            fallbackBackground
        }
    }

    @ViewBuilder
    private var fallbackBackground: some View {
        if let dest = trip.destinations.first {
            let token = MapboxOptions.accessToken
            let urlStr = "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/\(dest.longitude),\(dest.latitude),6,0/800x400@2x?access_token=\(token)"
            CachedAsyncImage(url: URL(string: urlStr)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(GAGATheme.deepNavy.opacity(0.3))
            }
        } else {
            Rectangle().fill(GAGATheme.deepNavy.opacity(0.3))
                .overlay {
                    Image(systemName: "airplane")
                        .font(.largeTitle)
                        .foregroundStyle(GAGATheme.coral.opacity(0.4))
                }
        }
    }
}

// Make Trip Hashable for NavigationLink
extension Trip: Hashable {
    static func == (lhs: Trip, rhs: Trip) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview {
    TimelineView()
        .environment(AuthViewModel())
        .environment(TripStore())
}
