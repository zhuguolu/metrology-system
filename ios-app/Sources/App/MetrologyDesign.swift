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
    let height: CGFloat

    init(containerWidth: CGFloat, containerHeight: CGFloat? = nil) {
        let baseWidth: CGFloat = 390
        let baseHeight: CGFloat = 844
        let rawWidth = containerWidth / baseWidth

        let resolvedHeight = max(containerHeight ?? baseHeight, 568)
        let rawHeight = resolvedHeight / baseHeight

        let mixed = (rawWidth * 0.72) + (rawHeight * 0.28)
        factor = min(max(mixed, 0.88), 1.26)
        width = containerWidth
        height = resolvedHeight
    }

    func px(_ value: CGFloat) -> CGFloat {
        value * factor
    }

    func vertical(_ value: CGFloat) -> CGFloat {
        value * min(max(factor * 0.96, 0.90), 1.20)
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

struct MetrologyDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: configuration.isPressed
                                ? [Color(hex: 0xE03B3B), Color(hex: 0xC61E1E)]
                                : [Color(hex: 0xEF4444), Color(hex: 0xDC2626)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        configuration.isPressed ? Color(hex: 0xB91C1C) : Color(hex: 0xC92323),
                        lineWidth: 1
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
    }
}

@MainActor
func metrologyDismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct MetrologySaveCancelRow: View {
    var cancelTitle: String = "取消"
    var saveTitle: String = "保存"
    var saveDisabled: Bool = false
    let onCancel: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                metrologyDismissKeyboard()
                onCancel()
            } label: {
                Text(cancelTitle)
                    .frame(maxWidth: .infinity, minHeight: 22)
            }
            .buttonStyle(MetrologySecondaryButtonStyle())

            Button {
                metrologyDismissKeyboard()
                onSave()
            } label: {
                Text(saveTitle)
                    .frame(maxWidth: .infinity, minHeight: 22)
            }
            .buttonStyle(MetrologyPrimaryButtonStyle())
            .disabled(saveDisabled)
            .opacity(saveDisabled ? 0.45 : 1)
        }
    }
}

struct MetrologySelectField: View {
    let title: String
    let value: String
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 5 : 6) {
            Text(compact ? "\(title):" : title)
                .font(.system(size: compact ? 11 : 12, weight: .bold))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: compact ? 11 : 12, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.down")
                .font(.system(size: compact ? 10 : 11, weight: .semibold))
                .foregroundStyle(MetrologyPalette.textMuted)
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 8 : 9)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(hex: 0xF4F8FE)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(hex: 0xCFDAEB), lineWidth: 1)
        )
    }
}

struct MetrologyNoticeDialog: View {
    let title: String
    let message: String
    var confirmTitle: String = "纭畾"
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(message)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(confirmTitle, action: onConfirm)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .buttonStyle(MetrologyPrimaryButtonStyle())
            }
            .padding(14)
            .frame(maxWidth: 360)
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
                    .stroke(Color(hex: 0xD5E2F2), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x456B96, alpha: 0.22), radius: 14, x: 0, y: 6)
            .padding(.horizontal, 20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(1000)
    }
}

struct MetrologyConfirmDialog: View {
    let title: String
    let message: String
    var cancelTitle: String = "取消"
    var confirmTitle: String = "确定"
    var destructive: Bool = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(message)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 10) {
                    Button(cancelTitle, action: onCancel)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .buttonStyle(MetrologySecondaryButtonStyle())

                    if destructive {
                        Button(confirmTitle, action: onConfirm)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .buttonStyle(MetrologyDangerButtonStyle())
                    } else {
                        Button(confirmTitle, action: onConfirm)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .buttonStyle(MetrologyPrimaryButtonStyle())
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: 360)
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
                    .stroke(Color(hex: 0xD5E2F2), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x456B96, alpha: 0.22), radius: 14, x: 0, y: 6)
            .padding(.horizontal, 20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(1000)
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
