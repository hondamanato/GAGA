import Foundation
import FirebaseFirestore

struct AppNotification: Identifiable, Codable {
    @DocumentID var firestoreId: String?
    var id: String { firestoreId ?? UUID().uuidString }
    var recipientId: String
    var actorId: String
    var type: NotificationType
    var tripId: String?
    var tripTitle: String?
    var isRead: Bool
    var createdAt: Date

    enum NotificationType: String, Codable {
        case like
        case comment
        case follow
    }

    init(recipientId: String, actorId: String, type: NotificationType, tripId: String? = nil, tripTitle: String? = nil) {
        self.recipientId = recipientId
        self.actorId = actorId
        self.type = type
        self.tripId = tripId
        self.tripTitle = tripTitle
        self.isRead = false
        self.createdAt = .now
    }
}
