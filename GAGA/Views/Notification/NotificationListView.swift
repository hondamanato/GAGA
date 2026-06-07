import SwiftUI

struct NotificationListView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(NotificationStore.self) private var notificationStore
    @State private var userCache: [String: AppUser] = [:]

    var body: some View {
        NavigationStack {
            Group {
                if notificationStore.notifications.isEmpty {
                    ContentUnavailableView("通知はありません", systemImage: "bell.slash", description: Text("いいね・コメント・フォローの通知がここに表示されます"))
                } else {
                    List(notificationStore.notifications) { notification in
                        NotificationRow(notification: notification, actor: userCache[notification.actorId])
                            .listRowBackground(notification.isRead ? Color.clear : Color.blue.opacity(0.08))
                            .onAppear {
                                Task { await notificationStore.markAsRead(notification) }
                                Task { await loadUserIfNeeded(notification.actorId) }
                            }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("通知")
            .toolbar {
                if !notificationStore.notifications.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("すべて既読") {
                            Task { await notificationStore.markAllAsRead(userId: authViewModel.firebaseUID) }
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }

    private func loadUserIfNeeded(_ userId: String) async {
        guard userCache[userId] == nil else { return }
        if let user = try? await UserService().fetchUser(id: userId) {
            userCache[userId] = user
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let actor: AppUser?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
                .font(.title3)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(GAGATheme.bodyFont)
                    .lineLimit(2)
                Text(notification.createdAt, style: .relative)
                    .font(GAGATheme.captionFont)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var actorName: String {
        actor?.displayName ?? "ユーザー"
    }

    private var iconName: String {
        switch notification.type {
        case .like: "heart.fill"
        case .comment: "bubble.left.fill"
        case .follow: "person.badge.plus"
        }
    }

    private var iconColor: Color {
        switch notification.type {
        case .like: .pink
        case .comment: .blue
        case .follow: .green
        }
    }

    private var message: AttributedString {
        var result = AttributedString()
        var name = AttributedString(actorName)
        name.font = GAGATheme.headlineFont
        result.append(name)

        switch notification.type {
        case .like:
            result.append(AttributedString("が「\(notification.tripTitle ?? "旅行")」にいいねしました"))
        case .comment:
            result.append(AttributedString("が「\(notification.tripTitle ?? "旅行")」にコメントしました"))
        case .follow:
            result.append(AttributedString("があなたをフォローしました"))
        }
        return result
    }
}
