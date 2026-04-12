import SwiftUI

struct CreateTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TripStore.self) private var tripStore

    @State private var title = ""
    @State private var origin: Location = CityCatalog.all[0]
    @State private var destinations: [Location] = [CityCatalog.all[13]]
    @State private var departureDate = Date.now
    @State private var returnDate = Date.now.addingTimeInterval(86400 * 7)
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var pickerTarget: PickerTarget?

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !destinations.isEmpty
            && departureDate <= returnDate
            && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("旅行タイトル") {
                    TextField("例: パリ一人旅", text: $title)
                }

                Section("出発地") {
                    Button {
                        pickerTarget = .origin
                    } label: {
                        locationRow(origin)
                    }
                    .buttonStyle(.plain)
                }

                Section("目的地") {
                    ForEach(destinations.indices, id: \.self) { index in
                        Button {
                            pickerTarget = .destination(index)
                        } label: {
                            locationRow(destinations[index])
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in
                        destinations.remove(atOffsets: offsets)
                    }

                    Button {
                        pickerTarget = .destinationNew
                    } label: {
                        Label("目的地を追加", systemImage: "plus.circle.fill")
                    }
                }

                Section("日程") {
                    DatePicker("出発日", selection: $departureDate, displayedComponents: .date)
                    DatePicker("帰国日", selection: $returnDate, in: departureDate..., displayedComponents: .date)
                }
            }
            .navigationTitle("旅行を作成")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("作成") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
            .sheet(item: $pickerTarget) { target in
                LocationPickerSheet { location in
                    apply(location, to: target)
                }
            }
            .overlay {
                if isSaving {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.5)
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
        }
    }

    @ViewBuilder
    private func locationRow(_ location: Location) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .foregroundStyle(.primary)
                if !location.country.isEmpty {
                    Text(location.country)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

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

    private func save() async {
        guard let uid = authViewModel.firebaseUID else {
            errorMessage = "サインインが必要です"
            return
        }
        isSaving = true
        defer { isSaving = false }

        let trip = Trip(
            userId: uid,
            title: title.trimmingCharacters(in: .whitespaces),
            origin: origin,
            destinations: destinations,
            departureDate: departureDate,
            returnDate: returnDate
        )

        do {
            try await TripService().create(trip)
            await tripStore.load(userId: uid)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

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

private struct LocationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    let onSelect: (Location) -> Void

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespaces)
    }

    private var filtered: [Location] {
        guard !trimmedQuery.isEmpty else { return CityCatalog.all }
        return CityCatalog.all.filter {
            $0.name.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.country.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var showCustomAdd: Bool {
        !trimmedQuery.isEmpty
            && !filtered.contains { $0.name.caseInsensitiveCompare(trimmedQuery) == .orderedSame }
    }

    var body: some View {
        NavigationStack {
            List {
                if showCustomAdd {
                    Button {
                        let custom = Location(
                            name: trimmedQuery,
                            country: "",
                            latitude: 0,
                            longitude: 0
                        )
                        onSelect(custom)
                        dismiss()
                    } label: {
                        Label("「\(trimmedQuery)」を追加", systemImage: "plus.circle.fill")
                    }
                }

                ForEach(filtered, id: \.self) { city in
                    Button {
                        onSelect(city)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(city.name)
                                .foregroundStyle(.primary)
                            Text(city.country)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
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
        }
    }
}

#Preview {
    CreateTripView()
        .environment(AuthViewModel())
        .environment(TripStore())
}
