import Foundation
import FirebaseFirestore

struct NotificationService {
    private var collection: CollectionReference {
        Firestore.firestore().collection("notifications")
    }

    func send(_ notification: AppNotification) async {
        guard notification.recipientId != notification.actorId else { return }
        do {
            try collection.addDocument(from: notification)
        } catch {
            // best-effort
        }
    }

    func fetchNotifications(userId: String, limit: Int = 50) async throws -> [AppNotification] {
        let snapshot = try await collection
            .whereField("recipientId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: AppNotification.self) }
    }

    func listenNotifications(userId: String, limit: Int = 50, onChange: @escaping ([AppNotification]) -> Void) -> ListenerRegistration {
        collection
            .whereField("recipientId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                let notifications = docs.compactMap { try? $0.data(as: AppNotification.self) }
                onChange(notifications)
            }
    }

    func markAsRead(notificationId: String) async throws {
        try await collection.document(notificationId).updateData(["isRead": true])
    }

    func markAllAsRead(userId: String) async throws {
        let snapshot = try await collection
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()
        let batch = Firestore.firestore().batch()
        for doc in snapshot.documents {
            batch.updateData(["isRead": true], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    func unreadCount(userId: String) async throws -> Int {
        let snapshot = try await collection
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .count
            .getAggregation(source: .server)
        return Int(truncating: snapshot.count)
    }
}
