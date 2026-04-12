import Foundation

enum TripStatus: String, Codable, CaseIterable {
    case planning = "計画中"
    case traveling = "旅行中"
    case completed = "完了"
}

struct Location: Codable, Equatable, Hashable {
    var name: String
    var country: String
    var latitude: Double
    var longitude: Double
}

struct DaySchedule: Identifiable, Codable {
    var id: String
    var date: Date
    var spots: [String]
    var notes: String

    init(id: String = UUID().uuidString, date: Date, spots: [String] = [], notes: String = "") {
        self.id = id
        self.date = date
        self.spots = spots
        self.notes = notes
    }
}

struct Trip: Identifiable, Codable {
    var id: String
    var userId: String
    var title: String
    var origin: Location
    var destinations: [Location]
    var departureDate: Date
    var returnDate: Date
    var status: TripStatus
    var schedule: [DaySchedule]
    var createdAt: Date

    init(id: String = UUID().uuidString, userId: String, title: String, origin: Location, destinations: [Location], departureDate: Date, returnDate: Date, status: TripStatus = .planning, schedule: [DaySchedule] = [], createdAt: Date = .now) {
        self.id = id
        self.userId = userId
        self.title = title
        self.origin = origin
        self.destinations = destinations
        self.departureDate = departureDate
        self.returnDate = returnDate
        self.status = status
        self.schedule = schedule
        self.createdAt = createdAt
    }
}
