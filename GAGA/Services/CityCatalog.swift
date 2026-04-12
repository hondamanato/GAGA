import Foundation

enum CityCatalog {
    static let all: [Location] = [
        Location(name: "東京",           country: "日本",         latitude: 35.6762, longitude: 139.6503),
        Location(name: "大阪",           country: "日本",         latitude: 34.6937, longitude: 135.5023),
        Location(name: "京都",           country: "日本",         latitude: 35.0116, longitude: 135.7681),
        Location(name: "ソウル",         country: "韓国",         latitude: 37.5665, longitude: 126.9780),
        Location(name: "台北",           country: "台湾",         latitude: 25.0330, longitude: 121.5654),
        Location(name: "香港",           country: "中国",         latitude: 22.3193, longitude: 114.1694),
        Location(name: "上海",           country: "中国",         latitude: 31.2304, longitude: 121.4737),
        Location(name: "シンガポール",     country: "シンガポール",   latitude: 1.3521,  longitude: 103.8198),
        Location(name: "バンコク",       country: "タイ",         latitude: 13.7563, longitude: 100.5018),
        Location(name: "バリ",           country: "インドネシア",   latitude: -8.4095, longitude: 115.1889),
        Location(name: "ハノイ",         country: "ベトナム",      latitude: 21.0278, longitude: 105.8342),
        Location(name: "ドバイ",         country: "UAE",          latitude: 25.2048, longitude: 55.2708),
        Location(name: "イスタンブール",  country: "トルコ",        latitude: 41.0082, longitude: 28.9784),
        Location(name: "パリ",           country: "フランス",      latitude: 48.8566, longitude: 2.3522),
        Location(name: "ロンドン",       country: "イギリス",      latitude: 51.5074, longitude: -0.1278),
        Location(name: "ローマ",         country: "イタリア",      latitude: 41.9028, longitude: 12.4964),
        Location(name: "バルセロナ",     country: "スペイン",      latitude: 41.3851, longitude: 2.1734),
        Location(name: "ベルリン",       country: "ドイツ",        latitude: 52.5200, longitude: 13.4050),
        Location(name: "アムステルダム",  country: "オランダ",      latitude: 52.3676, longitude: 4.9041),
        Location(name: "ウィーン",       country: "オーストリア",   latitude: 48.2082, longitude: 16.3738),
        Location(name: "プラハ",         country: "チェコ",        latitude: 50.0755, longitude: 14.4378),
        Location(name: "ニューヨーク",   country: "アメリカ",      latitude: 40.7128, longitude: -74.0060),
        Location(name: "ロサンゼルス",   country: "アメリカ",      latitude: 34.0522, longitude: -118.2437),
        Location(name: "サンフランシスコ", country: "アメリカ",      latitude: 37.7749, longitude: -122.4194),
        Location(name: "ホノルル",       country: "アメリカ",      latitude: 21.3069, longitude: -157.8583),
        Location(name: "バンクーバー",   country: "カナダ",        latitude: 49.2827, longitude: -123.1207),
        Location(name: "メキシコシティ", country: "メキシコ",      latitude: 19.4326, longitude: -99.1332),
        Location(name: "リオデジャネイロ", country: "ブラジル",     latitude: -22.9068, longitude: -43.1729),
        Location(name: "シドニー",       country: "オーストラリア", latitude: -33.8688, longitude: 151.2093),
        Location(name: "ケープタウン",   country: "南アフリカ",    latitude: -33.9249, longitude: 18.4241),
    ]

    static func find(name: String) -> Location? {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return all.first { $0.name == trimmed }
    }
}
