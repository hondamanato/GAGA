import SwiftUI
import MapboxMaps
import FirebaseFirestore

struct TimelineView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TripStore.self) private var tripStore

    @State private var userCache: [String: AppUser] = [:]
    @State private var commentTrip: Trip?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("タイムライン")
                .sheet(item: $commentTrip) { trip in
                    CommentsView(trip: trip)
                }
                .refreshable {
                    tripStore.startListening(userId: authViewModel.firebaseUID)
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
            // Skeleton loading
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(0..<3, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: GAGATheme.cardRadius)
                            .fill(Color.gray.opacity(0.12))
                            .frame(height: 220)
                            .gagaSkeleton(true)
                    }
                }
                .padding(.horizontal, GAGATheme.spacingMD)
                .padding(.vertical, GAGATheme.spacingSM)
            }
        } else if tripStore.timeline.isEmpty {
            GAGAEmptyState(
                icon: "airplane",
                title: "旅行プランがまだありません",
                description: "旅行タブから最初のプランを作ってみましょう"
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 20) {
                    ForEach(Array(tripStore.timeline.enumerated()), id: \.element.id) { index, trip in
                        NavigationLink(value: trip) {
                            TimelineTripCard(
                                trip: trip,
                                user: userCache[trip.userId],
                                currentUserId: authViewModel.firebaseUID,
                                isLiked: tripStore.likedTripIds.contains(trip.id),
                                onLikeTap: {
                                    guard let uid = authViewModel.firebaseUID else { return }
                                    Task { await tripStore.toggleLike(trip: trip, userId: uid) }
                                },
                                onCommentTap: { commentTrip = trip }
                            )
                        }
                        .buttonStyle(.plain)
                        .gagaStagger(index: index)
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
                .padding(.horizontal, GAGATheme.spacingMD)
                .padding(.vertical, GAGATheme.spacingSM)
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
    let currentUserId: String?
    var isLiked: Bool = false
    var onLikeTap: (() -> Void)? = nil
    var onCommentTap: (() -> Void)? = nil

    @State private var showHeartOverlay = false
    @State private var showReportSheet = false
    @State private var showReportDone = false

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
        VStack(spacing: 0) {
            // Card image area
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
                        Text(trip.status.localizedName)
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

                // Double-tap heart overlay
                if showHeartOverlay {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 8)
                        .transition(.scale.combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: GAGATheme.cardRadius,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: GAGATheme.cardRadius
                )
            )
            .simultaneousGesture(
                TapGesture(count: 2).onEnded {
                    if !isLiked { onLikeTap?() }
                    withAnimation(GAGATheme.springBounce) { showHeartOverlay = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation { showHeartOverlay = false }
                    }
                }
            )

            // Reaction bar
            HStack(spacing: GAGATheme.spacingLG) {
                HeartBounceView(
                    isLiked: isLiked,
                    count: trip.likesCount,
                    action: { onLikeTap?() }
                )

                Button {
                    onCommentTap?()
                } label: {
                    HStack(spacing: GAGATheme.spacingXS) {
                        Image(systemName: "bubble.right")
                        if trip.commentsCount > 0 {
                            Text("\(trip.commentsCount)")
                                .font(GAGATheme.captionFont)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)

                Spacer()

                ShareLink(item: trip.title) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background {
                UnevenRoundedRectangle(
                    topLeadingRadius: 0,
                    bottomLeadingRadius: GAGATheme.cardRadius,
                    bottomTrailingRadius: GAGATheme.cardRadius,
                    topTrailingRadius: 0
                )
                .fill(.ultraThinMaterial)
            }
        }
        .gagaCard()
        .sensoryFeedback(.impact(flexibility: .soft), trigger: isLiked)
        .contextMenu {
            if currentUserId != trip.userId {
                Button(role: .destructive) {
                    showReportSheet = true
                } label: {
                    Label("報告する", systemImage: "exclamationmark.triangle")
                }
            }
        }
        .confirmationDialog("報告の理由を選択", isPresented: $showReportSheet, titleVisibility: .visible) {
            ForEach(ReportReason.allCases, id: \.self) { reason in
                Button(reason.rawValue) {
                    Task { await submitReport(reason: reason.rawValue, contentType: "trip", contentId: trip.id, contentOwnerId: trip.userId) }
                }
            }
            Button("キャンセル", role: .cancel) {}
        }
        .alert("報告を送信しました", isPresented: $showReportDone) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("ご報告ありがとうございます。内容を確認いたします。")
        }
    }

    private func submitReport(reason: String, contentType: String, contentId: String, contentOwnerId: String) async {
        guard let reporterId = currentUserId else { return }
        try? await Firestore.firestore().collection("reports").addDocument(data: [
            "reporterId": reporterId,
            "contentType": contentType,
            "contentId": contentId,
            "contentOwnerId": contentOwnerId,
            "reason": reason,
            "createdAt": FieldValue.serverTimestamp()
        ])
        showReportDone = true
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

private enum ReportReason: String, CaseIterable {
    case spam = "スパム"
    case inappropriate = "不適切な内容"
    case harassment = "ハラスメント"
    case other = "その他"
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
