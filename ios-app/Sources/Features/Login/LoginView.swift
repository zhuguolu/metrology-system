import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = LoginViewModel()
    @State private var showPassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: 0x061B3F), Color(hex: 0x0B2A57)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: 0x64A4FF, alpha: 0.34), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 240, height: 240)
                    .offset(x: -150, y: -280)

                Circle()
                    .stroke(Color(hex: 0x6EE8DF, alpha: 0.42), lineWidth: 20)
                    .frame(width: 300, height: 300)
                    .offset(x: 190, y: 330)

                VStack {
                    Spacer(minLength: 0)

                    loginCard
                        .padding(.horizontal, 24)

                    Spacer(minLength: 0)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var loginCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x2E63F2), Color(hex: 0x16B8AC)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 54, height: 54)
                    Image(systemName: "gauge.with.dots.needle.100percent")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("计量管理系统")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                    Text("Calibration Management System")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                }
            }

            Text("欢迎使用")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)
                .padding(.top, 18)

            inputTitle("用户名")
                .padding(.top, 18)
            usernameInput
                .padding(.top, 8)

            inputTitle("密码")
                .padding(.top, 14)
            passwordInput
                .padding(.top, 8)

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(MetrologyPalette.statusExpired)
                    .padding(.top, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

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
                        .frame(height: 44)
                } else {
                    Text("登录")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                }
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: viewModel.isLoading
                                ? [Color(hex: 0x2D65CF), Color(hex: 0x1648B8)]
                                : [Color(hex: 0x346AF3), Color(hex: 0x1C55DF)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: 0x1E58C9), lineWidth: 1)
            )
            .padding(.top, 14)
            .disabled(viewModel.isLoading)

            if viewModel.isLoading {
                ProgressView()
                    .tint(MetrologyPalette.navActive)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }

            Text("如需注册账号，请联系管理员")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(MetrologyPalette.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 14)
        }
        .padding(.horizontal, 22)
        .padding(.top, 24)
        .padding(.bottom, 18)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xEEF5FF, alpha: 0.92), Color(hex: 0xDCE8F4, alpha: 0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color(hex: 0xA9C8E6, alpha: 0.44), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.16), radius: 20, x: 0, y: 10)
    }

    private func inputTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .bold))
            .foregroundStyle(MetrologyPalette.textPrimary)
    }

    private var usernameInput: some View {
        HStack(spacing: 10) {
            Image(systemName: "person")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MetrologyPalette.textMuted)
            TextField("用户名", text: $viewModel.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 16))
                .foregroundStyle(MetrologyPalette.textPrimary)
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0xF4F8FF, alpha: 0.80))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: 0xBFD0E8), lineWidth: 1)
        )
    }

    private var passwordInput: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(MetrologyPalette.textMuted)

            Group {
                if showPassword {
                    TextField("密码", text: $viewModel.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } else {
                    SecureField("密码", text: $viewModel.password)
                }
            }
            .font(.system(size: 16))
            .foregroundStyle(MetrologyPalette.textPrimary)

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MetrologyPalette.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0xF4F8FF, alpha: 0.80))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: 0xBFD0E8), lineWidth: 1)
        )
    }
}

private extension Color {
    init(hex: Int, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
