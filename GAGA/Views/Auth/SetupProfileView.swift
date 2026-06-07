import SwiftUI
import PhotosUI

struct SetupProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    @State private var username = ""
    @State private var displayName = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: Image?
    @State private var avatarData: Data?
    @State private var usernameStatus: UsernameStatus = .idle
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let userService = UserService()

    private enum UsernameStatus {
        case idle, checking, available, taken, invalid
    }

    private var isUsernameValid: Bool {
        username.range(of: "^[a-z0-9_]{3,20}$", options: .regularExpression) != nil
    }

    private var canSubmit: Bool {
        guard !isSaving else { return false }
        guard !username.isEmpty, usernameStatus == .available else { return false }
        guard !displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        return true
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, GAGATheme.deepNavy],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer().frame(height: 20)

                    // Title
                    VStack(spacing: 8) {
                        Text("プロフィールを設定")
                            .font(GAGATheme.titleFont)
                            .foregroundStyle(.white)
                        Text("あなたの旅行者プロフィールを作りましょう")
                            .font(GAGATheme.bodyFont)
                            .foregroundStyle(.gray)
                    }

                    // Avatar picker
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        ZStack(alignment: .bottomTrailing) {
                            if let avatarImage {
                                avatarImage
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                            } else {
                                GAGAAvatar(url: authViewModel.currentUser?.avatarURL, size: 100)
                            }
                            Image(systemName: "camera.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, GAGATheme.coral)
                                .offset(x: 4, y: 4)
                        }
                    }
                    .onChange(of: selectedPhoto) { _, newItem in
                        Task {
                            guard let newItem else { return }
                            if let data = try? await newItem.loadTransferable(type: Data.self) {
                                avatarData = data
                                if let uiImage = UIImage(data: data) {
                                    avatarImage = Image(uiImage: uiImage)
                                }
                            }
                        }
                    }

                    // Form fields
                    VStack(spacing: 20) {
                        // Username
                        VStack(alignment: .leading, spacing: 6) {
                            Text("ユーザーネーム")
                                .font(GAGATheme.captionFont)
                                .foregroundStyle(.gray)
                            HStack {
                                Text("@")
                                    .foregroundStyle(.gray)
                                TextField("username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .onChange(of: username) { _, newValue in
                                        username = newValue.lowercased()
                                        checkUsername()
                                    }
                                usernameIndicator
                            }
                            .padding(12)
                            .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.white)

                            Text("英小文字・数字・アンダースコア、3〜20文字")
                                .font(.caption2)
                                .foregroundStyle(.gray.opacity(0.7))
                        }

                        // Display name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("表示名")
                                .font(GAGATheme.captionFont)
                                .foregroundStyle(.gray)
                            TextField("あなたの名前", text: $displayName)
                                .padding(12)
                                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 32)

                    // Submit button
                    Button {
                        Task { await submit() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("始める")
                                    .font(GAGATheme.headlineFont)
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(canSubmit ? AnyShapeStyle(GAGATheme.accentGradient) : AnyShapeStyle(.gray.opacity(0.3)), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(!canSubmit)
                    .padding(.horizontal, 32)

                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear {
            if let user = authViewModel.currentUser {
                displayName = user.displayName
                if !user.username.isEmpty {
                    username = user.username
                    usernameStatus = .available
                }
            }
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

    @ViewBuilder
    private var usernameIndicator: some View {
        switch usernameStatus {
        case .idle:
            EmptyView()
        case .checking:
            ProgressView()
                .controlSize(.small)
                .tint(.white)
        case .available:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .taken:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .invalid:
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
        }
    }

    private func checkUsername() {
        let current = username
        if current.isEmpty {
            usernameStatus = .idle
            return
        }
        if !isUsernameValid {
            usernameStatus = .invalid
            return
        }
        // 自分の現在のユーザーネームと同じなら利用可能
        if current.lowercased() == authViewModel.currentUser?.username.lowercased(),
           !(authViewModel.currentUser?.username.isEmpty ?? true) {
            usernameStatus = .available
            return
        }
        usernameStatus = .checking
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard username == current else { return }
            do {
                let available = try await userService.isUsernameAvailable(current)
                if username == current {
                    usernameStatus = available ? .available : .taken
                }
            } catch {
                if username == current {
                    usernameStatus = .available
                }
            }
        }
    }

    private func submit() async {
        isSaving = true
        defer { isSaving = false }

        // Upload avatar if selected
        if let data = avatarData {
            await authViewModel.uploadAvatar(imageData: data)
        }

        // Save username + display name
        await authViewModel.updateProfile(
            displayName: displayName,
            bio: authViewModel.currentUser?.bio ?? "",
            username: username
        )

        if authViewModel.errorMessage != nil {
            errorMessage = authViewModel.errorMessage
            authViewModel.errorMessage = nil
        }
    }
}
