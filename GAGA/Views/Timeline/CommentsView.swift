import SwiftUI

struct CommentsView: View {
    let trip: Trip

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TripStore.self) private var tripStore

    @State private var comments: [Comment] = []
    @State private var userCache: [String: AppUser] = [:]
    @State private var newText = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?

    private let tripService = TripService()
    private let userService = UserService()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                content
                Divider()
                inputBar
            }
            .navigationTitle("コメント")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { await load() }
            .alert(
                "コメントの取得に失敗しました",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && comments.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if comments.isEmpty {
            GAGAEmptyState(
                icon: "bubble.right",
                title: "まだコメントがありません",
                description: "最初のコメントを書いてみましょう"
            )
        } else {
            List {
                ForEach(comments) { comment in
                    CommentRow(
                        comment: comment,
                        user: userCache[comment.userId]
                    )
                    .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("コメントを追加...", text: $newText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(authViewModel.firebaseUID == nil || isSending)

            Button {
                Task { await send() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
            }
            .disabled(!canSend)
        }
        .padding(12)
    }

    private var canSend: Bool {
        guard authViewModel.firebaseUID != nil, !isSending else { return false }
        return !newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await tripService.fetchComments(tripId: trip.id)
            comments = fetched
            let uniqueUserIds = Array(Set(fetched.map(\.userId)))
            if !uniqueUserIds.isEmpty {
                userCache = (try? await userService.fetchUsers(ids: uniqueUserIds)) ?? [:]
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func send() async {
        guard let uid = authViewModel.firebaseUID else { return }
        isSending = true
        defer { isSending = false }
        let text = newText
        do {
            try await tripStore.addComment(to: trip, userId: uid, text: text)
            newText = ""
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct CommentRow: View {
    let comment: Comment
    let user: AppUser?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            GAGAAvatar(url: user?.avatarURL, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(user?.displayName ?? "Traveler")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(comment.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(comment.text)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
