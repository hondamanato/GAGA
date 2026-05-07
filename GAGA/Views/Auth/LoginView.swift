import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showingGoogleSoonAlert = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var onboardingPage = 0

    private struct OnboardingPage: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let desc: String
    }

    private let onboardingPages: [OnboardingPage] = [
        OnboardingPage(id: 0, icon: "globe.americas.fill", title: "旅の記録を、地球に刻もう", desc: "3D地球儀であなたの旅行ルートを美しく可視化"),
        OnboardingPage(id: 1, icon: "camera.fill", title: "写真で旅を振り返る", desc: "旅先の写真を日付ごとに記録して旅行ジャーナルに"),
        OnboardingPage(id: 2, icon: "person.2.fill", title: "仲間と旅行をシェア", desc: "フォロワーと旅行体験を共有しよう"),
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
                        showingGoogleSoonAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("Googleでサインイン")
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(authViewModel.isLoading)

                    Button {
                        Task {
                            await authViewModel.signInAnonymously()
                        }
                    } label: {
                        VStack(spacing: 2) {
                            Text("ゲストとして始める")
                                .foregroundStyle(.gray)
                            Text("閲覧のみ・投稿にはログインが必要です")
                                .font(.caption2)
                                .foregroundStyle(.gray.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
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
        .alert("準備中", isPresented: $showingGoogleSoonAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Googleサインインは近日対応予定です")
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

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
