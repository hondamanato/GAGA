import SwiftUI

struct FollowListView: View {
    let userId: String
    let initialTab: FollowTab

    @State private var selectedTab: FollowTab
    @State private var followers: [AppUser] = []
    @State private var following: [AppUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = UserService()

    init(userId: String, initialTab: FollowTab) {
        self.userId = userId
        self.initialTab = initialTab
        _selectedTab = State(initialValue: initialTab)
    }

    enum FollowTab: String, CaseIterable {
        case followers = "フォロワー"
        case following = "フォロー中"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(FollowTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                let users = selectedTab == .followers ? followers : following
                if users.isEmpty {
                    GAGAEmptyState(
                        icon: "person.2",
                        title: selectedTab == .followers ? "フォロワーはいません" : "フォローしているユーザーはいません",
                        description: selectedTab == .followers ? "フォロワーが増えるとここに表示されます" : "ユーザーをフォローしてみましょう"
                    )
                } else {
                    List(users) { user in
                        NavigationLink(value: user.id) {
                            HStack(spacing: 12) {
                                GAGAAvatar(url: user.avatarURL, size: 44)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.displayName)
                                        .font(GAGATheme.bodyFont)
                                        .fontWeight(.semibold)
                                    if !user.bio.isEmpty {
                                        Text(user.bio)
                                            .font(GAGATheme.captionFont)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
        }
        .navigationTitle(selectedTab.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadAll()
        }
        .alert("読み込みに失敗しました", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let f = service.fetchFollowers(userId: userId)
            async let g = service.fetchFollowing(userId: userId)
            followers = try await f
            following = try await g
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
