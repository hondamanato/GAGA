import SwiftUI

struct TimelineView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(PostStore.self) private var postStore
    @State private var showCreatePost = false
    @State private var commentsTarget: Post?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("タイムライン")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreatePost = true
                        } label: {
                            Image(systemName: "square.and.pencil")
                        }
                        .disabled(authViewModel.firebaseUID == nil)
                    }
                }
                .sheet(isPresented: $showCreatePost) {
                    CreatePostView()
                }
                .sheet(item: $commentsTarget) { post in
                    CommentsView(post: post)
                        .presentationDetents([.medium, .large])
                }
                .refreshable {
                    await postStore.loadTimeline(currentUserId: authViewModel.firebaseUID)
                }
                .navigationDestination(for: String.self) { userId in
                    UserProfileView(userId: userId)
                }
                .alert(
                    "読み込みに失敗しました",
                    isPresented: Binding(
                        get: { postStore.errorMessage != nil },
                        set: { if !$0 { postStore.errorMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) { postStore.errorMessage = nil }
                } message: {
                    Text(postStore.errorMessage ?? "")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if postStore.isLoading && postStore.timeline.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if postStore.timeline.isEmpty {
            ContentUnavailableView(
                "投稿がまだありません",
                systemImage: "photo.on.rectangle.angled",
                description: Text("右上のボタンから最初の投稿をしましょう")
            )
        } else {
            List {
                ForEach(postStore.timeline) { post in
                    PostRow(
                        post: post,
                        isLiked: postStore.likedPostIds.contains(post.id),
                        canInteract: authViewModel.firebaseUID != nil,
                        onLikeTap: {
                            guard let uid = authViewModel.firebaseUID else { return }
                            Task { await postStore.toggleLike(post: post, userId: uid) }
                        },
                        onCommentTap: {
                            commentsTarget = post
                        }
                    )
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .listStyle(.plain)
        }
    }
}

private struct PostRow: View {
    let post: Post
    let isLiked: Bool
    let canInteract: Bool
    let onLikeTap: () -> Void
    let onCommentTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NavigationLink(value: post.userId) {
                HStack(spacing: 10) {
                    Circle()
                        .fill(.gray.opacity(0.3))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.gray)
                        }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.location.name)
                            .fontWeight(.semibold)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Text(post.createdAt.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .buttonStyle(.plain)

            AsyncImage(url: URL(string: post.imageURL)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .background(.gray.opacity(0.15))
                default:
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .background(.gray.opacity(0.15))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.subheadline)
            }

            HStack(spacing: 20) {
                Button(action: onLikeTap) {
                    Label("\(post.likesCount)", systemImage: isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(isLiked ? .red : .secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canInteract)

                Button(action: onCommentTap) {
                    Label("\(post.commentsCount)", systemImage: "bubble.right")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(!canInteract)
            }
            .font(.subheadline)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    TimelineView()
        .environment(AuthViewModel())
        .environment(PostStore())
}
