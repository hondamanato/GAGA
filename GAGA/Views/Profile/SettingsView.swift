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
                    Text("プロフィール編集")
                } label: {
                    Label("プロフィール編集", systemImage: "person.crop.circle")
                }
                NavigationLink {
                    Text("アカウント設定")
                } label: {
                    Label("アカウント", systemImage: "key.fill")
                }
                NavigationLink {
                    Text("リンクされたアカウント")
                } label: {
                    Label("連携アカウント", systemImage: "link")
                }
            }

            Section("通知") {
                NavigationLink {
                    Text("プッシュ通知設定")
                } label: {
                    Label("プッシュ通知", systemImage: "bell.fill")
                }
                NavigationLink {
                    Text("メール通知設定")
                } label: {
                    Label("メール通知", systemImage: "envelope.fill")
                }
            }

            Section("プライバシーとセキュリティ") {
                NavigationLink {
                    Text("プライバシー設定")
                } label: {
                    Label("プライバシー", systemImage: "lock.fill")
                }
                NavigationLink {
                    Text("ブロックしたユーザー")
                } label: {
                    Label("ブロックしたユーザー", systemImage: "person.fill.xmark")
                }
                NavigationLink {
                    Text("位置情報設定")
                } label: {
                    Label("位置情報", systemImage: "location.fill")
                }
            }

            Section("表示") {
                NavigationLink {
                    Text("言語設定")
                } label: {
                    Label("言語", systemImage: "globe")
                }
                NavigationLink {
                    Text("テーマ設定")
                } label: {
                    Label("テーマ", systemImage: "paintbrush.fill")
                }
                NavigationLink {
                    Text("単位設定")
                } label: {
                    Label("単位 (km / mile)", systemImage: "ruler.fill")
                }
            }

            Section("データ") {
                NavigationLink {
                    Text("ストレージ使用状況")
                } label: {
                    Label("ストレージ", systemImage: "internaldrive.fill")
                }
                NavigationLink {
                    Text("データのエクスポート")
                } label: {
                    Label("データをエクスポート", systemImage: "square.and.arrow.up")
                }
                NavigationLink {
                    Text("キャッシュ管理")
                } label: {
                    Label("キャッシュをクリア", systemImage: "trash.fill")
                }
            }

            Section("サポート") {
                NavigationLink {
                    Text("ヘルプセンター")
                } label: {
                    Label("ヘルプ", systemImage: "questionmark.circle.fill")
                }
                NavigationLink {
                    Text("フィードバック送信")
                } label: {
                    Label("フィードバックを送る", systemImage: "paperplane.fill")
                }
                NavigationLink {
                    Text("お問い合わせ")
                } label: {
                    Label("お問い合わせ", systemImage: "envelope.open.fill")
                }
            }

            Section("このアプリについて") {
                NavigationLink {
                    Text("利用規約")
                } label: {
                    Label("利用規約", systemImage: "doc.text.fill")
                }
                NavigationLink {
                    Text("プライバシーポリシー")
                } label: {
                    Label("プライバシーポリシー", systemImage: "hand.raised.fill")
                }
                NavigationLink {
                    Text("オープンソースライセンス")
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
                    Text("アカウント削除")
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
