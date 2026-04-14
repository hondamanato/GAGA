import Foundation
import FirebaseFirestore

enum ChecklistService {
    private static var db: Firestore { Firestore.firestore() }
    private static var cache: [String: [ChecklistItem]] = [:]

    static func save(tripId: String, items: [ChecklistItem]) async throws {
        cache[tripId] = items
        let data: [String: Any] = [
            "items": try items.map { try Firestore.Encoder().encode($0) },
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        try await db.collection("trips").document(tripId)
            .collection("checklist").document("items")
            .setData(data)
    }

    static func load(tripId: String) async throws -> [ChecklistItem]? {
        if let cached = cache[tripId] {
            return cached
        }
        let snapshot = try await db.collection("trips").document(tripId)
            .collection("checklist").document("items")
            .getDocument()
        guard snapshot.exists,
              let rawItems = snapshot.data()?["items"] as? [[String: Any]] else {
            return nil
        }
        let items = try rawItems.compactMap { dict in
            let data = try JSONSerialization.data(withJSONObject: dict)
            return try JSONDecoder().decode(ChecklistItem.self, from: data)
        }
        cache[tripId] = items
        return items
    }

    static func invalidate(tripId: String) {
        cache.removeValue(forKey: tripId)
    }
}
