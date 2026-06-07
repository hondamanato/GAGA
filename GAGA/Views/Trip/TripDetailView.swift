import SwiftUI

struct TripDetailView: View {
    let trip: Trip

    var body: some View {
        TripJournalView(initialTrip: trip)
    }
}
