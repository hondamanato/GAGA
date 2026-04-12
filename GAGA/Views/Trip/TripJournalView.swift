import SwiftUI
import MapboxMaps

struct TripJournalView: View {
    let trip: Trip
    @Environment(PostStore.self) private var postStore
    @Environment(\.dismiss) private var dismiss

    @State private var viewport: Viewport = .idle
    @State private var selectedPostId: String?
    @State private var showMenu = false
    @State private var showCreatePost = false
    @State private var mapRef: MapboxMap?

    private var posts: [Post] {
        (postStore.tripPosts[trip.id] ?? []).sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedPost: Post? {
        posts.first { $0.id == selectedPostId }
    }

    var body: some View {
        ZStack {
            mapLayer
            overlay
        }
        .ignoresSafeArea(edges: .top)
        .navigationBarHidden(true)
        .task {
            await postStore.loadPosts(forTripId: trip.id)
            if let first = posts.first {
                selectedPostId = first.id
                moveCameraTo(first.location)
            } else {
                let center = trip.destinations.first ?? trip.origin
                viewport = .camera(
                    center: CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude),
                    zoom: 4, bearing: 0, pitch: 30
                )
            }
        }
        .sheet(isPresented: $showMenu) {
            TripMenuSheet(trip: trip)
        }
        .sheet(isPresented: $showCreatePost, onDismiss: {
            Task { await postStore.loadPosts(forTripId: trip.id) }
        }) {
            CreatePostView(initialTripId: trip.id)
        }
    }

    // MARK: - Map

    private var mapLayer: some View {
        MapReader { proxy in
            Map(viewport: $viewport) {
                routeLines
                postAnnotations
            }
            .mapStyle(.satellite)
            .onStyleLoaded { _ in
                mapRef = proxy.map
            }
        }
    }

    // MARK: - Route Lines

    private var journalRouteSegments: [JournalRouteSegment] {
        let allLocations = [trip.origin] + trip.destinations
        var segments: [JournalRouteSegment] = []
        for i in 0..<(allLocations.count - 1) {
            let from = allLocations[i]
            let to = allLocations[i + 1]
            let coords = generateGreatCirclePath(
                from: CLLocationCoordinate2D(latitude: from.latitude, longitude: from.longitude),
                to: CLLocationCoordinate2D(latitude: to.latitude, longitude: to.longitude),
                pointCount: 100
            )
            segments.append(JournalRouteSegment(id: "journal-\(i)", coordinates: coords))
        }
        return segments
    }

    @MapContentBuilder
    private var routeLines: some MapContent {
        ForEvery(journalRouteSegments, id: \.id) { segment in
            GeoJSONSource(id: "route-\(segment.id)")
                .data(.geometry(.lineString(LineString(segment.coordinates))))

            makeJournalRouteLayer(for: segment)
        }
    }

    private func makeJournalRouteLayer(for segment: JournalRouteSegment) -> LineLayer {
        var layer = LineLayer(id: "line-\(segment.id)", source: "route-\(segment.id)")
        layer.lineColor = .constant(StyleColor(UIColor.white))
        layer.lineWidth = .constant(3)
        layer.lineOpacity = .constant(0.8)
        layer.lineDasharray = .constant([2, 2])
        layer.lineCap = .constant(.round)
        return layer
    }

    // MARK: - Post Annotations

    @MapContentBuilder
    private var postAnnotations: some MapContent {
        ForEvery(posts, id: \.id) { post in
            let isSelected = post.id == selectedPostId
            MapViewAnnotation(coordinate: CLLocationCoordinate2D(latitude: post.location.latitude, longitude: post.location.longitude)) {
                AsyncImage(url: URL(string: post.imageURL)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Color.gray
                    }
                }
                .frame(width: isSelected ? 56 : 36, height: isSelected ? 56 : 36)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white, lineWidth: 3))
                .overlay {
                    if isSelected {
                        Circle().stroke(.cyan, lineWidth: 4).padding(-4)
                    }
                }
                .shadow(color: .black.opacity(0.5), radius: 4)
                .onTapGesture {
                    selectedPostId = post.id
                    moveCameraTo(post.location)
                }
            }
            .allowOverlap(true)
        }
    }

    // MARK: - Overlay (Header + Day Pill + Carousel)

    private var overlay: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 56)
            Spacer()
            if !posts.isEmpty {
                dayPill
                    .padding(.leading, 16)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                postCarousel
            } else {
                Button {
                    showCreatePost = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.largeTitle)
                            .foregroundStyle(.white.opacity(0.8))
                        Text("タップして写真を投稿")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.4), in: Circle())
            }
            Spacer()
            Text(trip.title)
                .font(.headline)
                .foregroundStyle(.white)
                .shadow(radius: 2)
            Spacer()
            Button {
                showMenu = true
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.black.opacity(0.4), in: Circle())
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Day Pill

    private var dayPill: some View {
        let day = selectedPost.map { dayNumber(for: $0) } ?? 1
        return HStack(spacing: 6) {
            Image(systemName: "airplane")
            Text("Day \(day)")
        }
        .font(.subheadline.bold())
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Capsule().fill(.blue.opacity(0.85)))
    }

    // MARK: - Post Carousel

    private var postCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 12) {
                ForEach(posts) { post in
                    postCard(for: post)
                        .id(post.id)
                        .onTapGesture {
                            selectedPostId = post.id
                            moveCameraTo(post.location)
                        }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 16)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $selectedPostId)
        .frame(height: 220)
        .onChange(of: selectedPostId) { _, newId in
            guard let post = posts.first(where: { $0.id == newId }) else { return }
            moveCameraTo(post.location)
        }
    }

    // MARK: - Post Card

    private func postCard(for post: Post) -> some View {
        ZStack(alignment: .bottomLeading) {
            AsyncImage(url: URL(string: post.imageURL)) { phase in
                switch phase {
                case .success(let img):
                    img.resizable().scaledToFill()
                default:
                    Color.gray.opacity(0.3)
                }
            }
            .frame(width: 280, height: 200)
            .clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 4) {
                let flag = flagEmoji(for: post.location.country)
                if !flag.isEmpty {
                    Text(flag)
                        .font(.title3)
                        .padding(4)
                        .background(Circle().fill(.white.opacity(0.2)))
                }
                Text(post.caption.isEmpty ? post.location.name : post.caption)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 12) {
                    Label("\(post.likesCount)", systemImage: "heart")
                    Label("\(post.commentsCount)", systemImage: "bubble.right")
                }
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
            }
            .padding(12)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.3), radius: 6)
    }

    // MARK: - Helpers

    private func dayNumber(for post: Post) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: trip.departureDate)
        let d = cal.startOfDay(for: post.createdAt)
        return max((cal.dateComponents([.day], from: start, to: d).day ?? 0) + 1, 1)
    }

    private func moveCameraTo(_ location: Location) {
        withViewportAnimation(.easeInOut(duration: 0.5)) {
            viewport = .camera(
                center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
                zoom: 5, bearing: 0, pitch: 30
            )
        }
    }
}

private struct JournalRouteSegment: Identifiable {
    let id: String
    let coordinates: [CLLocationCoordinate2D]
}
