import SwiftUI
import MapboxMaps

struct UserProfileView: View {
    let userId: String

    @Environment(AuthViewModel.self) private var authViewModel
    @State private var store = UserProfileStore()
    @State private var isBlocked = false
    @State private var showBlockConfirm = false
    @State private var selectedTab: ProfileTab = .globe
    @State private var userTripStore = TripStore()
    @Namespace private var tabAnimation

    private let userService = UserService()

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

    private var visitedCountriesCount: Int {
        Set(allVisitedCountries).count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: GAGATheme.spacingSM) {
                statsRow

                VStack(alignment: .leading, spacing: 4) {
                    Text(store.user?.displayName ?? "")
                        .font(GAGATheme.headlineFont)
                    if let username = store.user?.username, !username.isEmpty {
                        Text("@\(username)")
                            .font(GAGATheme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                    if let bio = store.user?.bio, !bio.isEmpty {
                        Text(bio)
                            .font(GAGATheme.bodyFont)
                            .foregroundStyle(.secondary)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, GAGATheme.spacingMD)

                if !isMe, authViewModel.firebaseUID != nil {
                    followButton
                }

                if visitedCountriesCount > 0 {
                    visitedCountriesChips
                }

                tabBar
                tabContent
            }
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
                            Label {
                                Text(isBlocked ? LocalizedStringKey("ブロック解除") : LocalizedStringKey("ブロック"))
                            } icon: {
                                Image(systemName: isBlocked ? "person.badge.plus" : "person.fill.xmark")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .confirmationDialog(
            isBlocked ? LocalizedStringKey("ブロックを解除しますか？") : LocalizedStringKey("このユーザーをブロックしますか？"),
            isPresented: $showBlockConfirm,
            titleVisibility: .visible
        ) {
            Button(role: isBlocked ? nil : .destructive) {
                Task { await toggleBlock() }
            } label: {
                Text(isBlocked ? LocalizedStringKey("ブロック解除") : LocalizedStringKey("ブロック"))
            }
        } message: {
            Text(isBlocked ? LocalizedStringKey("このユーザーのコンテンツが再び表示されます。") : LocalizedStringKey("このユーザーの投稿が非表示になります。"))
        }
        .navigationDestination(for: Trip.self) { trip in
            TripDetailView(trip: trip)
        }
        .task {
            await store.load(userId: userId, currentUserId: authViewModel.firebaseUID)
            userTripStore.trips = store.trips
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

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 16) {
            GAGAAvatar(url: store.user?.avatarURL, size: 80)

            HStack(spacing: 0) {
                StatItem(value: "\(visitedCountriesCount)", label: "国")
                NavigationLink {
                    FollowListView(userId: userId, initialTab: .followers)
                } label: {
                    StatItem(value: "\(store.user?.followersCount ?? 0)", label: "フォロワー")
                }
                .buttonStyle(.plain)
                NavigationLink {
                    FollowListView(userId: userId, initialTab: .following)
                } label: {
                    StatItem(value: "\(store.user?.followingCount ?? 0)", label: "フォロー")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, GAGATheme.spacingMD)
    }

    // MARK: - Follow Button

    private var followButton: some View {
        Button {
            guard let uid = authViewModel.firebaseUID else { return }
            let wasFollowing = store.isFollowing
            Task {
                await store.toggleFollow(currentUserId: uid)
                // 自分の followingCount も即座に反映
                authViewModel.currentUser?.followingCount += wasFollowing ? -1 : 1
                if (authViewModel.currentUser?.followingCount ?? 0) < 0 {
                    authViewModel.currentUser?.followingCount = 0
                }
            }
        } label: {
            Text(store.isFollowing ? LocalizedStringKey("フォロー中") : LocalizedStringKey("フォローする"))
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

    // MARK: - Visited Countries Chips

    private var visitedCountriesChips: some View {
        let countries = Array(Set(allVisitedCountries)).sorted()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: GAGATheme.spacingSM) {
                ForEach(countries, id: \.self) { country in
                    Text("\(flagEmoji(for: country)) \(country)")
                        .font(GAGATheme.captionFont)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .stroke(GAGATheme.accentGradient, lineWidth: 1.5)
                        )
                }
            }
            .padding(.horizontal, GAGATheme.spacingMD)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        Text(tab.label)
                            .font(.caption2)
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        if selectedTab == tab {
                            Rectangle()
                                .fill(GAGATheme.accentGradient)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "userTabIndicator", in: tabAnimation)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .globe:
                GeometryReader { _ in
                    GlobeView()
                        .environment(userTripStore)
                }
                .frame(minHeight: 400)
            case .suitcase:
                SuitcaseView(
                    visitedCountries: allVisitedCountries,
                    userId: userId,
                    readOnly: true
                )
            case .list:
                tripListContent
            }
        }
        .id(selectedTab)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    @ViewBuilder
    private var tripListContent: some View {
        if store.trips.isEmpty {
            GAGAEmptyState(
                icon: "airplane",
                title: "旅行がまだありません",
                description: ""
            )
            .frame(minHeight: 200, maxHeight: 400)
        } else {
            LazyVStack(spacing: 16) {
                ForEach(store.trips) { trip in
                    NavigationLink(value: trip) {
                        ProfileTripCard(trip: trip)
                    }
                    .buttonStyle(.plain)
                    .contentShape(RoundedRectangle(cornerRadius: GAGATheme.cardRadius))
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Block

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
}
