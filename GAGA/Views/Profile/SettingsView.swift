import SwiftUI

struct SettingsView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }

    var body: some View {
        List {
            Section("アカウント") {
                NavigationLink {
                    EditProfileView()
                } label: {
                    Label("プロフィール編集", systemImage: "person.crop.circle")
                }
                NavigationLink {
                    AccountSettingsView()
                } label: {
                    Label("アカウント", systemImage: "key.fill")
                }
                NavigationLink {
                    LinkedAccountsView()
                } label: {
                    Label("連携アカウント", systemImage: "link")
                }
            }

            Section("通知") {
                NavigationLink {
                    PushNotificationSettingsView()
                } label: {
                    Label("プッシュ通知", systemImage: "bell.fill")
                }
                NavigationLink {
                    EmailNotificationSettingsView()
                } label: {
                    Label("メール通知", systemImage: "envelope.fill")
                }
            }

            Section("プライバシーとセキュリティ") {
                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    Label("プライバシー", systemImage: "lock.fill")
                }
                NavigationLink {
                    BlockedUsersView()
                } label: {
                    Label("ブロックしたユーザー", systemImage: "person.fill.xmark")
                }
                NavigationLink {
                    LocationSettingsView()
                } label: {
                    Label("位置情報", systemImage: "location.fill")
                }
            }

            Section("表示") {
                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("言語", systemImage: "globe")
                }
                NavigationLink {
                    ThemeSettingsView()
                } label: {
                    Label("テーマ", systemImage: "paintbrush.fill")
                }
                NavigationLink {
                    UnitSettingsView()
                } label: {
                    Label("単位 (km / mile)", systemImage: "ruler.fill")
                }
            }

            Section("データ") {
                NavigationLink {
                    StorageSettingsView()
                } label: {
                    Label("ストレージ", systemImage: "internaldrive.fill")
                }
                NavigationLink {
                    DataExportView()
                } label: {
                    Label("データをエクスポート", systemImage: "square.and.arrow.up")
                }
                NavigationLink {
                    CacheClearView()
                } label: {
                    Label("キャッシュをクリア", systemImage: "trash.fill")
                }
            }

            Section("サポート") {
                NavigationLink {
                    HelpView()
                } label: {
                    Label("ヘルプ", systemImage: "questionmark.circle.fill")
                }
                NavigationLink {
                    FeedbackView()
                } label: {
                    Label("フィードバックを送る", systemImage: "paperplane.fill")
                }
                NavigationLink {
                    ContactView()
                } label: {
                    Label("お問い合わせ", systemImage: "envelope.open.fill")
                }
            }

            Section("このアプリについて") {
                NavigationLink {
                    TermsOfServiceView()
                } label: {
                    Label("利用規約", systemImage: "doc.text.fill")
                }
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Label("プライバシーポリシー", systemImage: "hand.raised.fill")
                }
                NavigationLink {
                    LicensesView()
                } label: {
                    Label("ライセンス", systemImage: "doc.plaintext.fill")
                }
                HStack {
                    Label("バージョン", systemImage: "info.circle.fill")
                    Spacer()
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button(role: .destructive) {
                    authViewModel.signOut()
                } label: {
                    Text("サインアウト")
                        .frame(maxWidth: .infinity)
                }
            }

            Section {
                NavigationLink {
                    DeleteAccountView()
                } label: {
                    Text("アカウントを削除")
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("設定")
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environment(AuthViewModel())
    }
}
