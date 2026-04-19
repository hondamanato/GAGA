import SwiftUI
import MapboxMaps

struct LocationPostsView: View {
    let tappedLabel: TappedLabel

    @Environment(\.dismiss) private var dismiss
    @State private var posts: [Post] = []
    @State private var isLoading = true

    static let heroAssets: [String: String] = [
        "日本": "hero-japan",
        "Japan": "hero-japan",
        "韓国": "hero-korea",
        "South Korea": "hero-korea",
        "台湾": "hero-taiwan",
        "Taiwan": "hero-taiwan",
        "中国": "hero-china",
        "China": "hero-china",
        "アメリカ": "hero-usa",
        "アメリカ合衆国": "hero-usa",
        "United States": "hero-usa",
        "United States of America": "hero-usa",
        "US": "hero-usa",
        "USA": "hero-usa",
        "シンガポール": "hero-singapore",
        "Singapore": "hero-singapore",
        "タイ": "hero-thailand",
        "Thailand": "hero-thailand",
        "インドネシア": "hero-indonesia",
        "Indonesia": "hero-indonesia",
        "ベトナム": "hero-vietnam",
        "Vietnam": "hero-vietnam",
        "UAE": "hero-uae",
        "United Arab Emirates": "hero-uae",
        "アラブ首長国連邦": "hero-uae",
        "トルコ": "hero-turkey",
        "Turkey": "hero-turkey",
        "Türkiye": "hero-turkey",
        "フランス": "hero-france",
        "France": "hero-france",
        "イギリス": "hero-uk",
        "United Kingdom": "hero-uk",
        "イタリア": "hero-italy",
        "Italy": "hero-italy",
        "スペイン": "hero-spain",
        "Spain": "hero-spain",
        "ドイツ": "hero-germany",
        "Germany": "hero-germany",
    ]

    private var heroAssetName: String? {
        Self.heroAssets[tappedLabel.name]
    }

    private var heroFallbackURL: URL? {
        let zoom = tappedLabel.isCountry ? 4 : 10
        let token = MapboxOptions.accessToken
        let lon = tappedLabel.longitude
        let lat = tappedLabel.latitude
        return URL(string: "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/\(lon),\(lat),\(zoom),0/800x1200@2x?access_token=\(token)")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                heroBackground
                content
            }
            .navigationTitle(tappedLabel.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task { await load() }
        }
    }

    // MARK: - Background

    @ViewBuilder
    private func heroImage(fitting size: CGSize) -> some View {
        if let asset = heroAssetName {
            Image(asset)
                .resizable()
                .scaledToFill()
                .frame(width: size.width, height: size.height)
                .clipped()
        } else {
            CachedAsyncImage(url: heroFallbackURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.black
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    private var heroBackground: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                // シャープなレイヤー（上部に表示）
                heroImage(fitting: size)

                // ぼかしレイヤー（下に行くほど濃くなる）
                heroImage(fitting: size)
                    .blur(radius: 40)
                    .mask(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0),
                                .init(color: .clear, location: 0.25),
                                .init(color: .black, location: 0.6),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // 暗めのグラデーション（テキスト可読性）
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.1), location: 0),
                        .init(color: .black.opacity(0.6), location: 0.5),
                        .init(color: .black.opacity(0.85), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView()
                .tint(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if posts.isEmpty {
            ContentUnavailableView {
                Label("投稿がまだありません", systemImage: "photo.on.rectangle.angled")
                    .foregroundStyle(.white)
            } description: {
                Text("\(tappedLabel.name)の投稿はまだありません")
                    .foregroundStyle(.white.opacity(0.7))
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(posts) { post in
                        LocationPostCard(post: post)
                    }
                }
                .padding()
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let service = PostService()
        do {
            if tappedLabel.isCountry {
                posts = try await service.fetchPosts(country: tappedLabel.name)
            } else {
                posts = try await service.fetchPosts(locationName: tappedLabel.name)
            }
        } catch {
            posts = []
        }
    }
}

// MARK: - Post Card

private struct LocationPostCard: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(.white.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.caption)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.location.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                    Text(post.createdAt.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
            }

            CachedAsyncImage(url: URL(string: post.imageURL)) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
                    .tint(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 240)
                    .background(.white.opacity(0.1))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 240)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.9))
            }

            HStack(spacing: 6) {
                Image(systemName: "mappin")
                Text(post.location.name)
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding()
        .background(.ultraThinMaterial.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
    }
}
