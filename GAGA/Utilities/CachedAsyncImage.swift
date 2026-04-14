import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var image: UIImage?
    @State private var isLoading = false

    private static var cache: URLCache {
        let cache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )
        return cache
    }

    var body: some View {
        if let image {
            content(Image(uiImage: image))
        } else {
            placeholder()
                .task(id: url) {
                    await loadImage()
                }
        }
    }

    private func loadImage() async {
        guard let url, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let request = URLRequest(url: url)

        if let cached = Self.cache.cachedResponse(for: request),
           let uiImage = UIImage(data: cached.data) {
            self.image = uiImage
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let uiImage = UIImage(data: data) {
                let cachedResponse = CachedURLResponse(response: response, data: data)
                Self.cache.storeCachedResponse(cachedResponse, for: request)
                self.image = uiImage
            }
        } catch {
            // 読み込み失敗時は placeholder のまま
        }
    }
}
