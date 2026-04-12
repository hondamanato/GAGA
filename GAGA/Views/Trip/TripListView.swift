import SwiftUI

struct TripListView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TripStore.self) private var tripStore
    @State private var showCreateTrip = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("旅行")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCreateTrip = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .disabled(authViewModel.firebaseUID == nil)
                    }
                }
                .sheet(isPresented: $showCreateTrip) {
                    CreateTripView()
                        .environment(authViewModel)
                        .environment(tripStore)
                }
                .refreshable {
                    await tripStore.load(userId: authViewModel.firebaseUID)
                }
                .alert(
                    "読み込みに失敗しました",
                    isPresented: Binding(
                        get: { tripStore.errorMessage != nil },
                        set: { if !$0 { tripStore.errorMessage = nil } }
                    )
                ) {
                    Button("OK", role: .cancel) { tripStore.errorMessage = nil }
                } message: {
                    Text(tripStore.errorMessage ?? "")
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if tripStore.isLoading && tripStore.trips.isEmpty {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if tripStore.trips.isEmpty {
            ContentUnavailableView(
                "旅行がまだありません",
                systemImage: "airplane",
                description: Text("右上の + から最初の旅行を作成しましょう")
            )
        } else {
            List {
                ForEach(tripStore.trips) { trip in
                    NavigationLink(destination: TripDetailView(trip: trip)) {
                        TripRow(trip: trip)
                    }
                }
                .onDelete { offsets in
                    guard let uid = authViewModel.firebaseUID else { return }
                    Task { await tripStore.delete(at: offsets, userId: uid) }
                }
            }
            .listStyle(.plain)
        }
    }
}

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "airplane.departure")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(trip.title)
                    .fontWeight(.semibold)
                Text(trip.destinations.map(\.name).joined(separator: " → "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(trip.status.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor(trip.status).opacity(0.15))
                    .foregroundStyle(statusColor(trip.status))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .planning: .orange
        case .traveling: .green
        case .completed: .blue
        }
    }
}

#Preview {
    TripListView()
        .environment(AuthViewModel())
        .environment(TripStore())
}
