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
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @State private var authViewModel: AuthViewModel
    @State private var tripStore: TripStore
    @State private var postStore: PostStore
    @State private var notificationStore: NotificationStore

    init() {
        FirebaseApp.configure()
        MapboxOptions.accessToken = Bundle.main.infoDictionary?["MapboxAccessToken"] as? String ?? ""

        // Firebase configure 後に Store を生成する必要あり。
        // デフォルト値で @State を初期化すると init() body より先に評価され、
        // TripStore/PostStore 経由で Firestore に触れて NSException で起動クラッシュする。
        _authViewModel = State(wrappedValue: AuthViewModel())
        _tripStore = State(wrappedValue: TripStore())
        _postStore = State(wrappedValue: PostStore())
        _notificationStore = State(wrappedValue: NotificationStore())
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isLoggedIn {
                    if authViewModel.needsProfileSetup {
                        SetupProfileView()
                    } else {
                        ContentView()
                    }
                } else {
                    LoginView()
                }
            }
            .environment(authViewModel)
            .environment(tripStore)
            .environment(postStore)
            .environment(notificationStore)
            .task {
                authViewModel.start()
            }
        }
    }
}
