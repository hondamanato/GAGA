import SwiftUI

struct UserProfileView: View {
    let userId: String

    @Environment(AuthViewModel.self) private var authViewModel
    @State private var store = UserProfileStore()
    @State private var isBlocked = false
    @State private var showBlockConfirm = false

    private let userService = UserService()
    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private var isMe: Bool {
        authViewModel.firebaseUID == userId
    }

    private var allVisitedCountries: [String] {
        var countries: [String] = []
        for trip in store.trips {
            let origin = trip.origin.country.trimmingCharacters(in: .whitespaces)
            if !origin.isEmpty { countries.append(origin) }
            for dest in trip.destinations {
                let c = dest.country.trimmingCharacters(in: .whitespaces)
                if !c.isEmpty { countries.append(c) }
            }
        }
        return countries
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                statsRow
                if !isMe, authViewModel.firebaseUID != nil {
                    followButton
                }
                SuitcaseView(
                    visitedCountries: allVisitedCountries,
                    userId: userId,
                    readOnly: true
                )
                Divider()
                tripsGrid
            }
            .padding(.top, 8)
        }
        .navigationTitle(store.user?.displayName ?? "プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isMe, authViewModel.firebaseUID != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label(isBlocked ? "ブロック解除" : "ブロック", systemImage: isBlocked ? "person.badge.plus" : "person.fill.xmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .confirmationDialog(
            isBlocked ? "ブロックを解除しますか？" : "このユーザーをブロックしますか？",
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button(isBlocked ? "ブロック解除" : "ブロック", role: isBlocked ? nil : .destructive) {
                Task { await toggleBlock() }
            }
        } message: {
            Text(isBlocked ? "このユーザーのコンテンツが再び表示されます。" : "このユーザーの投稿が非表示になります。")
        }
        .task {
            await store.load(userId: userId, currentUserId: authViewModel.firebaseUID)
            if let uid = authViewModel.firebaseUID, uid != userId {
                isBlocked = (try? await userService.isBlocked(currentUserId: uid, targetUserId: userId)) ?? false
            }
        }
        .overlay {
            if store.isLoading && store.user == nil {
                ProgressView()
            }
        }
        .alert(
            "読み込みに失敗しました",
            isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { if !$0 { store.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            // Cover photo
            ZStack {
                if let urlStr = store.user?.coverPhotoURL, let url = URL(string: urlStr) {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        userCoverFallback
                    }
                } else {
                    userCoverFallback
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .clipped()

            GAGAAvatar(url: store.user?.avatarURL, size: 88)
                .background(Circle().fill(.background).padding(-4))
                .offset(y: -44)

            VStack(spacing: GAGATheme.spacingXS) {
                Text(store.user?.displayName ?? "")
                    .font(.title3)
                    .fontWeight(.semibold)
                if let bio = store.user?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .offset(y: -32)
        }
    }

    private var userCoverFallback: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [GAGATheme.deepNavy, GAGATheme.coral.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private var statsRow: some View {
        HStack {
            stat(value: store.trips.count, label: "旅行")
            Divider().frame(height: 32)
            NavigationLink {
                FollowListView(userId: userId, initialTab: .followers)
            } label: {
                stat(value: store.user?.followersCount ?? 0, label: "フォロワー")
            }
            .buttonStyle(.plain)
            Divider().frame(height: 32)
            NavigationLink {
                FollowListView(userId: userId, initialTab: .following)
            } label: {
                stat(value: store.user?.followingCount ?? 0, label: "フォロー中")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }

    private func stat(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var followButton: some View {
        Button {
            guard let uid = authViewModel.firebaseUID else { return }
            Task { await store.toggleFollow(currentUserId: uid) }
        } label: {
            Text(store.isFollowing ? "フォロー中" : "フォローする")
                .font(GAGATheme.headlineFont)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background {
                    if store.isFollowing {
                        Color.gray.opacity(0.2)
                    } else {
                        GAGATheme.accentGradient
                    }
                }
                .foregroundStyle(store.isFollowing ? Color.primary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: GAGATheme.buttonRadius))
                .animation(.spring(duration: 0.3), value: store.isFollowing)
        }
        .padding(.horizontal)
    }

    private var tripsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 12) {
            ForEach(store.trips) { trip in
                NavigationLink(value: trip) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let urlStr = trip.coverImageURL, let url = URL(string: urlStr) {
                            CachedAsyncImage(url: url) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                tripPlaceholder
                            }
                            .frame(height: 100)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            tripPlaceholder
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Text(trip.title)
                            .font(GAGATheme.captionFont)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                            .foregroundStyle(.primary)

                        Text("\(Self.dateFormatter.string(from: trip.departureDate)) - \(Self.dateFormatter.string(from: trip.returnDate))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal)
    }

    private func toggleBlock() async {
        guard let uid = authViewModel.firebaseUID else { return }
        do {
            if isBlocked {
                try await userService.unblockUser(currentUserId: uid, targetUserId: userId)
            } else {
                try await userService.blockUser(currentUserId: uid, targetUserId: userId)
            }
            isBlocked.toggle()
        } catch {
            store.errorMessage = error.localizedDescription
        }
    }

    private var tripPlaceholder: some View {
        Rectangle()
            .fill(GAGATheme.deepNavy.opacity(0.08))
            .frame(height: 100)
            .overlay {
                Image(systemName: "airplane")
                    .foregroundStyle(GAGATheme.coral.opacity(0.4))
            }
    }
}
