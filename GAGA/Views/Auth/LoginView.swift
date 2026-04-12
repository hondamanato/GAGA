import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var showingGoogleSoonAlert = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.black, Color(red: 0.05, green: 0.1, blue: 0.2)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 12) {
                    Image(systemName: "globe.americas.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.blue, .green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("GAGA")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundStyle(.white)
                    Text("旅の記録を、地球に刻もう")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
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
                            print("Apple Sign In failed: \(error)")
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
                        Text("ゲストとして始める")
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .foregroundStyle(.gray)
                    }
                    .disabled(authViewModel.isLoading)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }

            if authViewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .scaleEffect(1.5)
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
}

#Preview {
    LoginView()
        .environment(AuthViewModel())
}
