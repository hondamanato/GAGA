import SwiftUI

struct TripMenuSheet: View {
    let trip: Trip
    @State private var showEditTrip = false

    var body: some View {
        NavigationStack {
            List {
                Section("基本情報") {
                    LabeledContent("出発地", value: trip.origin.name)
                    LabeledContent("行き先", value: trip.destinations.map(\.name).joined(separator: ", "))
                    LabeledContent("出発日", value: trip.departureDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("帰国日", value: trip.returnDate.formatted(date: .abbreviated, time: .omitted))
                    LabeledContent("ステータス", value: trip.status.rawValue)

                    Button {
                        showEditTrip = true
                    } label: {
                        Label("旅行を編集", systemImage: "pencil")
                    }
                }

                Section("スケジュール") {
                    if trip.schedule.isEmpty {
                        GAGAEmptyState(
                            icon: "calendar.badge.plus",
                            title: "スケジュール未登録",
                            description: "日程ごとの予定を追加しましょう"
                        )
                    } else {
                        ForEach(trip.schedule) { day in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(day.date.formatted(date: .abbreviated, time: .omitted))
                                    .fontWeight(.semibold)
                                ForEach(day.spots, id: \.self) { spot in
                                    Label(spot, systemImage: "mappin")
                                        .font(.subheadline)
                                }
                                if !day.notes.isEmpty {
                                    Text(day.notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle(trip.title)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showEditTrip) {
                CreateTripView(editingTrip: trip)
            }
        }
        .presentationDetents([.medium, .large])
    }
}
