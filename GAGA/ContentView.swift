//
//  ContentView.swift
//  GAGA
//
//  Created by 本多真翔 on 2026/04/09.
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(TripStore.self) private var tripStore
    @Environment(PostStore.self) private var postStore
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Globe", systemImage: "globe.americas.fill", value: 0) {
                GlobeView()
            }

            Tab("タイムライン", systemImage: "text.line.first.and.arrowtriangle.forward", value: 1) {
                TimelineView()
            }

            Tab("旅行", systemImage: "airplane", value: 2) {
                TripListView()
            }

            Tab("プロフィール", systemImage: "person.fill", value: 3) {
                ProfileView()
            }
        }
        .tint(.blue)
        .task(id: authViewModel.firebaseUID) {
            await tripStore.load(userId: authViewModel.firebaseUID)
            await postStore.loadTimeline(currentUserId: authViewModel.firebaseUID)
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
        .environment(TripStore())
        .environment(PostStore())
}
