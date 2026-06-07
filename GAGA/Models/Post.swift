import Foundation

struct Post: Identifiable, Codable {
    var id: String
    var userId: String
    var tripId: String
    var imageURL: String
    var location: Location
    var caption: String
    var createdAt: Date

    init(id: String = UUID().uuidString, userId: String, tripId: String, imageURL: String, location: Location, caption: String = "", createdAt: Date = .now) {
        self.id = id
        self.userId = userId
        self.tripId = tripId
        self.imageURL = imageURL
        self.location = location
        self.caption = caption
        self.createdAt = createdAt
    }
}

struct Comment: Identifiable, Codable {
    var id: String
    var userId: String
    var text: String
    var createdAt: Date

    init(id: String = UUID().uuidString, userId: String, text: String, createdAt: Date = .now) {
        self.id = id
        self.userId = userId
        self.text = text
        self.createdAt = createdAt
    }
}
