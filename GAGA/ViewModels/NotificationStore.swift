import Foundation
import FirebaseFirestore

@Observable @MainActor
final class NotificationStore {
    var notifications: [AppNotification] = []
    var unreadCount: Int = 0

    private let service = NotificationService()
    private var listener: ListenerRegistration?

    func startListening(userId: String) {
        listener?.remove()
        guard !userId.isEmpty else { return }
        listener = service.listenNotifications(userId: userId) { [weak self] notifications in
            guard let self else { return }
            self.notifications = notifications
            self.unreadCount = notifications.filter { !$0.isRead }.count
        }
    }

    func markAsRead(_ notification: AppNotification) async {
        guard let id = notification.firestoreId, !notification.isRead else { return }
        try? await service.markAsRead(notificationId: id)
    }

    func markAllAsRead(userId: String) async {
        try? await service.markAllAsRead(userId: userId)
    }

    func clear() {
        listener?.remove()
        listener = nil
        notifications = []
        unreadCount = 0
    }
}
