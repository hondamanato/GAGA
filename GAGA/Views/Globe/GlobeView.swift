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
    @State private var isZoomedIn = false
    @State private var currentZoom: Double = 0.3
    @State private var selectedPin: PinData?
    @State private var navigateToTrip: Trip?
    @State private var navigateToLocationIndex: Int?

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
                .ornamentOptions(OrnamentOptions(
                    scaleBar: ScaleBarViewOptions(visibility: .hidden),
                    compass: CompassViewOptions(visibility: .hidden)
                ))
                .onCameraChanged { context in
                    mapRef = proxy.map
                    cameraTick &+= 1
                    currentZoom = context.cameraState.zoom
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

            // ズームアウトボタン
            if isZoomedIn {
                VStack {
                    HStack {
                        Button {
                            isZoomedIn = false
                            withAnimation { selectedPin = nil }
                            withViewportAnimation(.fly) {
                                viewport = .camera(
                                    center: CLLocationCoordinate2D(latitude: 15, longitude: 15),
                                    zoom: 0.3, bearing: 0, pitch: 0
                                )
                            }
                        } label: {
                            Image(systemName: "globe.asia.australia")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    Spacer()
                }
                .transition(.opacity)
            }

            // ピンタップ時のコンパクト旅行カード
            if let pin = selectedPin {
                VStack(spacing: 8) {
                    Spacer()
                    let trips = tripsForLocation(pin.location)
                    ForEach(trips) { trip in
                        GlobeTripCard(trip: trip)
                            .onTapGesture {
                                // 選択中のピンに対応するロケーションインデックスを計算
                                let allLocations = [trip.origin] + trip.destinations
                                navigateToLocationIndex = allLocations.firstIndex(where: { $0.id == pin.location.id }) ?? 0
                                navigateToTrip = trip
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(item: $navigateToTrip) { trip in
            NavigationStack {
                TripJournalView(initialTrip: trip, initialLocationIndex: navigateToLocationIndex)
            }
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

    /// 飛行機アイコンもズームに連動してフェードイン
    private var planeOpacity: Double {
        let t = (currentZoom - 1.5) / 1.5  // 1.5〜3.0 で 0→1
        return min(max(t, 0), 1)
    }

    @MapContentBuilder
    private var planeAnnotations: some MapContent {
        ForEvery(routeSegments, id: \.id) { segment in
            MapViewAnnotation(coordinate: segment.midpoint) {
                let angle = screenAngle(for: segment, tick: cameraTick)
                Image(systemName: "airplane")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white.opacity(planeOpacity))
                    .shadow(color: .black.opacity(0.6 * planeOpacity), radius: 2)
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

    /// ズームレベルに応じて徐々にフェードイン (zoom 1.5〜3.0 で 0→0.95)
    private func makeRouteLayer(for segment: RouteSegment) -> LineLayer {
        var layer = LineLayer(id: "route-layer-\(segment.id)", source: "route-source-\(segment.id)")
        layer.lineColor = .constant(StyleColor(UIColor.white))
        layer.lineWidth = .expression(
            Exp(.interpolate) { Exp(.linear); Exp(.zoom); 1.5; 0.0; 3.0; 3.5 }
        )
        layer.lineOpacity = .expression(
            Exp(.interpolate) { Exp(.linear); Exp(.zoom); 1.5; 0.0; 3.0; 0.95 }
        )
        layer.lineDasharray = .constant([2, 2])
        layer.lineCap = .constant(.round)
        return layer
    }

    private var routeSegments: [RouteSegment] {
        // ピン選択時はその場所を含む旅行のルートだけ表示
        let trips: [Trip]
        if let pin = selectedPin {
            trips = tripsForLocation(pin.location)
        } else {
            trips = tripStore.trips
        }
        var segments: [RouteSegment] = []
        for trip in trips {
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

    private static let countryLayers = [
        "country-label",
    ]

    private static let cityLayers = [
        "state-label", "settlement-label",
        "settlement-subdivision-label",
        "settlement-major-label", "settlement-minor-label",
        "place-city-label", "place-town-label", "place-village-label",
    ]

    @MapContentBuilder
    private var labelTapInteractions: some MapContent {
        ForEvery(Self.countryLayers, id: \.self) { layerId in
            TapInteraction(.layer(layerId)) { feature, context in
                guard let name = Self.labelName(from: feature.properties) else { return false }
                tappedLabel = TappedLabel(
                    name: name, isCountry: true,
                    latitude: context.coordinate.latitude,
                    longitude: context.coordinate.longitude
                )
                return true
            }
        }
        ForEvery(Self.cityLayers, id: \.self) { layerId in
            TapInteraction(.layer(layerId)) { feature, context in
                guard let name = Self.labelName(from: feature.properties) else { return false }
                tappedLabel = TappedLabel(
                    name: name, isCountry: false,
                    latitude: context.coordinate.latitude,
                    longitude: context.coordinate.longitude
                )
                return true
            }
        }
    }

    private static func labelName(from props: [String: Any?]) -> String? {
        stringValue(props["name"] as? JSONValue)
            ?? stringValue(props["name_en"] as? JSONValue)
    }

    private static func stringValue(_ value: JSONValue?) -> String? {
        guard case .string(let s) = value else { return nil }
        return s
    }

    // MARK: - Pins

    @MapContentBuilder
    private var pinAnnotations: some MapContent {
        ForEvery(uniquePins, id: \.id) { pin in
            MapViewAnnotation(coordinate: CLLocationCoordinate2D(
                latitude: pin.location.latitude,
                longitude: pin.location.longitude
            )) {
                Group {
                    let isSelected = selectedPin?.id == pin.id
                    pinImage(for: pin)
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(isSelected ? .blue : .white, lineWidth: isSelected ? 3 : 2.5))
                        .shadow(color: isSelected ? .blue.opacity(0.5) : .black.opacity(0.3), radius: isSelected ? 6 : 3, y: 1)
                }
                .onTapGesture {
                    isZoomedIn = true
                    withAnimation(.easeInOut(duration: 0.3)) {
                        selectedPin = pin
                    }
                    withViewportAnimation(.fly) {
                        viewport = .camera(
                            center: CLLocationCoordinate2D(
                                latitude: pin.location.latitude,
                                longitude: pin.location.longitude
                            ),
                            zoom: 5, bearing: 0, pitch: 0
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func pinImage(for pin: PinData) -> some View {
        if let urlString = pin.imageURL, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                pinFallbackImage(for: pin.location)
            }
        } else if let asset = LocationPostsView.heroAssets[pin.location.country] {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            let token = MapboxOptions.accessToken
            let urlStr = "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/\(pin.location.longitude),\(pin.location.latitude),10,0/100x100@2x?access_token=\(token)"
            CachedAsyncImage(url: URL(string: urlStr)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(GAGATheme.deepNavy.opacity(0.5))
            }
        }
    }

    private func pinFallbackImage(for location: Location) -> some View {
        Circle().fill(GAGATheme.deepNavy.opacity(0.5))
            .overlay { ProgressView().tint(.white).scaleEffect(0.5) }
    }

    private func defaultPinView(isSelected: Bool = false) -> some View {
        Circle()
            .fill(.white)
            .frame(width: isSelected ? 20 : 16, height: isSelected ? 20 : 16)
            .overlay(Circle().fill(.blue).frame(width: isSelected ? 14 : 10, height: isSelected ? 14 : 10))
            .overlay(isSelected ? Circle().stroke(.blue, lineWidth: 2) : nil)
            .shadow(color: isSelected ? .blue.opacity(0.5) : .black.opacity(0.3), radius: isSelected ? 6 : 2, y: 1)
    }

    private var uniquePins: [PinData] {
        var seen = Set<String>()
        var result: [PinData] = []
        for trip in tripStore.trips {
            for location in [trip.origin] + trip.destinations {
                if seen.insert(location.id).inserted {
                    let imageURL = tripStore.trips
                        .lazy
                        .compactMap { $0.locationCoverImages[location.id] }
                        .first
                    result.append(PinData(location: location, imageURL: imageURL))
                }
            }
        }
        return result
    }

    private func tripsForLocation(_ location: Location) -> [Trip] {
        tripStore.trips.filter { trip in
            ([trip.origin] + trip.destinations).contains(where: { $0.id == location.id })
        }
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

private struct PinData: Identifiable, Equatable {
    var id: String { location.id }
    let location: Location
    let imageURL: String?
}

// MARK: - Globe Trip Card (コンパクト)

private struct GlobeTripCard: View {
    let trip: Trip

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }()

    private var routeText: String {
        let names = ([trip.origin] + trip.destinations).map {
            flagEmoji(for: $0.country) + " " + $0.name
        }
        return names.joined(separator: " → ")
    }

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 5) {
                Text(trip.title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(routeText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(trip.status.localizedName)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(GAGATheme.tripStatusColor(trip.status).opacity(0.4), in: Capsule())
                        .foregroundStyle(.white)

                    HStack(spacing: 3) {
                        Image(systemName: "calendar")
                            .font(.caption2)
                        Text("\(Self.dateFormatter.string(from: trip.departureDate)) - \(Self.dateFormatter.string(from: trip.returnDate))")
                            .font(.caption2)
                    }
                    .foregroundStyle(.white.opacity(0.6))
                }
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let urlStr = trip.coverImageURL, let url = URL(string: urlStr) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackThumbnail
            }
        } else if let dest = trip.destinations.first,
                  let asset = LocationPostsView.heroAssets[dest.country] {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else if let dest = trip.destinations.first {
            let token = MapboxOptions.accessToken
            let urlStr = "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/\(dest.longitude),\(dest.latitude),8,0/200x200@2x?access_token=\(token)"
            CachedAsyncImage(url: URL(string: urlStr)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackThumbnail
            }
        } else {
            fallbackThumbnail
        }
    }

    private var fallbackThumbnail: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(GAGATheme.deepNavy.opacity(0.5))
            .overlay {
                Image(systemName: "airplane")
                    .foregroundStyle(.white.opacity(0.4))
            }
    }
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
