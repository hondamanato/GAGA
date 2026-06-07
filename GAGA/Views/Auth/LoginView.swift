import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showEmailAuth = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var onboardingPage = 0

    private struct OnboardingPage: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let desc: String
    }

    private let onboardingPages: [OnboardingPage] = [
        OnboardingPage(id: 0, icon: "globe.americas.fill", title: String(localized: "旅の記録を、地球に刻もう"), desc: String(localized: "3D地球儀であなたの旅行ルートを美しく可視化")),
        OnboardingPage(id: 1, icon: "camera.fill", title: String(localized: "写真で旅を振り返る"), desc: String(localized: "旅先の写真を日付ごとに記録して旅行ジャーナルに")),
        OnboardingPage(id: 2, icon: "person.2.fill", title: String(localized: "仲間と旅行をシェア"), desc: String(localized: "フォロワーと旅行体験を共有しよう")),
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, GAGATheme.deepNavy],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: GAGATheme.spacingXL) {
                Spacer()

                // Onboarding carousel or logo
                if !hasSeenOnboarding {
                    onboardingCarousel
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "globe.americas.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(GAGATheme.accentGradient)
                        Text("GAGA")
                            .font(GAGATheme.largeTitleFont)
                            .foregroundStyle(.white)
                        Text("旅の記録を、地球に刻もう")
                            .font(GAGATheme.bodyFont)
                            .foregroundStyle(.gray)
                    }
                }

                Spacer()

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        authViewModel.prepareAppleRequest(request)
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            Task {
                                await authViewModel.signInWithApple(authorization: authorization)
                            }
                        case .failure(let error):
                            authViewModel.errorMessage = error.localizedDescription
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .disabled(authViewModel.isLoading)

                    Button {
                        showEmailAuth = true
                    } label: {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("メールでサインイン")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(authViewModel.isLoading)

                }
                .padding(.horizontal, GAGATheme.spacingXL)
                .padding(.bottom, 48)
            }

            if authViewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .onAppear {
            if !hasSeenOnboarding {
                DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                    hasSeenOnboarding = true
                }
            }
        }
        .sheet(isPresented: $showEmailAuth) {
            EmailAuthView()
        }
        .alert(
            "サインインに失敗しました",
            isPresented: Binding(
                get: { authViewModel.errorMessage != nil },
                set: { if !$0 { authViewModel.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) { authViewModel.errorMessage = nil }
        } message: {
            Text(authViewModel.errorMessage ?? "")
        }
    }

    private var onboardingCarousel: some View {
        VStack(spacing: GAGATheme.spacingMD) {
            TabView(selection: $onboardingPage) {
                ForEach(onboardingPages) { page in
                    VStack(spacing: GAGATheme.spacingMD) {
                        Image(systemName: page.icon)
                            .font(.system(size: 64))
                            .foregroundStyle(GAGATheme.accentGradient)
                        Text(page.title)
                            .font(GAGATheme.titleFont)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                        Text(page.desc)
                            .font(GAGATheme.bodyFont)
                            .foregroundStyle(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, GAGATheme.spacingXL)
                    }
                    .tag(page.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 240)

            // Page indicator
            HStack(spacing: GAGATheme.spacingSM) {
                ForEach(0..<onboardingPages.count, id: \.self) { i in
                    Capsule()
                        .fill(i == onboardingPage ? GAGATheme.coral : .gray.opacity(0.4))
                        .frame(width: i == onboardingPage ? 20 : 8, height: 8)
                        .animation(GAGATheme.springSnappy, value: onboardingPage)
                }
            }

            if onboardingPage == 2 {
                Button {
                    withAnimation { hasSeenOnboarding = true }
                } label: {
                    Text("始める")
                        .font(GAGATheme.headlineFont)
                        .foregroundStyle(.white)
                        .padding(.horizontal, GAGATheme.spacingXL)
                        .padding(.vertical, 10)
                        .background(GAGATheme.accentGradient, in: Capsule())
                }
                .transition(.opacity)
            }
        }
    }
}

// MARK: - Email Auth

private struct EmailAuthView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var displayName = ""
    @State private var localError: String?

    private var canSubmit: Bool {
        guard !email.isEmpty, !password.isEmpty else { return false }
        if isSignUp {
            guard password == confirmPassword, !displayName.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        }
        return password.count >= 6
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Picker("", selection: $isSignUp) {
                    Text("ログイン").tag(false)
                    Text("新規登録").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                VStack(spacing: 16) {
                    if isSignUp {
                        TextField("表示名", text: $displayName)
                            .textContentType(.name)
                            .padding(12)
                            .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }

                    TextField("メールアドレス", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                    SecureField("パスワード（6文字以上）", text: $password)
                        .textContentType(isSignUp ? .newPassword : .password)
                        .padding(12)
                        .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))

                    if isSignUp {
                        SecureField("パスワード確認", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding(12)
                            .background(.gray.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(.horizontal)

                if let error = localError ?? authViewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Button {
                    Task { await submit() }
                } label: {
                    Group {
                        if authViewModel.isLoading {
                            ProgressView().tint(.white)
                        } else {
                            Text(isSignUp ? LocalizedStringKey("登録") : LocalizedStringKey("ログイン"))
                                .font(GAGATheme.headlineFont)
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(canSubmit ? AnyShapeStyle(GAGATheme.accentGradient) : AnyShapeStyle(.gray.opacity(0.3)), in: RoundedRectangle(cornerRadius: 14))
                }
                .disabled(!canSubmit || authViewModel.isLoading)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle(isSignUp ? LocalizedStringKey("新規登録") : LocalizedStringKey("ログイン"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .onChange(of: isSignUp) { _, _ in
                localError = nil
                authViewModel.errorMessage = nil
            }
        }
    }

    private func submit() async {
        localError = nil
        authViewModel.errorMessage = nil

        if isSignUp {
            if password != confirmPassword {
                localError = String(localized: "パスワードが一致しません")
                return
            }
            await authViewModel.signUpWithEmail(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password,
                displayName: displayName.trimmingCharacters(in: .whitespaces)
            )
        } else {
            await authViewModel.signInWithEmail(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        }

        if authViewModel.errorMessage == nil {
            dismiss()
        }
    }
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
