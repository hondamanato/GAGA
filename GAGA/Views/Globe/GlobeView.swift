import SwiftUI
import MapboxMaps

struct GlobeView: View {
    @Environment(TripStore.self) private var tripStore

    @State private var viewport: Viewport = .camera(
        center: CLLocationCoordinate2D(latitude: 15, longitude: 15),
        zoom: 0.3,
        bearing: 0,
        pitch: 0
    )

    // カメラが変わる度にインクリメントしてアノテーションを再評価させる
    @State private var cameraTick: Int = 0
    @State private var mapRef: MapboxMap?
    @State private var tappedLabel: TappedLabel?

    var body: some View {
        ZStack {
            MapReader { proxy in
                Map(viewport: $viewport) {
                    flightRoutes
                    planeAnnotations
                    pinAnnotations
                    labelTapInteractions
                }
                .mapStyle(.satelliteStreets)
                .onCameraChanged { _ in
                    mapRef = proxy.map
                    cameraTick &+= 1
                }
                .onStyleLoaded { _ in
                    mapRef = proxy.map
                    try? proxy.map?.setProjection(StyleProjection(name: .globe))

                    var atmosphere = Atmosphere()
                    atmosphere.starIntensity = .constant(1.0)
                    atmosphere.spaceColor = .constant(StyleColor(.black))
                    atmosphere.color = .constant(StyleColor(UIColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0)))
                    atmosphere.highColor = .constant(StyleColor(UIColor(red: 0.05, green: 0.05, blue: 0.2, alpha: 1.0)))
                    atmosphere.horizonBlend = .constant(0.05)
                    try? proxy.map?.setAtmosphere(atmosphere)
                    try? proxy.map?.localizeLabels(into: Locale.current)

                    // 地球儀スケールで邪魔になるレイヤーを非表示にする。
                    // 国名 / 州名 / 都市名の -label レイヤーと衛星 raster は残す。
                    let hidePrefixes = [
                        "road", "bridge", "tunnel", "building",
                        "poi", "transit", "ferry", "airport", "housenum"
                    ]
                    if let layerIds = proxy.map?.allLayerIdentifiers.map(\.id) {
                        for id in layerIds where hidePrefixes.contains(where: { id.hasPrefix($0) }) {
                            try? proxy.map?.setLayerProperty(
                                for: id,
                                property: "visibility",
                                value: "none"
                            )
                        }
                    }

                }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $tappedLabel) { label in
            LocationPostsView(tappedLabel: label)
        }
    }

    // MARK: - Routes

    @MapContentBuilder
    private var flightRoutes: some MapContent {
        ForEvery(routeSegments, id: \.id) { segment in
            GeoJSONSource(id: "route-source-\(segment.id)")
                .data(.geometry(.lineString(LineString(segment.coordinates))))

            makeRouteLayer(for: segment)
        }
    }

    @MapContentBuilder
    private var planeAnnotations: some MapContent {
        ForEvery(routeSegments, id: \.id) { segment in
            MapViewAnnotation(coordinate: segment.midpoint) {
                // cameraTick を参照することでカメラ変化時に再評価される
                let angle = screenAngle(for: segment, tick: cameraTick)
                Image(systemName: "airplane")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 2)
                    .rotationEffect(.degrees(angle))
                    .allowsHitTesting(false)
            }
            .allowOverlap(true)
        }
    }

    /// midpoint と nextPoint をスクリーン座標に投影し、
    /// SF Symbol `airplane`（デフォルト右向き）に合うスクリーン空間角度を返す。
    /// `tick` はカメラ変化時の再評価をトリガーするためだけに参照する。
    private func screenAngle(for segment: RouteSegment, tick: Int) -> Double {
        _ = tick
        guard let map = mapRef else {
            // マップ未取得時はフォールバックとして球面方位 - 90°
            return segment.bearing - 90
        }
        let p1 = map.point(for: segment.midpoint)
        let p2 = map.point(for: segment.nextPoint)
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        guard dx != 0 || dy != 0 else {
            return segment.bearing - 90
        }
        // SwiftUI の座標系は y が下向き。SF Symbol airplane はデフォルトで右 (+x) 向き。
        // atan2(dy, dx) をそのまま rotationEffect(.degrees:) に渡せば一致する。
        return atan2(dy, dx) * 180 / .pi
    }

    private func makeRouteLayer(for segment: RouteSegment) -> LineLayer {
        var layer = LineLayer(id: "route-layer-\(segment.id)", source: "route-source-\(segment.id)")
        layer.lineColor = .constant(StyleColor(UIColor.white))
        layer.lineWidth = .constant(3.5)
        layer.lineOpacity = .constant(0.95)
        layer.lineDasharray = .constant([2, 2])
        layer.lineCap = .constant(.round)
        return layer
    }

    private var routeSegments: [RouteSegment] {
        var segments: [RouteSegment] = []
        for trip in tripStore.trips {
            var previous = trip.origin
            for (index, dest) in trip.destinations.enumerated() {
                let coords = generateGreatCirclePath(
                    from: CLLocationCoordinate2D(latitude: previous.latitude, longitude: previous.longitude),
                    to: CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude),
                    pointCount: 100
                )
                let midIndex = coords.count / 2
                let midpoint = coords.isEmpty ? CLLocationCoordinate2D(latitude: 0, longitude: 0) : coords[midIndex]
                let bearingRef = midIndex + 1 < coords.count ? coords[midIndex + 1] : coords.last ?? midpoint
                let segBearing = geoBearing(from: midpoint, to: bearingRef)
                segments.append(
                    RouteSegment(
                        id: "\(trip.id)-\(index)",
                        coordinates: coords,
                        color: color(for: trip.status),
                        midpoint: midpoint,
                        nextPoint: bearingRef,
                        bearing: segBearing
                    )
                )
                previous = dest
            }
        }
        return segments
    }

    private func color(for status: TripStatus) -> UIColor {
        switch status {
        case .planning: return .systemOrange
        case .traveling: return .systemGreen
        case .completed: return .systemCyan
        }
    }

    // MARK: - Label Tap

    private static let tappableLayers = [
        "country-label", "state-label", "settlement-label",
        "settlement-subdivision-label",
    ]

    @MapContentBuilder
    private var labelTapInteractions: some MapContent {
        ForEvery(Self.tappableLayers, id: \.self) { layerId in
            TapInteraction(.layer(layerId)) { feature, context in
                let props = feature.properties
                guard let name = Self.stringValue(props["name"] as? JSONValue)
                    ?? Self.stringValue(props["name_en"] as? JSONValue) else {
                    return false
                }
                let isCountry = layerId == "country-label"
                let coord = context.coordinate
                tappedLabel = TappedLabel(
                    name: name,
                    isCountry: isCountry,
                    latitude: coord.latitude,
                    longitude: coord.longitude
                )
                return true
            }
        }
    }

    private static func stringValue(_ value: JSONValue?) -> String? {
        guard case .string(let s) = value else { return nil }
        return s
    }

    // MARK: - Pins

    @MapContentBuilder
    private var pinAnnotations: some MapContent {
        ForEvery(uniquePins, id: \.name) { pin in
            MapViewAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                VStack(spacing: 2) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .background(Circle().fill(.blue))
                        .shadow(radius: 3)
                    Text(pin.name)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.black.opacity(0.6)))
                }
            }
        }
    }

    private var uniquePins: [Location] {
        var seen = Set<String>()
        var result: [Location] = []
        for trip in tripStore.trips {
            for location in [trip.origin] + trip.destinations {
                if seen.insert(location.name).inserted {
                    result.append(location)
                }
            }
        }
        return result
    }

    // generateGreatCirclePath / geoBearing は Utilities/GeoMath.swift に定義
}

struct TappedLabel: Identifiable {
    let id = UUID()
    let name: String
    let isCountry: Bool
    let latitude: Double
    let longitude: Double
}

private struct RouteSegment {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let color: UIColor
    let midpoint: CLLocationCoordinate2D
    let nextPoint: CLLocationCoordinate2D
    let bearing: CLLocationDirection
}

#Preview {
    GlobeView()
        .environment(TripStore())
}
