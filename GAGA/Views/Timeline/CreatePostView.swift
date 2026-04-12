import SwiftUI
import PhotosUI

struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TripStore.self) private var tripStore
    @Environment(PostStore.self) private var postStore

    @State private var pickerItem: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var caption = ""
    @State private var location: Location = CityCatalog.all[0]
    @State private var selectedTripId: String?
    @State private var isPosting = false
    @State private var errorMessage: String?

    private var canPost: Bool {
        imageData != nil && !isPosting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("写真") {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        if let imageData, let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .frame(height: 240)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("写真を選択")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(.gray.opacity(0.15))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                Section("キャプション") {
                    TextField("旅の思い出を書きましょう", text: $caption, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("場所") {
                    Picker("場所", selection: $location) {
                        ForEach(CityCatalog.all, id: \.self) { city in
                            Text("\(city.name) (\(city.country))").tag(city)
                        }
                    }
                }

                if !tripStore.trips.isEmpty {
                    Section("旅行に紐付け (任意)") {
                        Picker("旅行", selection: $selectedTripId) {
                            Text("紐付けなし").tag(String?.none)
                            ForEach(tripStore.trips) { trip in
                                Text(trip.title).tag(String?.some(trip.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("投稿を作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .disabled(isPosting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("投稿") {
                        Task { await post() }
                    }
                    .disabled(!canPost)
                }
            }
            .overlay {
                if isPosting {
                    ProgressView("アップロード中...")
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .onChange(of: pickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        imageData = downsample(data, maxDimension: 1600)
                    }
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
        }
    }

    private func post() async {
        guard let uid = authViewModel.firebaseUID, let data = imageData else { return }
        isPosting = true
        defer { isPosting = false }
        do {
            try await postStore.create(
                imageData: data,
                userId: uid,
                tripId: selectedTripId,
                location: location,
                caption: caption.trimmingCharacters(in: .whitespacesAndNewlines)
            )
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
}

#Preview {
    CreatePostView()
        .environment(AuthViewModel())
        .environment(TripStore())
        .environment(PostStore())
}
