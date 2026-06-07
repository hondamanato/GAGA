import SwiftUI
import MapKit

struct CreateTripView: View {
    var editingTrip: Trip?

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TripStore.self) private var tripStore

    @State private var title = ""
    @State private var origin: Location = CityCatalog.all[0]
    @State private var destinations: [Location] = []
    @State private var departureDate: Date? = Calendar.current.startOfDay(for: .now)
    @State private var returnDate: Date? = Calendar.current.startOfDay(for: .now).addingTimeInterval(86400 * 7)
    @State private var showCalendar = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var pickerTarget: PickerTarget?
    @State private var didLoadEditing = false

    private var isEditing: Bool { editingTrip != nil }

    private var numberOfDays: Int {
        guard let dep = departureDate, let ret = returnDate else { return 1 }
        let cal = Calendar.current
        let days = (cal.dateComponents([.day], from: cal.startOfDay(for: dep), to: cal.startOfDay(for: ret)).day ?? 0) + 1
        return max(days, 1)
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !destinations.isEmpty
            && departureDate != nil
            && returnDate != nil
            && !isSaving
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 旅行タイトル
                    VStack(alignment: .leading, spacing: 8) {
                        Text("旅行タイトル")
                            .font(GAGATheme.captionFont)
                            .foregroundStyle(.secondary)
                        TextField("例: パリ一人旅", text: $title)
                            .font(GAGATheme.bodyFont)
                            .padding(14)
                            .background(.gray.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // 日程
                    VStack(alignment: .leading, spacing: 8) {
                        Text("日程")
                            .font(GAGATheme.captionFont)
                            .foregroundStyle(.secondary)
                        Button {
                            showCalendar = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("出発日")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(departureDate.map { formatDateJP($0) } ?? String(localized: "未設定"))
                                        .font(GAGATheme.headlineFont)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("帰国日")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    Text(returnDate.map { formatDateJP($0) } ?? String(localized: "未設定"))
                                        .font(GAGATheme.headlineFont)
                                }
                            }
                            .padding(14)
                            .background(.gray.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)

                        if departureDate != nil && returnDate != nil {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(GAGATheme.coral)
                                Text("\(numberOfDays)日間の旅")
                                    .font(GAGATheme.headlineFont)
                                    .contentTransition(.numericText())
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(GAGATheme.coral.opacity(0.1))
                            .clipShape(Capsule())
                            .animation(.spring(duration: 0.3), value: numberOfDays)
                        }
                    }

                    // 出発地
                    VStack(alignment: .leading, spacing: 8) {
                        Text("出発地")
                            .font(GAGATheme.captionFont)
                            .foregroundStyle(.secondary)
                        Button {
                            pickerTarget = .origin
                        } label: {
                            HStack {
                                Text("\(flagEmoji(for: origin.country)) \(origin.name)")
                                    .font(GAGATheme.bodyFont)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(.gray.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    // 目的地
                    VStack(alignment: .leading, spacing: 8) {
                        Text("目的地")
                            .font(GAGATheme.captionFont)
                            .foregroundStyle(.secondary)

                        ForEach(destinations, id: \.self) { dest in
                            HStack {
                                Text("\(flagEmoji(for: dest.country)) \(dest.name)")
                                    .font(GAGATheme.bodyFont)
                                Spacer()
                                Button {
                                    destinations.removeAll { $0 == dest }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.gray.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        Button {
                            pickerTarget = .destinationNew
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(GAGATheme.coral)
                                Text(destinations.isEmpty ? LocalizedStringKey("目的地を追加") : LocalizedStringKey("他の場所を追加"))
                                    .font(GAGATheme.bodyFont)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(.gray.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .navigationTitle(isEditing ? LocalizedStringKey("旅行を編集") : LocalizedStringKey("旅行を作成"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? LocalizedStringKey("更新") : LocalizedStringKey("作成")) {
                        Task { await save() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
            .sheet(isPresented: $showCalendar) {
                CalendarRangePickerView(startDate: departureDate, endDate: returnDate) { start, end in
                    departureDate = start
                    returnDate = end
                }
                .presentationCornerRadius(24)
            }
            .sheet(item: $pickerTarget) { target in
                LocationPickerSheet { location in
                    apply(location, to: target)
                }
                .presentationCornerRadius(24)
            }
            .overlay {
                if isSaving {
                    ProgressView()
                        .padding(24)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: GAGATheme.cardRadius))
                }
            }
            .alert(
                "保存に失敗しました",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .onAppear {
                guard let trip = editingTrip, !didLoadEditing else { return }
                didLoadEditing = true
                title = trip.title
                origin = trip.origin
                destinations = trip.destinations
                departureDate = trip.departureDate
                returnDate = trip.returnDate
            }
        }
    }

    // MARK: - Helpers

    private func apply(_ location: Location, to target: PickerTarget) {
        switch target {
        case .origin:
            origin = location
        case .destinationNew:
            destinations.append(location)
        case .destination(let index):
            guard destinations.indices.contains(index) else { return }
            destinations[index] = location
        }
    }

    private func formatDateJP(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.setLocalizedDateFormatFromTemplate("MMMd")
        return f.string(from: date)
    }

    private func save() async {
        guard let uid = authViewModel.firebaseUID else {
            errorMessage = String(localized: "サインインが必要です")
            return
        }
        guard let dep = departureDate, let ret = returnDate else {
            errorMessage = String(localized: "日程を設定してください")
            return
        }
        isSaving = true
        defer { isSaving = false }

        let trip: Trip
        if let existing = editingTrip {
            trip = Trip(
                id: existing.id,
                userId: existing.userId,
                title: title.trimmingCharacters(in: .whitespaces),
                origin: origin,
                destinations: destinations,
                departureDate: dep,
                returnDate: ret,
                status: existing.status,
                schedule: existing.schedule,
                coverImageURL: existing.coverImageURL,
                likesCount: existing.likesCount,
                commentsCount: existing.commentsCount,
                createdAt: existing.createdAt
            )
        } else {
            trip = Trip(
                userId: uid,
                title: title.trimmingCharacters(in: .whitespaces),
                origin: origin,
                destinations: destinations,
                departureDate: dep,
                returnDate: ret
            )
        }

        do {
            if isEditing {
                try await TripService().update(trip)
                tripStore.applyUpdate(trip)
            } else {
                try await TripService().create(trip)
            }
            await tripStore.load(userId: uid)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Picker Types

private enum PickerTarget: Identifiable {
    case origin
    case destinationNew
    case destination(Int)

    var id: String {
        switch self {
        case .origin: "origin"
        case .destinationNew: "new"
        case .destination(let i): "dest-\(i)"
        }
    }
}

struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var searchResults: [Location] = []
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?
    let onSelect: (Location) -> Void

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private func kanaPrefix(_ text: String, _ prefix: String) -> Bool {
        let t = text.applyingTransform(.hiraganaToKatakana, reverse: false) ?? text
        let p = prefix.applyingTransform(.hiraganaToKatakana, reverse: false) ?? prefix
        return t.hasPrefix(p)
    }

    private var localFiltered: [Location] {
        guard !trimmedQuery.isEmpty else { return CityCatalog.all }
        let q = trimmedQuery
        let countries = CityCatalog.countries.filter {
            kanaPrefix($0.name, q)
        }
        let cities = CityCatalog.all.filter {
            kanaPrefix($0.name, q) || kanaPrefix($0.country, q)
        }
        return countries + cities
    }

    private var displayResults: [Location] {
        if trimmedQuery.isEmpty {
            return CityCatalog.all
        }
        var seen: Set<String> = []
        var merged: [Location] = []
        for loc in localFiltered + searchResults {
            let key = "\(loc.name)-\(loc.country)"
            if seen.insert(key).inserted {
                merged.append(loc)
            }
        }
        return merged
    }

    var body: some View {
        NavigationStack {
            List {
                if !trimmedQuery.isEmpty && displayResults.isEmpty && !isSearching {
                    ContentUnavailableView.search(text: trimmedQuery)
                }

                ForEach(displayResults, id: \.self) { city in
                    Button {
                        onSelect(city)
                        dismiss()
                    } label: {
                        HStack {
                            Text(flagEmoji(for: city.country))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(city.name)
                                    .font(GAGATheme.bodyFont)
                                    .foregroundStyle(.primary)
                                Text(city.country)
                                    .font(GAGATheme.captionFont)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }
            }
            .searchable(text: $query, prompt: "都市名または国名で検索")
            .navigationTitle("場所を選ぶ")
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
        request.resultTypes = .address

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            guard !Task.isCancelled else { return }
            searchResults = response.mapItems.compactMap { item in
                guard let name = item.placemark.locality ?? item.placemark.name else { return nil }
                let country = item.placemark.country ?? ""
                let coord = item.placemark.coordinate
                return Location(name: name, country: country, latitude: coord.latitude, longitude: coord.longitude)
            }
            var seen: Set<String> = []
            searchResults = searchResults.filter { loc in
                seen.insert("\(loc.name)-\(loc.country)").inserted
            }
        } catch {
            if !Task.isCancelled {
                searchResults = []
            }
        }
    }
}

#Preview {
    CreateTripView()
        .environment(AuthViewModel())
        .environment(TripStore())
}
