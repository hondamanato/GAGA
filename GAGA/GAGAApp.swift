//
//  GAGAApp.swift
//  GAGA
//
//  Created by 本多真翔 on 2026/04/09.
//

import SwiftUI
import FirebaseCore
import MapboxMaps

@main
struct GAGAApp: App {
    @State private var authViewModel: AuthViewModel
    @State private var tripStore: TripStore
    @State private var postStore: PostStore

    init() {
        FirebaseApp.configure()
        MapboxOptions.accessToken = "MAPBOX_TOKEN_REMOVED"

        // Firebase configure 後に Store を生成する必要あり。
        // デフォルト値で @State を初期化すると init() body より先に評価され、
        // TripStore/PostStore 経由で Firestore に触れて NSException で起動クラッシュする。
        _authViewModel = State(wrappedValue: AuthViewModel())
        _tripStore = State(wrappedValue: TripStore())
        _postStore = State(wrappedValue: PostStore())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isLoggedIn {
                    ContentView()
                } else {
                    LoginView()
                }
            }
            .environment(authViewModel)
            .environment(tripStore)
            .environment(postStore)
            .task {
                authViewModel.start()
            }
        }
    }
}
