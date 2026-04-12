import SwiftUI

struct UserProfileView: View {
    let userId: String

    @Environment(AuthViewModel.self) private var authViewModel
    @State private var store = UserProfileStore()

    private let gridColumns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]

    private var isMe: Bool {
        authViewModel.firebaseUID == userId
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                header
                statsRow
                if !isMe, authViewModel.firebaseUID != nil {
                    followButton
                }
                Divider()
                postsGrid
            }
            .padding(.top, 8)
        }
        .navigationTitle(store.user?.displayName ?? "プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await store.load(userId: userId, currentUserId: authViewModel.firebaseUID)
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
        VStack(spacing: 8) {
            Circle()
                .fill(.gray.opacity(0.3))
                .frame(width: 88, height: 88)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.gray)
                }
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
    }

    private var statsRow: some View {
        HStack {
            stat(value: store.posts.count, label: "投稿")
            Divider().frame(height: 32)
            stat(value: store.user?.followersCount ?? 0, label: "フォロワー")
            Divider().frame(height: 32)
            stat(value: store.user?.followingCount ?? 0, label: "フォロー中")
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
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(store.isFollowing ? Color.gray.opacity(0.2) : Color.blue)
                .foregroundStyle(store.isFollowing ? Color.primary : Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding(.horizontal)
    }

    private var postsGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: 2) {
            ForEach(store.posts) { post in
                AsyncImage(url: URL(string: post.imageURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color.gray.opacity(0.15)
                            .overlay {
                                Image(systemName: "photo").foregroundStyle(.gray)
                            }
                    default:
                        Color.gray.opacity(0.1)
                    }
                }
                .frame(height: 120)
                .clipped()
            }
        }
    }
}
