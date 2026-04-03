import SwiftUI

struct StartupView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0xF1F8FF), Color(hex: 0xD3E8FF)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xA6D8FF, alpha: 0.34), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 320, height: 320)
                .offset(x: 180, y: -310)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xC2F2E8, alpha: 0.30), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 300, height: 300)
                .offset(x: -170, y: 340)

            VStack {
                Spacer(minLength: 0)

                VStack(spacing: 0) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: 0xF9FCFF), Color(hex: 0xEAF5FF)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color(hex: 0xBFD7F2), lineWidth: 1)
                            )
                            .frame(width: 92, height: 92)

                        Image(systemName: "gauge.with.dots.needle.100percent")
                            .font(.system(size: 42, weight: .bold))
                            .foregroundStyle(Color(hex: 0x1D4ED8))
                    }

                    Text("计量管理系统")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color(hex: 0x0A1E3C))
                        .padding(.top, 16)

                    Text("设备、校准、审核与资料统一管理")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(Color(hex: 0x3A5F87))
                        .padding(.top, 6)

                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(Color(hex: 0x2563EB))
                            .scaleEffect(0.9)
                        Text("正在启动...")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color(hex: 0x3A5F87))
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(Color(hex: 0xF7FBFF, alpha: 0.80))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color(hex: 0xA5C5E6), lineWidth: 1)
                    )
                    .padding(.top, 18)
                }
                .padding(.horizontal, 22)
                .padding(.top, 28)
                .padding(.bottom, 22)
                .background(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0xF4FAFF, alpha: 0.94), Color(hex: 0xDDECF9, alpha: 0.84)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(Color(hex: 0xB6D4EE, alpha: 0.50), lineWidth: 1)
                )
                .padding(.horizontal, 22)

                Spacer(minLength: 0)
            }
        }
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
