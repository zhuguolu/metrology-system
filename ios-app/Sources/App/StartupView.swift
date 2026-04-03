import SwiftUI

struct StartupView: View {
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.05, blue: 0.10),
                    Color(red: 0.01, green: 0.02, blue: 0.04)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 22) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(MetrologyPalette.accent.opacity(0.14))
                        .frame(width: 110, height: 110)
                    Image(systemName: "gauge.with.dots.needle.100percent")
                        .font(.system(size: 50, weight: .semibold))
                        .foregroundStyle(MetrologyPalette.accent)
                }
                .scaleEffect(pulse ? 1.04 : 0.96)
                .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)

                VStack(spacing: 8) {
                    Text("计量系统")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                    Text("设备台账 · 校准 · 审核一体化")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                }
            }
        }
        .onAppear {
            pulse = true
        }
    }
}
