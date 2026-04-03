import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = LoginViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                MetrologyPalette.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    Spacer(minLength: 30)

                    Text("校准管理系统")
                        .font(.system(size: 42, weight: .black))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                    Text("请输入账号密码登录")
                        .font(.system(size: 16))
                        .foregroundStyle(MetrologyPalette.textSecondary)

                    VStack(spacing: 12) {
                        TextField("用户名", text: $viewModel.username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .metrologyInput()

                        SecureField("密码", text: $viewModel.password)
                            .metrologyInput()
                    }
                    .padding(14)
                    .metrologyCard()

                    Button {
                        Task {
                            await viewModel.login { response in
                                appState.applyLogin(response)
                            }
                        }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        } else {
                            Text("登录")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                    }
                    .buttonStyle(MetrologyPrimaryButtonStyle())
                    .disabled(viewModel.isLoading)
                    .opacity(viewModel.isLoading ? 0.8 : 1)

                    if let message = viewModel.errorMessage {
                        Text(message)
                            .foregroundStyle(Color.red.opacity(0.9))
                            .font(.footnote)
                            .padding(.horizontal, 4)
                    }

                    Spacer()
                }
                .padding(.horizontal, 20)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}
