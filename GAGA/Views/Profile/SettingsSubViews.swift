import SwiftUI
import FirebaseAuth

// MARK: - アカウント

struct EditProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var displayName = ""
    @State private var bio = ""
    @State private var isSaving = false
    @State private var showSaved = false

    var body: some View {
        Form {
            Section("表示名") {
                TextField("名前を入力", text: $displayName)
                    .font(GAGATheme.bodyFont)
            }
            Section("自己紹介") {
                TextField("自己紹介を入力", text: $bio, axis: .vertical)
                    .font(GAGATheme.bodyFont)
                    .lineLimit(3...6)
            }
        }
        .navigationTitle("プロフィール編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task {
                        isSaving = true
                        await authViewModel.updateProfile(displayName: displayName, bio: bio)
                        isSaving = false
                        showSaved = true
                    }
                }
                .disabled(isSaving || displayName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .overlay {
            if showSaved {
                savedToast
            }
        }
        .onAppear {
            if let user = authViewModel.currentUser {
                displayName = user.displayName
                bio = user.bio
            }
        }
    }

    private var savedToast: some View {
        Text("保存しました")
            .font(GAGATheme.bodyFont)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Capsule().fill(.green))
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation { showSaved = false }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.top, 8)
    }
}

struct AccountSettingsView: View {
    var body: some View {
        Form {
            Section("認証方法") {
                HStack {
                    Label("Apple ID", systemImage: "apple.logo")
                    Spacer()
                    Text("連携済み")
                        .foregroundStyle(.secondary)
                }
            }
            Section("メールアドレス") {
                HStack {
                    Text(Auth.auth().currentUser?.email ?? "未設定")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("アカウント")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LinkedAccountsView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "apple.logo")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Apple ID")
                            .font(GAGATheme.bodyFont)
                            .fontWeight(.semibold)
                        Text("サインインに使用中")
                            .font(GAGATheme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } footer: {
                Text("Apple IDでサインインしています。")
            }
        }
        .navigationTitle("連携アカウント")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 通知

struct PushNotificationSettingsView: View {
    @AppStorage("notif_likes") private var likes = true
    @AppStorage("notif_comments") private var comments = true
    @AppStorage("notif_follows") private var follows = true
    @AppStorage("notif_trips") private var trips = true

    var body: some View {
        Form {
            Section("アクティビティ") {
                Toggle("いいね", isOn: $likes)
                Toggle("コメント", isOn: $comments)
                Toggle("新しいフォロワー", isOn: $follows)
            }
            Section("旅行") {
                Toggle("旅行リマインダー", isOn: $trips)
            }
        }
        .navigationTitle("プッシュ通知")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EmailNotificationSettingsView: View {
    @AppStorage("email_newsletter") private var newsletter = true
    @AppStorage("email_activity") private var activity = true

    var body: some View {
        Form {
            Section {
                Toggle("ニュースレター", isOn: $newsletter)
                Toggle("アクティビティ通知", isOn: $activity)
            } footer: {
                Text("メール通知の設定を変更できます。")
            }
        }
        .navigationTitle("メール通知")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - プライバシーとセキュリティ

struct PrivacySettingsView: View {
    @AppStorage("privacy_private_account") private var isPrivate = false
    @AppStorage("privacy_activity_status") private var showActivity = true

    var body: some View {
        Form {
            Section {
                Toggle("非公開アカウント", isOn: $isPrivate)
            } footer: {
                Text("非公開にすると、承認したユーザーのみが投稿を閲覧できます。")
            }
            Section {
                Toggle("アクティビティステータスを表示", isOn: $showActivity)
            } footer: {
                Text("オンにすると、他のユーザーにオンライン状態が表示されます。")
            }
        }
        .navigationTitle("プライバシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BlockedUsersView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var blockedUsers: [AppUser] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let service = UserService()

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if blockedUsers.isEmpty {
                GAGAEmptyState(
                    icon: "person.fill.xmark",
                    title: "ブロックしたユーザーはいません",
                    description: "ブロックしたユーザーはここに表示されます"
                )
            } else {
                List {
                    ForEach(blockedUsers) { user in
                        HStack {
                            GAGAAvatar(url: user.avatarURL, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(user.displayName)
                                    .font(GAGATheme.bodyFont)
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                            Button("解除") {
                                Task { await unblock(user: user) }
                            }
                            .font(GAGATheme.captionFont)
                            .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("ブロックしたユーザー")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadBlocked() }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func loadBlocked() async {
        guard let uid = authViewModel.firebaseUID else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            blockedUsers = try await service.fetchBlockedUsers(userId: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func unblock(user: AppUser) async {
        guard let uid = authViewModel.firebaseUID else { return }
        do {
            try await service.unblockUser(currentUserId: uid, targetUserId: user.id)
            blockedUsers.removeAll { $0.id == user.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct LocationSettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Label("位置情報の利用", systemImage: "location.fill")
                    Spacer()
                    Text("使用中のみ")
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("位置情報は投稿や旅行の記録に使用されます。")
            }
            Section {
                Button("設定アプリで変更") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } footer: {
                Text("位置情報の権限はiOSの設定アプリから変更できます。")
            }
        }
        .navigationTitle("位置情報")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 表示

struct LanguageSettingsView: View {
    var body: some View {
        Form {
            Section {
                HStack {
                    Text("現在の言語")
                    Spacer()
                    Text(Locale.current.localizedString(forLanguageCode: Locale.current.language.languageCode?.identifier ?? "ja") ?? "日本語")
                        .foregroundStyle(.secondary)
                }
            }
            Section {
                Button("設定アプリで変更") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            } footer: {
                Text("言語はiOSの設定アプリから変更できます。")
            }
        }
        .navigationTitle("言語")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ThemeSettingsView: View {
    @AppStorage("app_theme") private var theme = 0 // 0=system, 1=light, 2=dark

    var body: some View {
        Form {
            Section {
                Picker("テーマ", selection: $theme) {
                    Text("システム").tag(0)
                    Text("ライト").tag(1)
                    Text("ダーク").tag(2)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } footer: {
                Text("アプリの外観を選択できます。「システム」はデバイスの設定に従います。")
            }
        }
        .navigationTitle("テーマ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct UnitSettingsView: View {
    @AppStorage("distance_unit") private var unit = 0 // 0=km, 1=mile

    var body: some View {
        Form {
            Section {
                Picker("距離の単位", selection: $unit) {
                    Text("キロメートル (km)").tag(0)
                    Text("マイル (mile)").tag(1)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("単位")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - データ

struct StorageSettingsView: View {
    @State private var cacheSize: String = "計算中..."

    var body: some View {
        Form {
            Section("キャッシュ") {
                HStack {
                    Text("画像キャッシュ")
                    Spacer()
                    Text(cacheSize)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("ストレージ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { calculateCacheSize() }
    }

    private func calculateCacheSize() {
        let cache = URLCache.shared
        let bytes = cache.currentDiskUsage
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        cacheSize = formatter.string(fromByteCount: Int64(bytes))
    }
}

struct DataExportView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var errorMessage: String?

    private let userService = UserService()
    private let tripService = TripService()
    private let postService = PostService()

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.largeTitle)
                        .foregroundStyle(GAGATheme.coral)
                    Text("データのエクスポート")
                        .font(GAGATheme.headlineFont)
                    Text("投稿、旅行、プロフィール情報をJSON形式でエクスポートできます。")
                        .font(GAGATheme.captionFont)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            Section {
                if isExporting {
                    HStack {
                        ProgressView()
                        Text("エクスポート中...")
                            .font(GAGATheme.bodyFont)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                    }
                } else {
                    Button("エクスポートを開始") {
                        Task { await exportData() }
                    }
                }
            } footer: {
                Text("プロフィール、旅行、投稿データがJSON形式で出力されます。")
            }
        }
        .navigationTitle("データをエクスポート")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: Binding(
            get: { exportURL.map { ShareableURL(url: $0) } },
            set: { exportURL = $0?.url }
        )) { item in
            ShareSheet(url: item.url)
        }
        .alert("エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func exportData() async {
        guard let uid = authViewModel.firebaseUID else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            let user = try await userService.fetchUser(id: uid)
            let trips = try await tripService.fetchTrips(for: uid)
            let posts = try await userService.fetchPosts(by: uid)

            let exportDict: [String: Any] = [
                "exportDate": ISO8601DateFormatter().string(from: .now),
                "profile": [
                    "displayName": user.displayName,
                    "bio": user.bio,
                    "followersCount": user.followersCount,
                    "followingCount": user.followingCount
                ],
                "tripsCount": trips.count,
                "postsCount": posts.count
            ]

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601

            struct ExportData: Codable {
                let exportDate: String
                let profile: AppUser
                let trips: [Trip]
                let posts: [Post]
            }

            let data = try encoder.encode(ExportData(
                exportDate: ISO8601DateFormatter().string(from: .now),
                profile: user,
                trips: trips,
                posts: posts
            ))

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("GAGA_export_\(uid.prefix(6)).json")
            try data.write(to: tempURL)
            exportURL = tempURL
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ShareableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct CacheClearView: View {
    @State private var cacheSize: String = "計算中..."
    @State private var showConfirm = false
    @State private var cleared = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("キャッシュサイズ")
                    Spacer()
                    Text(cacheSize)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("キャッシュをクリアすると、画像の再読み込みが必要になります。")
            }
            Section {
                Button("キャッシュをクリア", role: .destructive) {
                    showConfirm = true
                }
                .disabled(cleared)
            }
        }
        .navigationTitle("キャッシュをクリア")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { calculateCacheSize() }
        .alert("キャッシュをクリア", isPresented: $showConfirm) {
            Button("クリア", role: .destructive) {
                URLCache.shared.removeAllCachedResponses()
                cleared = true
                calculateCacheSize()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("キャッシュされた画像データをすべて削除します。")
        }
    }

    private func calculateCacheSize() {
        let cache = URLCache.shared
        let bytes = cache.currentDiskUsage
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        cacheSize = formatter.string(fromByteCount: Int64(bytes))
    }
}

// MARK: - サポート

struct HelpView: View {
    var body: some View {
        List {
            Section("よくある質問") {
                DisclosureGroup("旅行を作成するには？") {
                    Text("ホーム画面の「+」ボタンから新しい旅行を作成できます。出発地と目的地を設定し、日程を入力してください。")
                        .font(GAGATheme.captionFont)
                        .foregroundStyle(.secondary)
                }
                DisclosureGroup("投稿を削除するには？") {
                    Text("投稿の右上にある「...」メニューから「削除」を選択してください。")
                        .font(GAGATheme.captionFont)
                        .foregroundStyle(.secondary)
                }
                DisclosureGroup("プロフィールを編集するには？") {
                    Text("プロフィール画面の設定アイコンから「プロフィール編集」を選択してください。")
                        .font(GAGATheme.captionFont)
                        .foregroundStyle(.secondary)
                }
                DisclosureGroup("地球儀の操作方法は？") {
                    Text("ピンチで拡大縮小、ドラッグで回転できます。地名ラベルをタップすると、その場所の投稿一覧が表示されます。")
                        .font(GAGATheme.captionFont)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("ヘルプ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeedbackView: View {
    @State private var feedbackText = ""
    @State private var showSent = false

    var body: some View {
        Form {
            Section("フィードバック") {
                TextField("ご意見・ご要望を入力", text: $feedbackText, axis: .vertical)
                    .font(GAGATheme.bodyFont)
                    .lineLimit(5...10)
            }
            Section {
                Button("送信") {
                    showSent = true
                    feedbackText = ""
                }
                .disabled(feedbackText.trimmingCharacters(in: .whitespaces).isEmpty)
            } footer: {
                Text("この機能は現在準備中です。")
            }
        }
        .navigationTitle("フィードバック")
        .navigationBarTitleDisplayMode(.inline)
        .alert("ありがとうございます", isPresented: $showSent) {
            Button("OK") {}
        } message: {
            Text("フィードバックを受け付けました。")
        }
    }
}

struct ContactView: View {
    var body: some View {
        Form {
            Section("お問い合わせ先") {
                Label("support@gaga-app.com", systemImage: "envelope.fill")
            }
            Section {
                Link(destination: URL(string: "https://twitter.com")!) {
                    Label("X (Twitter)", systemImage: "bubble.left.fill")
                }
                Link(destination: URL(string: "https://instagram.com")!) {
                    Label("Instagram", systemImage: "camera.fill")
                }
            } footer: {
                Text("SNSからもお問い合わせいただけます。")
            }
        }
        .navigationTitle("お問い合わせ")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - このアプリについて

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("利用規約")
                    .font(GAGATheme.titleFont)
                Text("最終更新日: 2024年1月1日")
                    .font(GAGATheme.captionFont)
                    .foregroundStyle(.secondary)

                Group {
                    sectionText("第1条（適用）", "本規約は、本アプリケーション（以下「本アプリ」）の利用に関する条件を定めるものです。ユーザーは本規約に同意の上、本アプリを利用するものとします。")
                    sectionText("第2条（利用登録）", "登録希望者が本規約に同意の上、所定の方法により利用登録を申請し、当社がこれを承認することによって、利用登録が完了するものとします。")
                    sectionText("第3条（禁止事項）", "ユーザーは以下の行為をしてはなりません。法令または公序良俗に違反する行為、犯罪行為に関連する行為、サーバーまたはネットワークの機能を破壊する行為、当社のサービスの運営を妨害する行為。")
                    sectionText("第4条（免責事項）", "当社は、本サービスに起因してユーザーに生じたあらゆる損害について一切の責任を負いません。")
                }
            }
            .padding()
        }
        .navigationTitle("利用規約")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionText(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(GAGATheme.headlineFont)
            Text(body)
                .font(GAGATheme.bodyFont)
                .foregroundStyle(.secondary)
        }
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("プライバシーポリシー")
                    .font(GAGATheme.titleFont)
                Text("最終更新日: 2024年1月1日")
                    .font(GAGATheme.captionFont)
                    .foregroundStyle(.secondary)

                Group {
                    sectionText("1. 収集する情報", "本アプリでは、アカウント情報（表示名、プロフィール写真）、位置情報（投稿時の位置データ）、利用状況データを収集します。")
                    sectionText("2. 情報の利用目的", "収集した情報は、サービスの提供・改善、ユーザーサポート、安全性の確保のために利用します。")
                    sectionText("3. 情報の第三者提供", "法令に基づく場合を除き、ユーザーの同意なく個人情報を第三者に提供することはありません。")
                    sectionText("4. データの保護", "適切な技術的・組織的措置を講じ、個人情報の安全管理に努めます。")
                }
            }
            .padding()
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionText(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(GAGATheme.headlineFont)
            Text(body)
                .font(GAGATheme.bodyFont)
                .foregroundStyle(.secondary)
        }
    }
}

struct LicensesView: View {
    private let licenses = [
        ("Mapbox Maps SDK", "BSD 2-Clause License"),
        ("Firebase iOS SDK", "Apache License 2.0"),
        ("Google AI SDK", "Apache License 2.0"),
    ]

    var body: some View {
        List(licenses, id: \.0) { name, license in
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(GAGATheme.bodyFont)
                    .fontWeight(.semibold)
                Text(license)
                    .font(GAGATheme.captionFont)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .navigationTitle("ライセンス")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - アカウント削除

struct DeleteAccountView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showConfirm = false
    @State private var confirmText = ""

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text("アカウントを削除すると、すべてのデータが完全に削除され、復元できません。")
                        .font(GAGATheme.bodyFont)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }

            Section {
                TextField("確認のため「削除」と入力", text: $confirmText)
                Button("アカウントを削除", role: .destructive) {
                    showConfirm = true
                }
                .disabled(confirmText != "削除")
            }
        }
        .navigationTitle("アカウント削除")
        .navigationBarTitleDisplayMode(.inline)
        .alert("本当に削除しますか？", isPresented: $showConfirm) {
            Button("削除する", role: .destructive) {
                authViewModel.signOut()
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。すべてのデータが削除されます。")
        }
    }
}

