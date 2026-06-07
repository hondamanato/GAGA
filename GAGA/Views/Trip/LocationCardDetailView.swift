import SwiftUI
import PhotosUI
import MapboxMaps

struct LocationCardDetailView: View {
    let location: Location
    let trip: Trip
    let isLiked: Bool
    let canInteract: Bool
    let onLikeTap: () -> Void
    let onCommentTap: () -> Void
    let onDismiss: () -> Void

    @Environment(TripStore.self) private var tripStore
    @State private var showHeartOverlay = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false

    private var coverImageURL: String? {
        trip.locationCoverImages[location.id]
    }

    private var heroAssetName: String? {
        LocationPostsView.heroAssets[location.country]
    }

    private var fallbackURL: URL? {
        let token = MapboxOptions.accessToken
        let urlStr = "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/\(location.longitude),\(location.latitude),8,0/480x600@2x?access_token=\(token)"
        return URL(string: urlStr)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy/M/d"
        return f
    }()

    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Full-screen image (user photo > hero asset > satellite)
            GeometryReader { geo in
                Group {
                    if let urlStr = coverImageURL, let url = URL(string: urlStr) {
                        CachedAsyncImage(url: url) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(GAGATheme.deepNavy)
                                .overlay { ProgressView().tint(.white) }
                        }
                    } else if let asset = heroAssetName {
                        Image(asset)
                            .resizable()
                            .scaledToFill()
                    } else {
                        CachedAsyncImage(url: fallbackURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(GAGATheme.deepNavy)
                                .overlay { ProgressView().tint(.white) }
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)
                .clipped()
            }
            .ignoresSafeArea()
            .onTapGesture(count: 2) {
                guard canInteract else { return }
                if !isLiked { onLikeTap() }
                showHeartOverlay = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showHeartOverlay = false
                }
            }

            // Heart animation overlay
            if showHeartOverlay {
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.3), radius: 8)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
                    .animation(.spring(duration: 0.4, bounce: 0.5), value: showHeartOverlay)
            }

            // Uploading overlay
            if isUploading {
                Color.black.opacity(0.4).ignoresSafeArea()
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            }

            // Top bar: close + photo picker
            VStack {
                HStack {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(.black.opacity(0.5), in: Circle())
                            .shadow(color: .black.opacity(0.5), radius: 4)
                    }
                    Spacer()
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(isUploading)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()
            }

            // Bottom overlay: location info + actions
            VStack {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        let flag = flagEmoji(for: location.country)
                        if !flag.isEmpty {
                            Text(flag)
                                .font(.system(size: 36))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(location.name)
                                .font(GAGATheme.titleFont)
                                .foregroundStyle(.white)
                            Text("\(Self.dateFormatter.string(from: trip.departureDate)) - \(Self.dateFormatter.string(from: trip.returnDate))")
                                .font(GAGATheme.captionFont)
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }

                    HStack(spacing: 24) {
                        Button(action: onLikeTap) {
                            Label {
                                Text("\(trip.likesCount)")
                                    .contentTransition(.numericText())
                            } icon: {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .symbolEffect(.bounce, value: isLiked)
                            }
                            .foregroundStyle(isLiked ? GAGATheme.coral : .white)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canInteract)
                        .sensoryFeedback(.impact(flexibility: .soft), trigger: isLiked)

                        Button(action: onCommentTap) {
                            Label("\(trip.commentsCount)", systemImage: "bubble.right")
                                .foregroundStyle(.white)
                                .contentTransition(.numericText())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canInteract)

                        Spacer()
                    }
                    .font(GAGATheme.bodyFont)
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                )
            }
        }
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.height > 0 {
                        dragOffset = value.translation.height
                    }
                }
                .onEnded { value in
                    if value.translation.height > 120 {
                        onDismiss()
                    } else {
                        withAnimation(.spring(duration: 0.3)) { dragOffset = 0 }
                    }
                }
        )
        .statusBarHidden()
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await uploadPhoto(item: newItem) }
        }
    }

    private func uploadPhoto(item: PhotosPickerItem) async {
        isUploading = true
        defer { isUploading = false }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }
        let service = TripService()
        guard let urlStr = try? await service.uploadLocationCoverImage(data, tripId: trip.id, locationId: location.id) else { return }
        var updated = trip
        updated.locationCoverImages[location.id] = urlStr
        try? await service.update(updated)
        tripStore.applyUpdate(updated)
    }
}
