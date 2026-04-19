import CoreLocation

func generateGreatCirclePath(
    from start: CLLocationCoordinate2D,
    to end: CLLocationCoordinate2D,
    pointCount: Int
) -> [CLLocationCoordinate2D] {
    let lat1 = start.latitude * .pi / 180
    let lon1 = start.longitude * .pi / 180
    let lat2 = end.latitude * .pi / 180
    let lon2 = end.longitude * .pi / 180

    let d = acos(sin(lat1) * sin(lat2) + cos(lat1) * cos(lat2) * cos(lon2 - lon1))

    guard d.isFinite, d > 0 else {
        return [start, end]
    }

    var coordinates: [CLLocationCoordinate2D] = []
    for i in 0...pointCount {
        let f = Double(i) / Double(pointCount)
        let a = sin((1 - f) * d) / sin(d)
        let b = sin(f * d) / sin(d)

        let x = a * cos(lat1) * cos(lon1) + b * cos(lat2) * cos(lon2)
        let y = a * cos(lat1) * sin(lon1) + b * cos(lat2) * sin(lon2)
        let z = a * sin(lat1) + b * sin(lat2)

        let lat = atan2(z, sqrt(x * x + y * y)) * 180 / .pi
        var lon = atan2(y, x) * 180 / .pi

        // Unwrap longitude to avoid date-line jumps in Mapbox rendering
        if let prev = coordinates.last {
            let diff = lon - prev.longitude
            if diff > 180 { lon -= 360 }
            else if diff < -180 { lon += 360 }
        }

        coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
    }

    return coordinates
}

func geoBearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> CLLocationDirection {
    let lat1 = a.latitude * .pi / 180
    let lat2 = b.latitude * .pi / 180
    let dLon = (b.longitude - a.longitude) * .pi / 180
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let deg = atan2(y, x) * 180 / .pi
    return (deg + 360).truncatingRemainder(dividingBy: 360)
}

private let _countryNameToCode: [String: String] = [
    // 日本語名
    "日本": "JP", "タイ": "TH", "アメリカ": "US", "アメリカ合衆国": "US",
    "イギリス": "GB", "フランス": "FR", "ドイツ": "DE",
    "イタリア": "IT", "スペイン": "ES", "オーストラリア": "AU",
    "カナダ": "CA", "中国": "CN", "中華人民共和国": "CN",
    "韓国": "KR", "大韓民国": "KR",
    "台湾": "TW", "シンガポール": "SG", "マレーシア": "MY",
    "インドネシア": "ID", "ベトナム": "VN", "フィリピン": "PH",
    "インド": "IN", "ブラジル": "BR", "メキシコ": "MX",
    "オランダ": "NL", "ケニア": "KE", "エジプト": "EG",
    "南アフリカ": "ZA", "トルコ": "TR", "ロシア": "RU",
    "ポルトガル": "PT", "ギリシャ": "GR",
    "スイス": "CH", "スウェーデン": "SE", "ノルウェー": "NO",
    "フィンランド": "FI", "デンマーク": "DK", "ニュージーランド": "NZ",
    "カンボジア": "KH", "ミャンマー": "MM", "ネパール": "NP",
    "モロッコ": "MA", "アルゼンチン": "AR", "ペルー": "PE",
    "コロンビア": "CO", "チリ": "CL", "クロアチア": "HR",
    "チェコ": "CZ", "ポーランド": "PL", "ハンガリー": "HU",
    "オーストリア": "AT", "ベルギー": "BE", "アイルランド": "IE",
    "スリランカ": "LK", "タンザニア": "TZ", "エチオピア": "ET",
    "アラブ首長国連邦": "AE", "UAE": "AE",
    // 英語名
    "Japan": "JP", "Thailand": "TH", "United States": "US",
    "United States of America": "US",
    "United Kingdom": "GB", "France": "FR", "Germany": "DE",
    "Italy": "IT", "Spain": "ES", "Australia": "AU",
    "Canada": "CA", "China": "CN", "South Korea": "KR",
    "Taiwan": "TW", "Singapore": "SG", "Malaysia": "MY",
    "Indonesia": "ID", "Vietnam": "VN", "Philippines": "PH",
    "India": "IN", "Brazil": "BR", "Mexico": "MX",
    "Netherlands": "NL", "Kenya": "KE", "Egypt": "EG",
    "South Africa": "ZA", "Turkey": "TR", "Türkiye": "TR", "Russia": "RU",
    "Portugal": "PT", "Greece": "GR",
    "Switzerland": "CH", "Sweden": "SE", "Norway": "NO",
    "Finland": "FI", "Denmark": "DK", "New Zealand": "NZ",
    "Cambodia": "KH", "Myanmar": "MM", "Nepal": "NP",
    "Morocco": "MA", "Argentina": "AR", "Peru": "PE",
    "Colombia": "CO", "Chile": "CL", "Croatia": "HR",
    "Czech Republic": "CZ", "Czechia": "CZ",
    "Poland": "PL", "Hungary": "HU",
    "Austria": "AT", "Belgium": "BE", "Ireland": "IE",
    "Sri Lanka": "LK", "Tanzania": "TZ", "Ethiopia": "ET",
    "United Arab Emirates": "AE",
    "Hong Kong": "HK", "香港": "HK",
]

func flagEmoji(for country: String) -> String {
    let trimmed = country.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return "" }

    let code: String
    // ISO 2文字コードの場合はそのまま使用
    if trimmed.count == 2 && trimmed.allSatisfy({ $0.isASCII && $0.isLetter }) {
        code = trimmed.uppercased()
    } else if let mapped = _countryNameToCode[trimmed] {
        code = mapped
    } else {
        return ""
    }

    let base: UInt32 = 0x1F1E6 - UInt32(UnicodeScalar("A").value)
    return String(code.unicodeScalars.compactMap {
        UnicodeScalar(base + $0.value)
    }.map { Character($0) })
}
