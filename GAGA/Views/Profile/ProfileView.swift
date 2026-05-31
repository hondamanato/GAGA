import SwiftUI
import MapboxMaps

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TripStore.self) private var tripStore

    @State private var selectedTab: ProfileTab = .globe
    @Namespace private var tabAnimation

    private var user: AppUser? { authViewModel.currentUser }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: GAGATheme.spacingSM) {
                    statsRow
                    if visitedCountriesCount > 0 {
                        visitedCountriesChips
                    }
                    tabBar
                    tabContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text(user?.displayName ?? "Traveler")
                        .font(GAGATheme.headlineFont)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .navigationDestination(for: String.self) { userId in
                UserProfileView(userId: userId)
            }
            .navigationDestination(for: Trip.self) { trip in
                TripDetailView(trip: trip)
            }
            .refreshable {
                await tripStore.load(userId: authViewModel.firebaseUID)
            }
        }
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            GAGAAvatar(url: user?.avatarURL, size: 48)
                .padding(.trailing, 8)
            StatItem(value: "\(tripStore.trips.count)", label: "旅行")
            StatItem(value: "\(visitedCountriesCount)", label: "国")
            if let uid = authViewModel.firebaseUID {
                NavigationLink {
                    FollowListView(userId: uid, initialTab: .followers)
                } label: {
                    StatItem(value: "\(user?.followersCount ?? 0)", label: "フォロワー")
                }
                .buttonStyle(.plain)
            } else {
                StatItem(value: "\(user?.followersCount ?? 0)", label: "フォロワー")
            }
            if let uid = authViewModel.firebaseUID {
                NavigationLink {
                    FollowListView(userId: uid, initialTab: .following)
                } label: {
                    StatItem(value: "\(user?.followingCount ?? 0)", label: "フォロー")
                }
                .buttonStyle(.plain)
            } else {
                StatItem(value: "\(user?.followingCount ?? 0)", label: "フォロー")
            }
        }
        .padding(.horizontal, GAGATheme.spacingMD)
    }

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

    private var visitedCountriesCount: Int {
        var countries = Set<String>()
        for trip in tripStore.trips {
            let country = trip.origin.country.trimmingCharacters(in: .whitespaces)
            if !country.isEmpty { countries.insert(country) }
            for dest in trip.destinations {
                let c = dest.country.trimmingCharacters(in: .whitespaces)
                if !c.isEmpty { countries.insert(c) }
            }
        }
        return countries.count
    }

    private var allVisitedCountries: [String] {
        var countries: [String] = []
        for trip in tripStore.trips {
            let origin = trip.origin.country.trimmingCharacters(in: .whitespaces)
            if !origin.isEmpty { countries.append(origin) }
            for dest in trip.destinations {
                let c = dest.country.trimmingCharacters(in: .whitespaces)
                if !c.isEmpty { countries.append(c) }
            }
        }
        return countries
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(duration: 0.3)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        if selectedTab == tab {
                            Rectangle()
                                .fill(GAGATheme.accentGradient)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "tabIndicator", in: tabAnimation)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        Group {
            switch selectedTab {
            case .globe:
                GeometryReader { geo in
                    GlobeView()
                }
                .frame(minHeight: 400)
            case .suitcase:
                if let uid = authViewModel.firebaseUID {
                    SuitcaseView(visitedCountries: allVisitedCountries, userId: uid)
                }
            case .list:
                tripListContent
            }
        }
        .id(selectedTab)
        .sensoryFeedback(.selection, trigger: selectedTab)
    }

    @ViewBuilder
    private var tripListContent: some View {
        if tripStore.trips.isEmpty {
            GAGAEmptyState(
                icon: "airplane",
                title: "旅行がまだありません",
                description: "旅行タブから作成しましょう"
            )
            .frame(height: 400)
        } else {
            LazyVStack(spacing: 16) {
                ForEach(tripStore.trips) { trip in
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

}

private enum ProfileTab: CaseIterable {
    case globe, suitcase, list

    var icon: String {
        switch self {
        case .globe: "globe.americas.fill"
        case .suitcase: "suitcase.fill"
        case .list: "list.bullet"
        }
    }
}

private struct ProfileTripCard: View {
    let trip: Trip

    private var routeText: String {
        ([trip.origin] + trip.destinations).map(\.name).joined(separator: " → ")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            cardBackground
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )

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
                    Text(trip.status.rawValue)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(GAGATheme.tripStatusColor(trip.status).opacity(0.3), in: Capsule())
                        .foregroundStyle(.white)

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
        }
    }
}

private struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundStyle(GAGATheme.accentGradient)
            Text(label)
                .font(GAGATheme.captionFont)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileView()
        .environment(AuthViewModel())
        .environment(TripStore())
}
