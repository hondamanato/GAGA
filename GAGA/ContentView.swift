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
    @Environment(NotificationStore.self) private var notificationStore
    @State private var selectedTab = 0
    @AppStorage("app_theme") private var appTheme = 0

    private var colorScheme: ColorScheme? {
        switch appTheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

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

            Tab(value: 3) {
                NotificationListView()
            } label: {
                Label("通知", systemImage: "bell.fill")
                    .badge(notificationStore.unreadCount)
            }

            Tab("検索", systemImage: "magnifyingglass", value: 4) {
                SearchView()
            }

            Tab("プロフィール", systemImage: "person.fill", value: 5) {
                ProfileView()
            }
        }
        .preferredColorScheme(colorScheme)
        .tint(GAGATheme.coral)
        .task(id: authViewModel.firebaseUID) {
            tripStore.startListening(userId: authViewModel.firebaseUID)
            notificationStore.startListening(userId: authViewModel.firebaseUID)
        }
    }
}

#Preview {
    ContentView()
        .environment(AuthViewModel())
        .environment(TripStore())
        .environment(PostStore())
        .environment(NotificationStore())
}
