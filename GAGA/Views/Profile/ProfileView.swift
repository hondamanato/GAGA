import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TripStore.self) private var tripStore

    @State private var selectedTab: ProfileTab = .globe

    private var user: AppUser? { authViewModel.currentUser }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    statsRow
                    tabBar
                    tabContent
                }
                .padding(.vertical, 12)
            }
            .navigationTitle("プロフィール")
            .toolbar {
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
            .refreshable {
                await tripStore.load(userId: authViewModel.firebaseUID)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(.gray.opacity(0.3))
                .frame(width: 72, height: 72)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundStyle(.gray)
                }
            VStack(alignment: .leading, spacing: 4) {
                Text(user?.displayName ?? "ゲストユーザー")
                    .font(.title3)
                    .fontWeight(.bold)
                if let bio = user?.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("ログインして旅行を記録しよう")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private var statsRow: some View {
        HStack {
            StatItem(value: "\(visitedCountriesCount)", label: "国")
            Divider().frame(height: 32)
            StatItem(value: "\(user?.followersCount ?? 0)", label: "フォロワー")
            Divider().frame(height: 32)
            StatItem(value: "\(user?.followingCount ?? 0)", label: "フォロー")
        }
        .padding(.horizontal, 24)
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

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ProfileTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                        Rectangle()
                            .fill(selectedTab == tab ? Color.primary : Color.clear)
                            .frame(height: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .globe:
            GlobeView()
                .frame(height: 400)
        case .suitcase:
            ContentUnavailableView(
                "まだ何もありません",
                systemImage: "suitcase",
                description: Text("近日公開")
            )
            .frame(height: 400)
        case .list:
            tripListContent
        }
    }

    @ViewBuilder
    private var tripListContent: some View {
        if tripStore.trips.isEmpty {
            ContentUnavailableView(
                "旅行がまだありません",
                systemImage: "airplane",
                description: Text("旅行タブから作成しましょう")
            )
            .frame(height: 400)
        } else {
            LazyVStack(spacing: 0) {
                ForEach(tripStore.trips) { trip in
                    NavigationLink {
                        TripDetailView(trip: trip)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "airplane.departure")
                                .foregroundStyle(.blue)
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.title)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text(trip.destinations.map(\.name).joined(separator: " → "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    Divider()
                }
            }
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

private struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption2)
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
