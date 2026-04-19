import Foundation

enum TripStatus: String, Codable, CaseIterable {
    case planning = "計画中"
    case traveling = "旅行中"
    case completed = "完了"
}

struct Location: Identifiable, Codable, Equatable, Hashable {
    var id: String { "\(name)-\(latitude)-\(longitude)" }
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
    var coverImageURL: String?
    var locationCoverImages: [String: String]
    var likesCount: Int
    var commentsCount: Int
    var createdAt: Date

    init(id: String = UUID().uuidString, userId: String, title: String, origin: Location, destinations: [Location], departureDate: Date, returnDate: Date, status: TripStatus = .planning, schedule: [DaySchedule] = [], coverImageURL: String? = nil, locationCoverImages: [String: String] = [:], likesCount: Int = 0, commentsCount: Int = 0, createdAt: Date = .now) {
        self.id = id
        self.userId = userId
        self.title = title
        self.origin = origin
        self.destinations = destinations
        self.departureDate = departureDate
        self.returnDate = returnDate
        self.status = status
        self.schedule = schedule
        self.coverImageURL = coverImageURL
        self.locationCoverImages = locationCoverImages
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        userId = try c.decode(String.self, forKey: .userId)
        title = try c.decode(String.self, forKey: .title)
        origin = try c.decode(Location.self, forKey: .origin)
        destinations = try c.decode([Location].self, forKey: .destinations)
        departureDate = try c.decode(Date.self, forKey: .departureDate)
        returnDate = try c.decode(Date.self, forKey: .returnDate)
        status = try c.decode(TripStatus.self, forKey: .status)
        schedule = try c.decode([DaySchedule].self, forKey: .schedule)
        coverImageURL = try c.decodeIfPresent(String.self, forKey: .coverImageURL)
        locationCoverImages = try c.decodeIfPresent([String: String].self, forKey: .locationCoverImages) ?? [:]
        likesCount = try c.decodeIfPresent(Int.self, forKey: .likesCount) ?? 0
        commentsCount = try c.decodeIfPresent(Int.self, forKey: .commentsCount) ?? 0
        createdAt = try c.decode(Date.self, forKey: .createdAt)
    }
}
