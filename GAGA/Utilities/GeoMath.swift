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
        let lon = atan2(y, x) * 180 / .pi

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

func flagEmoji(for country: String) -> String {
    let map: [String: String] = [
        "Japan": "JP", "Thailand": "TH", "United States": "US",
        "United Kingdom": "GB", "France": "FR", "Germany": "DE",
        "Italy": "IT", "Spain": "ES", "Australia": "AU",
        "Canada": "CA", "China": "CN", "South Korea": "KR",
        "Taiwan": "TW", "Singapore": "SG", "Malaysia": "MY",
        "Indonesia": "ID", "Vietnam": "VN", "Philippines": "PH",
        "India": "IN", "Brazil": "BR", "Mexico": "MX",
        "Netherlands": "NL", "Kenya": "KE", "Egypt": "EG",
        "South Africa": "ZA", "Turkey": "TR", "Russia": "RU",
        "UAE": "AE", "Portugal": "PT", "Greece": "GR",
        "Switzerland": "CH", "Sweden": "SE", "Norway": "NO",
        "Finland": "FI", "Denmark": "DK", "New Zealand": "NZ",
        "Cambodia": "KH", "Myanmar": "MM", "Nepal": "NP",
        "Morocco": "MA", "Argentina": "AR", "Peru": "PE",
        "Colombia": "CO", "Chile": "CL", "Croatia": "HR",
        "Czech Republic": "CZ", "Poland": "PL", "Hungary": "HU",
        "Austria": "AT", "Belgium": "BE", "Ireland": "IE",
        "Sri Lanka": "LK", "Tanzania": "TZ", "Ethiopia": "ET",
    ]
    guard let code = map[country], code.count == 2 else { return "" }
    let base: UInt32 = 0x1F1E6 - 65 // 'A' offset for regional indicator
    return String(code.uppercased().unicodeScalars.compactMap {
        UnicodeScalar(base + $0.value)
    }.map { Character($0) })
}
