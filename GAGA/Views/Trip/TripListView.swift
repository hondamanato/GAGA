import SwiftUI
import MapboxMaps

struct TripListView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TripStore.self) private var tripStore
    @State private var showCreateTrip = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("旅行")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateTrip = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(authViewModel.firebaseUID == nil)
                    }
                }
                .sheet(isPresented: $showCreateTrip) {
                    CreateTripView()
                        .environment(authViewModel)
                        .environment(tripStore)
                }
                .refreshable {
                    await tripStore.load(userId: authViewModel.firebaseUID)
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
        }
    }

    @ViewBuilder
    private var content: some View {
        if tripStore.isLoading && tripStore.trips.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tripStore.trips.isEmpty {
            GAGAEmptyState(
                icon: "airplane.departure",
                title: "旅行がまだありません",
                description: "右上の + から最初の旅行を作成しましょう",
                ctaTitle: "最初の旅行を作成",
                ctaAction: { showCreateTrip = true }
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(tripStore.trips) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            TripCard(trip: trip)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                guard let uid = authViewModel.firebaseUID else { return }
                                if let idx = tripStore.trips.firstIndex(where: { $0.id == trip.id }) {
                                    Task { await tripStore.delete(at: IndexSet(integer: idx), userId: uid) }
                                }
                            } label: {
                                Label("削除", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Trip Card

private struct TripCard: View {
    let trip: Trip

    private var routeText: String {
        let names = ([trip.origin] + trip.destinations).map { $0.name }
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
                .frame(height: 160)
                .clipped()

            // Dark gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

            // Content overlay
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

                HStack(spacing: 8) {
                    // Status badge
                    Text(trip.status.localizedName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(GAGATheme.tripStatusColor(trip.status).opacity(0.3), in: Capsule())
                        .foregroundStyle(.white)

                    // Dates
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("\(Self.dateFormatter.string(from: trip.departureDate)) - \(Self.dateFormatter.string(from: trip.returnDate))")
                            .font(GAGATheme.captionFont)
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
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

#Preview {
    TripListView()
        .environment(AuthViewModel())
        .environment(TripStore())
}
