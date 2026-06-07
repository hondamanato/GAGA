import Foundation

struct LocationResult: Identifiable, Hashable {
    var id: String { "\(name)-\(country)" }
    let name: String
    let country: String
    let latitude: Double
    let longitude: Double
    let postCount: Int
}

@Observable
@MainActor
final class SearchStore {
    var query = ""
    var currentUserId: String?
    var userResults: [AppUser] = []
    var countryResults: [LocationResult] = []
    var locationResults: [LocationResult] = []
    var isSearching = false

    private let service = SearchService()
    private var searchTask: Task<Void, Never>?

    /// ひらがな/カタカナを同一視 + 読み仮名/ローマ字も検索
    private func kanaPrefix(_ text: String, _ prefix: String) -> Bool {
        let t = text.applyingTransform(.hiraganaToKatakana, reverse: false) ?? text
        let p = prefix.applyingTransform(.hiraganaToKatakana, reverse: false) ?? prefix
        if t.hasPrefix(p) { return true }
        // 小文字で比較（ローマ字対応）
        if text.lowercased().hasPrefix(prefix.lowercased()) { return true }
        // 読み仮名辞書を検索
        if let readings = CityCatalog.readings[text] {
            let pLower = prefix.lowercased()
            let pKana = prefix.applyingTransform(.hiraganaToKatakana, reverse: false) ?? prefix
            for reading in readings {
                let rKana = reading.applyingTransform(.hiraganaToKatakana, reverse: false) ?? reading
                if rKana.hasPrefix(pKana) || reading.lowercased().hasPrefix(pLower) { return true }
            }
        }
        return false
    }

    func performSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else {
            clear()
            return
        }

        // ローカル検索（即時）— 国リスト + 都市リスト両方を検索
        let localCountries = CityCatalog.countries
            .filter { kanaPrefix($0.name, trimmed) }
        let localLocations = (CityCatalog.all + CityCatalog.countries)
            .filter { kanaPrefix($0.name, trimmed) || kanaPrefix($0.country, trimmed) }

        countryResults = deduplicateCountries(from: [], local: localCountries)
        locationResults = deduplicateLocations(from: [], local: localLocations)

        guard trimmed.count >= 2 else { return }

        isSearching = true
        searchTask = Task {
            do {
                async let users = service.searchUsers(prefix: trimmed)
                async let usernameUsers = service.searchUsersByUsername(prefix: trimmed)
                async let countryPosts = service.searchPostsByCountry(prefix: trimmed)
                async let locationPosts = service.searchPostsByLocationName(prefix: trimmed)

                let (u, uu, cp, lp) = try await (users, usernameUsers, countryPosts, locationPosts)
                guard !Task.isCancelled else { return }

                // マージ・重複排除
                var seen = Set<String>()
                var merged: [AppUser] = []
                for user in u + uu {
                    if user.id == currentUserId { continue }
                    if seen.insert(user.id).inserted {
                        merged.append(user)
                    }
                }
                userResults = merged
                countryResults = deduplicateCountries(from: cp, local: localCountries)
                locationResults = deduplicateLocations(from: lp, local: localLocations)
            } catch {
                guard !Task.isCancelled else { return }
            }
            isSearching = false
        }
    }

    func clear() {
        userResults = []
        countryResults = []
        locationResults = []
        isSearching = false
    }

    private func deduplicateCountries(from posts: [Post], local: [Location]) -> [LocationResult] {
        var grouped: [String: (location: Location, count: Int)] = [:]

        for post in posts {
            let key = post.location.country
            if let existing = grouped[key] {
                grouped[key] = (existing.location, existing.count + 1)
            } else {
                grouped[key] = (post.location, 1)
            }
        }

        for loc in local where grouped[loc.country] == nil {
            grouped[loc.country] = (loc, 0)
        }

        return grouped.values
            .sorted { $0.count > $1.count }
            .map { LocationResult(name: $0.location.country, country: $0.location.country, latitude: $0.location.latitude, longitude: $0.location.longitude, postCount: $0.count) }
    }

    private func deduplicateLocations(from posts: [Post], local: [Location]) -> [LocationResult] {
        var grouped: [String: (location: Location, count: Int)] = [:]

        for post in posts {
            let key = post.location.name
            if let existing = grouped[key] {
                grouped[key] = (existing.location, existing.count + 1)
            } else {
                grouped[key] = (post.location, 1)
            }
        }

        for loc in local where grouped[loc.name] == nil {
            grouped[loc.name] = (loc, 0)
        }

        return grouped.values
            .sorted { $0.count > $1.count }
            .map { LocationResult(name: $0.location.name, country: $0.location.country, latitude: $0.location.latitude, longitude: $0.location.longitude, postCount: $0.count) }
    }
}
