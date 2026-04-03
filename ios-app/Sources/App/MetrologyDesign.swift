import SwiftUI
import UIKit

enum MetrologyPalette {
    static let brandBlue = Color(hex: 0x2563EB)

    static let background = Color(hex: 0xEEF4FB)         // surfacePage
    static let surface = Color.white
    static let card = Color(hex: 0xF9FCFF)               // surfaceCard
    static let cardSoftBlue = Color(hex: 0xEEF4FF)
    static let stroke = Color(hex: 0xD5E2F2)

    static let textPrimary = Color(hex: 0x0F1F3A)
    static let textSecondary = Color(hex: 0x5E6F87)
    static let textMuted = Color(hex: 0x8A9AAF)

    static let navActive = Color(hex: 0x1D4ED8)
    static let navInactive = Color(hex: 0x7B8BA0)

    static let statusValid = Color(hex: 0x059669)
    static let statusWarning = Color(hex: 0xD97706)
    static let statusExpired = Color(hex: 0xDC2626)

    static let moreBgStart = Color(hex: 0xF7FAFF)
    static let moreBgEnd = Color(hex: 0xEEF7FF)
}

enum MetrologyAppearance {
    static func applyGlobal() {
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(hex: 0xF8FBFF)
        nav.shadowColor = UIColor(hex: 0xDCE8F8)
        nav.titleTextAttributes = [.foregroundColor: UIColor(hex: 0x0F1F3A)]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor(hex: 0x0F1F3A)]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = UIColor(hex: 0x1D4ED8)
    }
}

struct AndroidScale {
    let factor: CGFloat
    let width: CGFloat

    init(containerWidth: CGFloat) {
        let base: CGFloat = 390
        let raw = containerWidth / base
        factor = min(max(raw, 0.86), 1.22)
        width = containerWidth
    }

    func px(_ value: CGFloat) -> CGFloat {
        value * factor
    }
}

struct MetrologyCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(hex: 0xF6FAFF)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MetrologyPalette.stroke, lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x7A95B8, alpha: 0.10), radius: 6, x: 0, y: 2)
    }
}

struct MetrologyInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .regular))
            .foregroundStyle(MetrologyPalette.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: 0xD6E2F2), lineWidth: 1)
            )
    }
}

struct MetrologyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: configuration.isPressed
                                ? [Color(hex: 0x276EDD), Color(hex: 0x1B54C2)]
                                : [Color(hex: 0x2F7CF7), Color(hex: 0x1F62E8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        configuration.isPressed ? Color(hex: 0x1E58C9) : Color(hex: 0x2C6EEA),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct MetrologySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(MetrologyPalette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: configuration.isPressed
                                ? [Color(hex: 0xEEF4FD), Color(hex: 0xE3ECF9)]
                                : [Color.white, Color(hex: 0xF4F8FE)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        configuration.isPressed ? Color(hex: 0xBFCFE5) : Color(hex: 0xCFDAEB),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

struct MetrologyGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(MetrologyPalette.navActive.opacity(configuration.isPressed ? 0.72 : 1))
    }
}

extension View {
    func metrologyCard() -> some View {
        modifier(MetrologyCardModifier())
    }

    func metrologyInput() -> some View {
        modifier(MetrologyInputModifier())
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

private extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
