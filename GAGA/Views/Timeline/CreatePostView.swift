import SwiftUI
import PhotosUI
import Photos
import CoreLocation

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TripStore.self) private var tripStore
    @Environment(PostStore.self) private var postStore

    @State private var step = 0
    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var uiImage: UIImage?
    @State private var caption = ""
    @State private var location: Location = CityCatalog.all[0]
    @State private var selectedTripId: String?
    @State private var photoDate: Date?
    @State private var selectedDate: Date = .now
    @State private var autoLocationName: String?

    var initialTripId: String?
    var initialDate: Date?
    @State private var isPosting = false
    @State private var showSuccessToast: String?
    @State private var errorMessage: String?

    private var selectedTrip: Trip? {
        tripStore.trips.first { $0.id == selectedTripId }
    }

    private var canPost: Bool {
        imageData != nil && !isPosting && selectedTripId != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .ignoresSafeArea()
                        .blur(radius: 40)
                        .overlay(.black.opacity(0.4))
                } else {
                    GAGATheme.accentGradient
                        .opacity(0.15)
                        .ignoresSafeArea()
                }

                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        ForEach(0..<2, id: \.self) { i in
                            Capsule()
                                .fill(i <= step ? GAGATheme.coral : Color.gray.opacity(0.3))
                                .frame(height: 3)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 8)

                    if step == 0 {
                        photoStep
                            .transition(.push(from: .leading))
                    } else {
                        detailsStep
                            .transition(.push(from: .trailing))
                    }
                }
            }
            .animation(.spring(duration: 0.35), value: step)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .foregroundStyle(.primary)
                        .disabled(isPosting)
                }
                ToolbarItem(placement: .principal) {
                    Text(step == 0 ? LocalizedStringKey("写真を選ぶ") : LocalizedStringKey("詳細を入力"))
                        .font(GAGATheme.headlineFont)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if step == 0 {
                        Button("次へ") {
                            step = 1
                        }
                        .disabled(imageData == nil)
                        .fontWeight(.semibold)
                    } else {
                        Button("投稿") {
                            Task { await post() }
                        }
                        .disabled(!canPost)
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                if let initialTripId { selectedTripId = initialTripId }
                if let initialDate { selectedDate = initialDate }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task { await loadPhoto(newItem) }
            }
            .overlay {
                if isPosting {
                    ProgressView("アップロード中...")
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GAGATheme.cardRadius))
                }
            }
            .alert(
                "投稿に失敗しました",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .gagaToast($showSuccessToast)
            .sensoryFeedback(.success, trigger: showSuccessToast)
        }
    }

    // MARK: - Step 1: Photo Selection

    private var photoStep: some View {
        VStack(spacing: 24) {
            Spacer()

            PhotosPicker(selection: $pickerItem, matching: .images) {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.width * 1.1)
                        .clipShape(RoundedRectangle(cornerRadius: GAGATheme.cardRadius))
                        .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 48))
                            .foregroundStyle(GAGATheme.accentGradient)
                        Text("タップして写真を選択")
                            .font(GAGATheme.headlineFont)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.width * 1.1)
                    .background(.gray.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: GAGATheme.cardRadius))
                }
            }
            .padding(.horizontal, 20)

            if let photoDate {
                HStack(spacing: 6) {
                    Image(systemName: "camera")
                        .foregroundStyle(GAGATheme.coral)
                    Text(photoDate.formatted(date: .abbreviated, time: .shortened))
                        .font(GAGATheme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
    }

    // MARK: - Step 2: Details

    private var detailsStep: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let uiImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 20)
                }

                // Caption
                VStack(alignment: .leading, spacing: 8) {
                    Text("キャプション")
                        .font(GAGATheme.captionFont)
                        .foregroundStyle(.secondary)
                    TextField("旅の思い出を書きましょう", text: $caption, axis: .vertical)
                        .lineLimit(3...6)
                        .font(GAGATheme.bodyFont)
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)

                // Location
                VStack(alignment: .leading, spacing: 8) {
                    Text("場所")
                        .font(GAGATheme.captionFont)
                        .foregroundStyle(.secondary)

                    if let autoLocationName {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .foregroundStyle(GAGATheme.coral)
                            Text(autoLocationName)
                                .font(GAGATheme.captionFont)
                                .foregroundStyle(.secondary)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CityCatalog.all, id: \.self) { city in
                                Button {
                                    location = city
                                } label: {
                                    Text("\(flagEmoji(for: city.country)) \(city.name)")
                                        .font(GAGATheme.captionFont)
                                        .fontWeight(location == city ? .semibold : .regular)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            location == city
                                            ? AnyShapeStyle(GAGATheme.accentGradient)
                                            : AnyShapeStyle(Color.gray.opacity(0.15))
                                        )
                                        .foregroundStyle(location == city ? .white : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Trip selection (required)
                VStack(alignment: .leading, spacing: 8) {
                    Text("旅行プラン")
                        .font(GAGATheme.captionFont)
                        .foregroundStyle(.secondary)

                    if tripStore.trips.isEmpty {
                        Text("先に旅行プランを作成してください")
                            .font(GAGATheme.captionFont)
                            .foregroundStyle(.tertiary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tripStore.trips) { trip in
                                    Button {
                                        selectedTripId = trip.id
                                    } label: {
                                        Text(trip.title)
                                            .font(GAGATheme.captionFont)
                                            .fontWeight(selectedTripId == trip.id ? .semibold : .regular)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedTripId == trip.id
                                                ? AnyShapeStyle(GAGATheme.accentGradient)
                                                : AnyShapeStyle(Color.gray.opacity(0.15))
                                            )
                                            .foregroundStyle(selectedTripId == trip.id ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)

                // Date selection
                if let trip = selectedTrip {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("日付")
                            .font(GAGATheme.captionFont)
                            .foregroundStyle(.secondary)
                        DatePicker(
                            "日付",
                            selection: $selectedDate,
                            in: trip.departureDate...trip.returnDate,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .datePickerStyle(.compact)
                    }
                    .padding(.horizontal, 20)
                }

                // Back button
                Button {
                    step = 0
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("写真を変更")
                    }
                    .font(GAGATheme.captionFont)
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Actions

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        if let data = try? await item.loadTransferable(type: Data.self) {
            imageData = downsample(data, maxDimension: 1600)
            if let imageData {
                uiImage = UIImage(data: imageData)
            }
        }

        if let assetId = item.itemIdentifier {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
            if let asset = result.firstObject {
                if let date = asset.creationDate {
                    photoDate = date
                    selectedDate = date
                }
                if let coordinate = asset.location?.coordinate,
                   CLLocationCoordinate2DIsValid(coordinate) {
                    location = findNearestCity(to: coordinate)
                    reverseGeocode(coordinate)
                }
            }
        }
    }

    private func post() async {
        guard let uid = authViewModel.firebaseUID,
              let data = imageData,
              let tripId = selectedTripId else { return }
        isPosting = true
        defer { isPosting = false }
        do {
            try await postStore.create(
                imageData: data,
                userId: uid,
                tripId: tripId,
                location: location,
                caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
                createdAt: photoDate ?? selectedDate
            )
            showSuccessToast = String(localized: "投稿しました ✈️")
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func downsample(_ data: Data, maxDimension: CGFloat) -> Data {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let scale = min(1, maxDimension / max(size.width, size.height))
        if scale >= 1 {
            return image.jpegData(compressionQuality: 0.8) ?? data
        }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.8) ?? data
    }

    private func findNearestCity(to coordinate: CLLocationCoordinate2D) -> Location {
        let photoLoc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        var best = CityCatalog.all[0]
        var bestDist = Double.greatestFiniteMagnitude
        for city in CityCatalog.all {
            let cityLoc = CLLocation(latitude: city.latitude, longitude: city.longitude)
            let d = photoLoc.distance(from: cityLoc)
            if d < bestDist {
                bestDist = d
                best = city
            }
        }
        return best
    }

    private func reverseGeocode(_ coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let clLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        geocoder.reverseGeocodeLocation(clLocation) { placemarks, _ in
            if let pm = placemarks?.first {
                let parts = [pm.locality, pm.administrativeArea, pm.country].compactMap { $0 }
                if !parts.isEmpty {
                    autoLocationName = parts.joined(separator: ", ")
                }
            }
        }
    }
}

#Preview {
    CreatePostView(initialTripId: "test")
        .environment(AuthViewModel())
        .environment(TripStore())
        .environment(PostStore())
}
