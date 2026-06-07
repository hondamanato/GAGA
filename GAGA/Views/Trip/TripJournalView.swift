import SwiftUI
import MapboxMaps
import MapKit

struct TripJournalView: View {
    let initialTrip: Trip
    var initialLocationIndex: Int? = nil

    @Environment(PostStore.self) private var postStore
    @Environment(TripStore.self) private var tripStore
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss

    /// TripStore から最新の Trip を取得（更新反映用）
    private var trip: Trip {
        tripStore.trips.first(where: { $0.id == initialTrip.id }) ?? initialTrip
    }

    @State private var selectedLocationIndex: Int = 0
    @State private var scrolledCardId: Int?
    @State private var showMenu = false
    @State private var showCreatePost = false
    @State private var createPostDate: Date?
    @State private var mapRef: MapboxMap?
    @State private var cameraTick: Int = 0
    @State private var showLocationPicker = false
    @State private var insertIndex: Int = 0
    @State private var detailLocation: Location?
    @State private var showComments = false
    @State private var selectedSegmentIndex: Int? = nil
    @State private var routeSegments: [TripRouteSegment] = []

    @State private var viewport: Viewport = .idle

    private var destinationFlags: String {
        trip.destinations.map { flagEmoji(for: $0.country) }.joined(separator: " ")
    }

    // MARK: - Route segments for this trip

    private func loadRouteSegments() async {
        var segments: [TripRouteSegment] = []
        var previous = trip.origin
        for (index, dest) in trip.destinations.enumerated() {
            let from = CLLocationCoordinate2D(latitude: previous.latitude, longitude: previous.longitude)
            let to = CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
            let transport = trip.transportType(forSegment: index)

            let coords: [CLLocationCoordinate2D]
            if transport.usesRoadRoute {
                coords = await fetchRoadRoute(from: from, to: to, transportType: transport) ?? generateGreatCirclePath(from: from, to: to, pointCount: 100)
            } else {
                coords = generateGreatCirclePath(from: from, to: to, pointCount: 100)
            }

            let midIndex = coords.count / 2
            let midpoint = coords.isEmpty ? CLLocationCoordinate2D(latitude: 0, longitude: 0) : coords[midIndex]
            let nextPt = midIndex + 1 < coords.count ? coords[midIndex + 1] : coords.last ?? midpoint
            segments.append(TripRouteSegment(
                id: "\(trip.id)-\(index)",
                coordinates: coords,
                midpoint: midpoint,
                nextPoint: nextPt,
                bearing: geoBearing(from: midpoint, to: nextPt)
            ))
            previous = dest
        }
        routeSegments = segments
    }

    private func fetchRoadRoute(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D, transportType: TransportType) async -> [CLLocationCoordinate2D]? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = transportType.mkTransportType
        request.requestsAlternateRoutes = false
        do {
            let response = try await MKDirections(request: request).calculate()
            guard let route = response.routes.first else { return nil }
            let count = route.polyline.pointCount
            let points = route.polyline.points()
            return (0..<count).map { points[$0].coordinate }
        } catch {
            return nil
        }
    }

    private var initialCamera: Viewport {
        let allLocations = [trip.origin] + trip.destinations

        // 特定ロケーションが指定されていたらそこにフォーカス
        if let idx = initialLocationIndex, allLocations.indices.contains(idx) {
            let loc = allLocations[idx]
            return .camera(
                center: CLLocationCoordinate2D(latitude: loc.latitude - 1.5, longitude: loc.longitude),
                zoom: 5, bearing: 0, pitch: 0
            )
        }

        let lats = allLocations.map(\.latitude)
        let lons = allLocations.map(\.longitude)
        let centerLat = (lats.min()! + lats.max()!) / 2
        let centerLon = (lons.min()! + lons.max()!) / 2
        let latSpan = (lats.max()! - lats.min()!)
        let lonSpan = (lons.max()! - lons.min()!)
        let maxSpan = max(latSpan, lonSpan)
        let zoom: Double
        if maxSpan > 100 { zoom = 0.5 }
        else if maxSpan > 50 { zoom = 1.2 }
        else if maxSpan > 20 { zoom = 2.5 }
        else if maxSpan > 10 { zoom = 3.5 }
        else { zoom = 4.5 }
        return .camera(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            zoom: zoom, bearing: 0, pitch: 0
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen globe
            globeMap
                .ignoresSafeArea()

            // Bottom section: progress bar + cards
            VStack(spacing: 0) {
                dayProgressOverlay
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                photoCardsSection
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            if let idx = initialLocationIndex {
                selectedLocationIndex = idx
                scrolledCardId = idx
            }
            viewport = initialCamera
        }
        .onChange(of: selectedLocationIndex) {
            let locations = tripLocations
            guard locations.indices.contains(selectedLocationIndex) else { return }
            let loc = locations[selectedLocationIndex]
            // Offset latitude upward so pin appears above the bottom cards area
            let offsetLat = loc.latitude - 1.5
            withViewportAnimation(.fly) {
                viewport = .camera(
                    center: CLLocationCoordinate2D(latitude: offsetLat, longitude: loc.longitude),
                    zoom: 5, bearing: 0, pitch: 0
                )
            }
        }
        .task {
            await postStore.loadPosts(forTripId: trip.id)
            await loadRouteSegments()
        }
        .sheet(isPresented: $showMenu) {
            TripMenuSheet(trip: trip)
        }
        .sheet(isPresented: $showCreatePost, onDismiss: {
            Task { await postStore.loadPosts(forTripId: trip.id) }
        }) {
            CreatePostView(initialTripId: trip.id, initialDate: createPostDate)
        }
        .sheet(isPresented: $showLocationPicker) {
            AddStepSheet(
                defaultDate: estimatedDate(forInsertAt: insertIndex),
                onAdd: { location, date in
                    Task { await addDestination(location, at: insertIndex) }
                }
            )
            .presentationDetents([.medium])
            .presentationCornerRadius(24)
        }
        .fullScreenCover(item: $detailLocation) { location in
            LocationCardDetailView(
                location: location,
                trip: trip,
                isLiked: tripStore.likedTripIds.contains(trip.id),
                canInteract: authViewModel.firebaseUID != nil,
                onLikeTap: {
                    guard let uid = authViewModel.firebaseUID else { return }
                    Task { await tripStore.toggleLike(trip: trip, userId: uid) }
                },
                onCommentTap: {
                    detailLocation = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        showComments = true
                    }
                },
                onDismiss: { detailLocation = nil }
            )
        }
        .sheet(isPresented: $showComments) {
            CommentsView(trip: trip)
                .presentationDetents([.medium, .large])
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: Binding(
            get: { selectedSegmentIndex != nil },
            set: { if !$0 { selectedSegmentIndex = nil } }
        )) {
            if let index = selectedSegmentIndex {
                TransportTypePicker(
                    current: trip.transportType(forSegment: index),
                    onSelect: { type in
                        Task { await updateTransport(type, forSegment: index) }
                        selectedSegmentIndex = nil
                    }
                )
                .presentationDetents([.height(280)])
                .presentationCornerRadius(24)
            }
        }
    }

    private func estimatedDate(forInsertAt index: Int) -> Date {
        let locations = tripLocations
        let totalLocations = locations.count
        guard totalLocations > 0 else { return trip.departureDate }
        let cal = Calendar.current
        let totalDays = max(cal.dateComponents([.day], from: trip.departureDate, to: trip.returnDate).day ?? 0, 1)
        // Interpolate: position index out of totalLocations+1 slots
        let fraction = Double(index) / Double(totalLocations)
        let dayOffset = Int(round(fraction * Double(totalDays)))
        return cal.date(byAdding: .day, value: dayOffset, to: trip.departureDate) ?? trip.departureDate
    }

    private func addDestination(_ location: Location, at index: Int) async {
        var updated = trip
        // index 0 = before origin (insert as new first destination, shift origin)
        // index == destinations.count + 1 = append at end
        let destIndex = max(index - 1, 0)
        if index == 0 {
            updated.destinations.insert(trip.origin, at: 0)
            updated.origin = location
        } else if destIndex >= updated.destinations.count {
            updated.destinations.append(location)
        } else {
            updated.destinations.insert(location, at: destIndex)
        }
        do {
            try await TripService().update(updated)
            tripStore.applyUpdate(updated)
        } catch {
            // silent fail
        }
    }

    private func updateTransport(_ type: TransportType, forSegment index: Int) async {
        var updated = trip
        updated.segmentTransports["\(index)"] = type.rawValue
        do {
            try await TripService().update(updated)
            tripStore.applyUpdate(updated)
            await loadRouteSegments()
        } catch {
            // silent fail
        }
    }

    // MARK: - Globe Map

    private var globeMap: some View {
        ZStack(alignment: .top) {
            MapReader { proxy in
                Map(viewport: $viewport) {
                    // Route lines
                    ForEvery(routeSegments, id: \.id) { segment in
                        GeoJSONSource(id: "trip-route-\(segment.id)")
                            .data(.geometry(.lineString(LineString(segment.coordinates))))

                        makeRouteLayer(for: segment)
                    }

                    // Transport annotations
                    ForEvery(Array(routeSegments.enumerated()), id: \.element.id) { index, segment in
                        MapViewAnnotation(coordinate: segment.midpoint) {
                            let angle = planeAngle(for: segment, tick: cameraTick)
                            let transport = trip.transportType(forSegment: index)
                            Image(systemName: transport.rawValue)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(.white)
                                .shadow(color: .black.opacity(0.6), radius: 2)
                                .rotationEffect(.degrees(transport == .airplane ? angle : 0))
                                .onTapGesture { selectedSegmentIndex = index }
                        }
                        .allowOverlap(true)
                    }

                    // Location pins
                    ForEvery(Array(tripLocations.enumerated()), id: \.offset) { index, pin in
                        MapViewAnnotation(coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude)) {
                            let isSelected = index == selectedLocationIndex
                            let pinSize: CGFloat = isSelected ? 48 : 36
                            VStack(spacing: 2) {
                                locationPinImage(for: pin)
                                    .frame(width: pinSize, height: pinSize)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(isSelected ? .blue : .white, lineWidth: isSelected ? 3 : 2.5))
                                    .shadow(color: isSelected ? .blue.opacity(0.6) : .black.opacity(0.3), radius: isSelected ? 8 : 3, y: 1)
                                    .animation(.easeInOut(duration: 0.3), value: isSelected)

                                Text(pin.name)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(.black.opacity(0.6)))
                            }
                        }
                        .allowOverlap(true)
                    }
                }
                .mapStyle(.satelliteStreets)
                .ornamentOptions(OrnamentOptions(
                    scaleBar: ScaleBarViewOptions(visibility: .hidden),
                    compass: CompassViewOptions(visibility: .hidden),
                    logo: LogoViewOptions(margins: .init(x: 8, y: -100)),
                    attributionButton: AttributionButtonOptions(margins: .init(x: -100, y: -100))
                ))
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

                    let hidePrefixes = ["road", "bridge", "tunnel", "building", "poi", "transit", "ferry", "airport", "housenum"]
                    if let layerIds = proxy.map?.allLayerIdentifiers.map(\.id) {
                        for id in layerIds where hidePrefixes.contains(where: { id.hasPrefix($0) }) {
                            try? proxy.map?.setLayerProperty(for: id, property: "visibility", value: "none")
                        }
                    }
                }
            }

            // Header
            header
                .padding(.top, 56)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial.opacity(0.6), in: Circle())
            }

            Spacer()

            VStack(spacing: 2) {
                Text(trip.title)
                    .font(GAGATheme.headlineFont)
                    .foregroundStyle(.white)
                if !destinationFlags.isEmpty {
                    Text(destinationFlags)
                        .font(.title3)
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 4)

            Spacer()

            Button {
                showMenu = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial.opacity(0.6), in: Circle())
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Day Progress Overlay

    private var dayProgressOverlay: some View {
        GeometryReader { geo in
            let count = tripLocations.count
            let width = geo.size.width
            let pillWidth: CGFloat = 90
            let minX = pillWidth / 2
            let maxX = width - pillWidth / 2
            let progress = count > 1
                ? CGFloat(selectedLocationIndex) / CGFloat(count - 1)
                : 0.5
            let indicatorX = minX + (maxX - minX) * progress
            let currentLocation = tripLocations[min(selectedLocationIndex, count - 1)]

            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(.white.opacity(0.3))
                    .frame(height: 4)
                    .padding(.vertical, 16)

                // Active track
                Capsule()
                    .fill(Color.blue)
                    .frame(width: max(indicatorX, 0), height: 4)
                    .padding(.vertical, 16)

                // Location indicator
                HStack(spacing: 4) {
                    Image(systemName: "figure.walk")
                        .font(.system(size: 11, weight: .semibold))
                    Text(currentLocation.name)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .position(x: indicatorX, y: 18)
                .animation(.spring(duration: 0.3), value: selectedLocationIndex)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        guard count > 0 else { return }
                        let fraction = max(0, min(1, (value.location.x - minX) / (maxX - minX)))
                        let idx = count > 1
                            ? Int(round(fraction * CGFloat(count - 1)))
                            : 0
                        let clamped = max(0, min(count - 1, idx))
                        if clamped != selectedLocationIndex {
                            selectedLocationIndex = clamped
                        }
                    }
            )
        }
        .frame(height: 36)
    }

    // MARK: - Photo Cards

    private var tripLocations: [Location] {
        [trip.origin] + trip.destinations
    }

    private var photoCardsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 0) {
                ForEach(Array(tripLocations.enumerated()), id: \.offset) { index, location in
                    HStack(spacing: 0) {
                        addButton(at: index)

                        locationCard(location: location)
                            .id(index)
                            .onTapGesture { detailLocation = location }
                            .scrollTransition { content, phase in
                                content
                                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                                    .opacity(phase.isIdentity ? 1 : 0.7)
                            }
                    }
                }
                addButton(at: tripLocations.count)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrolledCardId)
        .onChange(of: scrolledCardId) { _, newId in
            if let newId, newId != selectedLocationIndex {
                selectedLocationIndex = newId
            }
        }
    }

    private func addButton(at index: Int) -> some View {
        Button {
            insertIndex = index
            showLocationPicker = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 3)
        }
        .padding(.horizontal, 6)
    }

    private static let windowShape = UnevenRoundedRectangle(
        topLeadingRadius: 80, bottomLeadingRadius: 50,
        bottomTrailingRadius: 50, topTrailingRadius: 80
    )

    private func locationCard(location: Location) -> some View {
        return ZStack(alignment: .topLeading) {
            locationHeroImage(for: location)
                .frame(width: 220, height: 290)
                .clipped()

            let flag = flagEmoji(for: location.country)
            if !flag.isEmpty {
                Text(flag)
                    .font(.system(size: 20))
                    .padding(6)
                    .background(.ultraThinMaterial, in: Circle())
                    .padding(10)
            }
        }
        .overlay(alignment: .bottomLeading) {
            Text(location.name)
                .font(GAGATheme.headlineFont)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 3)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.5)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
        .clipShape(Self.windowShape)
        .overlay(Self.windowShape.stroke(.white.opacity(0.5), lineWidth: 3))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    // MARK: - Hero Image

    @ViewBuilder
    private func locationHeroImage(for location: Location) -> some View {
        if let urlStr = trip.locationCoverImages[location.id], let url = URL(string: urlStr) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(GAGATheme.deepNavy.opacity(0.5))
                    .overlay { ProgressView().tint(.white) }
            }
        } else if let asset = LocationPostsView.heroAssets[location.country] {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            let token = MapboxOptions.accessToken
            let urlStr = "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/\(location.longitude),\(location.latitude),8,0/480x600@2x?access_token=\(token)"
            CachedAsyncImage(url: URL(string: urlStr)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(GAGATheme.deepNavy.opacity(0.5))
                    .overlay { ProgressView().tint(.white) }
            }
        }
    }

    // MARK: - Helpers

    private func makeRouteLayer(for segment: TripRouteSegment) -> LineLayer {
        var layer = LineLayer(id: "trip-line-\(segment.id)", source: "trip-route-\(segment.id)")
        layer.lineColor = .constant(StyleColor(UIColor.white))
        layer.lineWidth = .constant(3.5)
        layer.lineOpacity = .constant(0.95)
        layer.lineDasharray = .constant([2, 2])
        layer.lineCap = .constant(.round)
        return layer
    }

    private var tripPins: [Location] {
        var seen = Set<String>()
        var result: [Location] = []
        for location in [trip.origin] + trip.destinations {
            if seen.insert(location.name).inserted {
                result.append(location)
            }
        }
        return result
    }

    @ViewBuilder
    private func locationPinImage(for location: Location) -> some View {
        if let urlStr = trip.locationCoverImages[location.id], let url = URL(string: urlStr) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(GAGATheme.deepNavy.opacity(0.5))
                    .overlay { ProgressView().tint(.white).scaleEffect(0.5) }
            }
        } else if let asset = LocationPostsView.heroAssets[location.country] {
            Image(asset)
                .resizable()
                .scaledToFill()
        } else {
            let token = MapboxOptions.accessToken
            let urlStr = "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/\(location.longitude),\(location.latitude),10,0/100x100@2x?access_token=\(token)"
            CachedAsyncImage(url: URL(string: urlStr)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Circle().fill(GAGATheme.deepNavy.opacity(0.5))
            }
        }
    }

    private func planeAngle(for segment: TripRouteSegment, tick: Int) -> Double {
        _ = tick
        guard let map = mapRef else { return segment.bearing - 90 }
        let p1 = map.point(for: segment.midpoint)
        let p2 = map.point(for: segment.nextPoint)
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        guard dx != 0 || dy != 0 else { return segment.bearing - 90 }
        return atan2(dy, dx) * 180 / .pi
    }
}

private struct TripRouteSegment {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
    let midpoint: CLLocationCoordinate2D
    let nextPoint: CLLocationCoordinate2D
    let bearing: CLLocationDirection
}

// MARK: - Add Step Sheet

private struct AddStepSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var selectedLocation: Location?
    @State private var date: Date
    @State private var searchResults: [Location] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    let onAdd: (Location, Date) -> Void

    init(defaultDate: Date, onAdd: @escaping (Location, Date) -> Void) {
        _date = State(initialValue: defaultDate)
        self.onAdd = onAdd
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private var localFiltered: [Location] {
        guard !trimmedQuery.isEmpty else { return [] }
        let q = trimmedQuery
        return CityCatalog.all.filter {
            kanaPrefix($0.name, q) || kanaPrefix($0.country, q)
        }
    }

    private func kanaPrefix(_ text: String, _ prefix: String) -> Bool {
        let t = text.applyingTransform(.hiraganaToKatakana, reverse: false) ?? text
        let p = prefix.applyingTransform(.hiraganaToKatakana, reverse: false) ?? prefix
        return t.hasPrefix(p)
    }

    private var displayResults: [Location] {
        if trimmedQuery.isEmpty { return [] }
        var seen: Set<String> = []
        var merged: [Location] = []
        for loc in localFiltered + searchResults {
            let key = "\(loc.name)-\(loc.country)"
            if seen.insert(key).inserted { merged.append(loc) }
        }
        return merged
    }

    private var canAdd: Bool {
        selectedLocation != nil
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ja_JP")
        f.dateFormat = "M月d日 (E)"
        return f
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Location field
                VStack(alignment: .leading, spacing: 4) {
                    Text("場所")
                        .font(GAGATheme.captionFont)
                        .foregroundStyle(.secondary)
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        if let loc = selectedLocation {
                            HStack {
                                Text("\(flagEmoji(for: loc.country)) \(loc.name)")
                                    .font(GAGATheme.bodyFont)
                                Spacer()
                                Button {
                                    selectedLocation = nil
                                    query = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            TextField("都市名や場所で検索", text: $query)
                                .font(GAGATheme.bodyFont)
                        }
                    }
                    .padding(12)
                    .background(.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                // Search results
                if selectedLocation == nil && !displayResults.isEmpty {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(displayResults, id: \.self) { loc in
                                Button {
                                    selectedLocation = loc
                                    query = loc.name
                                } label: {
                                    HStack {
                                        Text(flagEmoji(for: loc.country))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(loc.name)
                                                .font(GAGATheme.bodyFont)
                                                .foregroundStyle(.primary)
                                            Text(loc.country)
                                                .font(GAGATheme.captionFont)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 4)
                                }
                                Divider()
                            }
                        }
                    }
                    .frame(maxHeight: 150)
                }

                // Date field
                VStack(alignment: .leading, spacing: 4) {
                    Text("日付")
                        .font(GAGATheme.captionFont)
                        .foregroundStyle(.secondary)
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundStyle(.secondary)
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .labelsHidden()
                        Spacer()
                        Text(Self.dateFormatter.string(from: date))
                            .font(GAGATheme.bodyFont)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Spacer()

                // Add button
                Button {
                    guard let loc = selectedLocation else { return }
                    onAdd(loc, date)
                    dismiss()
                } label: {
                    Text("追加")
                        .font(GAGATheme.headlineFont)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            if canAdd {
                                GAGATheme.accentGradient
                            } else {
                                Color.gray.opacity(0.3)
                            }
                        }
                        .foregroundStyle(canAdd ? .white : .secondary)
                        .clipShape(RoundedRectangle(cornerRadius: GAGATheme.buttonRadius))
                }
                .disabled(!canAdd)
            }
            .padding(20)
            .navigationTitle("訪問地を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onChange(of: query) { _, newValue in
                searchTask?.cancel()
                let q = newValue.trimmingCharacters(in: .whitespaces)
                guard q.count >= 2 else {
                    searchResults = []
                    return
                }
                searchTask = Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    guard !Task.isCancelled else { return }
                    await search(query: q)
                }
            }
        }
    }

    private func search(query: String) async {
        isSearching = true
        defer { isSearching = false }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        do {
            let response = try await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            var seen: Set<String> = []
            searchResults = response.mapItems.compactMap { item in
                guard let name = item.name ?? item.placemark.locality ?? item.placemark.name else { return nil }
                let country = item.placemark.country ?? ""
                let coord = item.placemark.coordinate
                let key = "\(name)-\(coord.latitude)-\(coord.longitude)"
                guard seen.insert(key).inserted else { return nil }
                return Location(name: name, country: country, latitude: coord.latitude, longitude: coord.longitude)
            }
        } catch {
            if !Task.isCancelled { searchResults = [] }
        }
    }
}

// MARK: - Transport Type Picker

private struct TransportTypePicker: View {
    let current: TransportType
    let onSelect: (TransportType) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(.secondary.opacity(0.4))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Text("移動手段")
                .font(GAGATheme.headlineFont)

            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(TransportType.allCases, id: \.self) { type in
                    let isSelected = type == current
                    Button {
                        onSelect(type)
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: type.rawValue)
                                .font(.system(size: 24))
                                .frame(width: 52, height: 52)
                                .background(isSelected ? GAGATheme.coral : Color(.systemGray6))
                                .foregroundStyle(isSelected ? .white : .primary)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Text(type.label)
                                .font(GAGATheme.captionFont)
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
