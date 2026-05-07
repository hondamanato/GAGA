import SwiftUI
import MapboxMaps

struct SearchView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var store = SearchStore()
    @State private var selectedLocation: TappedLabel?
    @State private var selectedCategory: SearchCategory?

    private let suggestColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    private enum SearchCategory: String, CaseIterable, Identifiable {
        case beach = "ビーチ"
        case city = "都市"
        case nature = "自然"
        case food = "グルメ"

        var id: String { rawValue }
        var icon: String {
            switch self {
            case .beach: "sun.max.fill"
            case .city: "building.2.fill"
            case .nature: "leaf.fill"
            case .food: "fork.knife"
            }
        }

        // Simple keyword mapping for filtering
        var keywords: Set<String> {
            switch self {
            case .beach: ["ホノルル", "バリ", "バルセロナ", "シドニー", "マイアミ"]
            case .city: ["東京", "ニューヨーク", "パリ", "ロンドン", "ソウル", "上海", "シンガポール", "ドバイ", "香港", "ベルリン"]
            case .nature: ["バリ", "バンクーバー", "ウィーン", "プラハ"]
            case .food: ["東京", "大阪", "バンコク", "台北", "ハノイ", "ローマ", "京都"]
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if store.query.trimmingCharacters(in: .whitespaces).isEmpty {
                    suggestedSection
                } else {
                    resultsSection
                }
            }
            .searchable(text: Bindable(store).query, prompt: "ユーザー・国名・地名を検索")
            .onChange(of: store.query) {
                store.performSearch()
            }
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { userId in
                UserProfileView(userId: userId)
            }
            .sheet(item: $selectedLocation) { label in
                LocationPostsView(tappedLabel: label)
            }
        }
    }

    // MARK: - Hero画像マップ

    private static let heroAssets: [String: String] = [
        "日本": "hero-japan", "韓国": "hero-korea", "台湾": "hero-taiwan",
        "中国": "hero-china", "アメリカ": "hero-usa", "シンガポール": "hero-singapore",
        "タイ": "hero-thailand", "インドネシア": "hero-indonesia", "ベトナム": "hero-vietnam",
        "UAE": "hero-uae", "トルコ": "hero-turkey", "フランス": "hero-france",
        "イギリス": "hero-uk", "イタリア": "hero-italy", "スペイン": "hero-spain",
        "ドイツ": "hero-germany",
    ]

    private func spotImageURL(for city: Location) -> URL? {
        let token = MapboxOptions.accessToken
        return URL(string: "https://api.mapbox.com/styles/v1/mapbox/satellite-v9/static/\(city.longitude),\(city.latitude),10,0/400x300@2x?access_token=\(token)")
    }

    // MARK: - おすすめスポット

    private var filteredCities: [Location] {
        guard let cat = selectedCategory else { return CityCatalog.all }
        return CityCatalog.all.filter { cat.keywords.contains($0.name) }
    }

    private var suggestedSection: some View {
        VStack(alignment: .leading, spacing: GAGATheme.spacingMD) {
            // Category chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: GAGATheme.spacingSM) {
                    ForEach(SearchCategory.allCases) { cat in
                        Button {
                            withAnimation(GAGATheme.springSnappy) {
                                selectedCategory = selectedCategory == cat ? nil : cat
                            }
                        } label: {
                            Label(cat.rawValue, systemImage: cat.icon)
                                .font(GAGATheme.captionFont)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    selectedCategory == cat
                                        ? AnyShapeStyle(GAGATheme.accentGradient)
                                        : AnyShapeStyle(Color.gray.opacity(0.1)),
                                    in: Capsule()
                                )
                                .foregroundStyle(selectedCategory == cat ? .white : .primary)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, GAGATheme.spacingMD)
            }

            // Trending section
            VStack(alignment: .leading, spacing: GAGATheme.spacingSM) {
                Text("🔥 トレンド")
                    .font(GAGATheme.headlineFont)
                    .padding(.horizontal, GAGATheme.spacingMD)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(CityCatalog.all.prefix(8), id: \.name) { city in
                            Button {
                                selectedLocation = TappedLabel(
                                    name: city.name,
                                    isCountry: false,
                                    latitude: city.latitude,
                                    longitude: city.longitude
                                )
                            } label: {
                                trendingCard(for: city)
                            }
                            .buttonStyle(ScaleButtonStyle())
                        }
                    }
                    .padding(.horizontal, GAGATheme.spacingMD)
                }
            }

            // Spots grid
            VStack(alignment: .leading, spacing: GAGATheme.spacingSM) {
                Text("おすすめスポット")
                    .font(GAGATheme.headlineFont)
                    .padding(.horizontal, GAGATheme.spacingMD)

                LazyVGrid(columns: suggestColumns, spacing: 12) {
                    ForEach(filteredCities, id: \.name) { city in
                        Button {
                            selectedLocation = TappedLabel(
                                name: city.name,
                                isCountry: false,
                                latitude: city.latitude,
                                longitude: city.longitude
                            )
                        } label: {
                            spotCard(for: city)
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, GAGATheme.spacingMD)
            }
        }
        .padding(.top, GAGATheme.spacingSM)
    }

    private func trendingCard(for city: Location) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let asset = Self.heroAssets[city.country] {
                Image(asset)
                    .resizable()
                    .scaledToFill()
            } else {
                CachedAsyncImage(url: spotImageURL(for: city)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(.gray.opacity(0.15))
                }
            }

            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .center, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 2) {
                Text(flagEmoji(for: city.country))
                    .font(.title2)
                Text(city.name)
                    .font(GAGATheme.headlineFont)
                    .foregroundStyle(.white)
            }
            .padding(12)
        }
        .frame(width: 200, height: 140)
        .clipShape(RoundedRectangle(cornerRadius: GAGATheme.cardRadius))
    }

    private func spotCard(for city: Location) -> some View {
        ZStack(alignment: .bottomLeading) {
            // 背景画像
            GeometryReader { geo in
                if let asset = Self.heroAssets[city.country] {
                    Image(asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } else {
                    CachedAsyncImage(url: spotImageURL(for: city)) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(.gray.opacity(0.15))
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
                }
            }

            // グラデーション
            LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)

            // テキスト
            VStack(alignment: .leading, spacing: 2) {
                Text(flagEmoji(for: city.country))
                    .font(.title3)
                Text(city.name)
                    .font(GAGATheme.headlineFont)
                    .foregroundStyle(.white)
                Text(city.country)
                    .font(GAGATheme.captionFont)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(12)
        }
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: GAGATheme.cardRadius))
    }

    // MARK: - 検索結果

    private var resultsSection: some View {
        LazyVStack(alignment: .leading, spacing: 20) {
            if store.isSearching {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.top, 20)
            }

            if !store.userResults.isEmpty {
                usersSection
            }

            if !store.countryResults.isEmpty {
                countriesSection
            }

            if !store.locationResults.isEmpty {
                locationsSection
            }

            if !store.isSearching && store.userResults.isEmpty && store.countryResults.isEmpty && store.locationResults.isEmpty && store.query.count >= 2 {
                GAGAEmptyState(
                    icon: "magnifyingglass",
                    title: "検索結果なし",
                    description: "「\(store.query)」に一致する結果はありません"
                )
            }
        }
        .padding(.top, 8)
    }

    // MARK: - ユーザーセクション

    private var usersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ユーザー")
                .font(GAGATheme.headlineFont)
                .padding(.horizontal)

            ForEach(store.userResults) { user in
                NavigationLink(value: user.id) {
                    HStack(spacing: 12) {
                        GAGAAvatar(url: user.avatarURL, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(user.displayName)
                                .font(GAGATheme.bodyFont)
                                .fontWeight(.semibold)
                            if !user.bio.isEmpty {
                                Text(user.bio)
                                    .font(GAGATheme.captionFont)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
                .tint(.primary)
            }
        }
    }

    // MARK: - 国セクション

    private var countriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("国")
                .font(GAGATheme.headlineFont)
                .padding(.horizontal)

            ForEach(store.countryResults) { result in
                Button {
                    selectedLocation = TappedLabel(
                        name: result.name,
                        isCountry: true,
                        latitude: result.latitude,
                        longitude: result.longitude
                    )
                } label: {
                    HStack(spacing: 12) {
                        Text(flagEmoji(for: result.country))
                            .font(.title2)
                        Text(result.name)
                            .font(GAGATheme.bodyFont)
                            .fontWeight(.semibold)
                        Spacer()
                        if result.postCount > 0 {
                            Text("\(result.postCount)件")
                                .font(GAGATheme.captionFont)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - スポットセクション

    private var locationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("スポット")
                .font(GAGATheme.headlineFont)
                .padding(.horizontal)

            ForEach(store.locationResults) { result in
                Button {
                    selectedLocation = TappedLabel(
                        name: result.name,
                        isCountry: false,
                        latitude: result.latitude,
                        longitude: result.longitude
                    )
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundStyle(GAGATheme.coral)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name)
                                .font(GAGATheme.bodyFont)
                                .fontWeight(.semibold)
                            Text(result.country)
                                .font(GAGATheme.captionFont)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if result.postCount > 0 {
                            Text("\(result.postCount)件")
                                .font(GAGATheme.captionFont)
                                .foregroundStyle(.secondary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
