import SwiftUI

struct EditPostView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PostStore.self) private var postStore

    let post: Post

    @State private var caption: String
    @State private var location: Location
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(post: Post) {
        self.post = post
        _caption = State(initialValue: post.caption)
        _location = State(initialValue: post.location)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("写真") {
                    CachedAsyncImage(url: URL(string: post.imageURL)) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } placeholder: {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                    }
                }

                Section("キャプション") {
                    TextField("キャプションを入力", text: $caption, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("場所") {
                    Picker("場所", selection: $location) {
                        ForEach(CityCatalog.all, id: \.name) { city in
                            Text("\(city.name), \(city.country)")
                                .tag(city)
                        }
                    }
                }
            }
            .navigationTitle("投稿を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .alert("エラー", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        var updated = post
        updated.caption = caption
        updated.location = location
        do {
            try await postStore.update(updated)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
