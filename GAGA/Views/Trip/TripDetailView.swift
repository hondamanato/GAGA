import SwiftUI

struct TripDetailView: View {
    let trip: Trip

    var body: some View {
        List {
            Section("基本情報") {
                LabeledContent("出発地", value: trip.origin.name)
                LabeledContent("行き先", value: trip.destinations.map(\.name).joined(separator: ", "))
                LabeledContent("出発日", value: trip.departureDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("帰国日", value: trip.returnDate.formatted(date: .abbreviated, time: .omitted))
                LabeledContent("ステータス", value: trip.status.rawValue)
            }

            Section("スケジュール") {
                if trip.schedule.isEmpty {
                    ContentUnavailableView("スケジュール未登録", systemImage: "calendar.badge.plus", description: Text("日程ごとの予定を追加しましょう"))
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

            Section("持ち物チェックリスト") {
                NavigationLink("チェックリストを見る") {
                    ChecklistView(tripId: trip.id, destinations: trip.destinations)
                }
            }
        }
        .navigationTitle(trip.title)
    }
}
