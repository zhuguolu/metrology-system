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
    static let statusNeutral = Color(hex: 0x4F7ED0)
    static let statusMuted = Color(hex: 0x64748B)

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
            .shadow(
                color: Color(hex: 0x2C6EEA, alpha: configuration.isPressed ? 0.10 : 0.18),
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 1 : 4
            )
            .offset(y: configuration.isPressed ? 1 : 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

enum MetrologyLayout {
    static let pageHorizontalPadding: CGFloat = 4
    static let controlHorizontalPadding: CGFloat = 12
}

struct MetrologySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(MetrologyPalette.textPrimary)
            .padding(.horizontal, MetrologyLayout.controlHorizontalPadding)
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
            .shadow(
                color: Color(hex: 0x91A7C3, alpha: configuration.isPressed ? 0.06 : 0.10),
                radius: configuration.isPressed ? 3 : 6,
                x: 0,
                y: configuration.isPressed ? 1 : 3
            )
            .offset(y: configuration.isPressed ? 1 : 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
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
            .padding(.horizontal, MetrologyLayout.controlHorizontalPadding)
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
            .shadow(
                color: Color(hex: 0xDC2626, alpha: configuration.isPressed ? 0.10 : 0.18),
                radius: configuration.isPressed ? 4 : 8,
                x: 0,
                y: configuration.isPressed ? 1 : 4
            )
            .offset(y: configuration.isPressed ? 1 : 0)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
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

enum MetrologyPillTone {
    case neutral
    case valid
    case warning
    case expired
    case muted

    var tint: Color {
        switch self {
        case .neutral:
            return MetrologyPalette.statusNeutral
        case .valid:
            return MetrologyPalette.statusValid
        case .warning:
            return MetrologyPalette.statusWarning
        case .expired:
            return MetrologyPalette.statusExpired
        case .muted:
            return MetrologyPalette.statusMuted
        }
    }

    var background: Color {
        switch self {
        case .neutral:
            return Color(hex: 0xF5F9FF)
        case .valid:
            return Color(hex: 0xECFDF5)
        case .warning:
            return Color(hex: 0xFFFBEB)
        case .expired:
            return Color(hex: 0xFEF2F2)
        case .muted:
            return Color(hex: 0xF8FAFC)
        }
    }

    var strongBackground: Color {
        switch self {
        case .neutral:
            return Color(hex: 0xE7F0FF)
        case .valid:
            return Color(hex: 0xDCFCE7)
        case .warning:
            return Color(hex: 0xFEF3C7)
        case .expired:
            return Color(hex: 0xFEE2E2)
        case .muted:
            return Color(hex: 0xEAEFF5)
        }
    }

    var stroke: Color {
        switch self {
        case .neutral:
            return Color(hex: 0xC5D8F7)
        case .valid:
            return Color(hex: 0xA7F3D0)
        case .warning:
            return Color(hex: 0xFCD34D)
        case .expired:
            return Color(hex: 0xFCA5A5)
        case .muted:
            return Color(hex: 0xCBD5E1)
        }
    }
}

struct MetrologyPageHeroCard<Trailing: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var accent: MetrologyPillTone = .neutral
    @ViewBuilder let trailing: () -> Trailing

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        accent: MetrologyPillTone = .neutral,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(accent.tint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(accent.strongBackground)
                    )

                Text(title)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            trailing()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white,
                            accent.background.opacity(0.95),
                            Color(hex: 0xF6FAFF)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(accent.stroke.opacity(0.65), lineWidth: 1)
        )
        .shadow(color: accent.tint.opacity(0.12), radius: 14, x: 0, y: 6)
    }
}

struct MetrologyInteractivePill: View {
    let title: String
    let value: String
    var tone: MetrologyPillTone = .neutral
    var isSelected: Bool = false
    var compact: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                HStack(alignment: .center, spacing: compact ? 3 : 8) {
                    Circle()
                        .fill(tone.tint)
                        .frame(width: compact ? 3 : 6, height: compact ? 3 : 6)

                    VStack(alignment: .leading, spacing: compact ? 2 : 4) {
                        Text(title)
                            .font(.system(size: compact ? 8 : 11, weight: .bold))
                            .foregroundStyle(tone.tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                            .allowsTightening(true)

                        Text(value)
                            .font(.system(size: compact ? 10 : 14, weight: .black, design: .rounded))
                            .foregroundStyle(isSelected ? tone.tint : MetrologyPalette.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                            .allowsTightening(true)
                    }

                    Spacer(minLength: 0)
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: compact ? 7 : 10, weight: .black))
                        .foregroundStyle(tone.tint)
                        .padding(.top, compact ? 2 : 6)
                        .padding(.trailing, compact ? 2 : 6)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: compact ? 42 : 62, alignment: .leading)
            .padding(.horizontal, compact ? 6 : 12)
            .padding(.vertical, compact ? 5 : 10)
            .background(
                RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
                    .fill(isSelected ? tone.strongBackground : tone.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous)
                    .stroke(isSelected ? tone.tint.opacity(0.95) : tone.stroke, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? tone.tint.opacity(0.16) : Color.clear, radius: 8, x: 0, y: 4)
            .scaleEffect(isSelected ? 1.02 : 1)
            .opacity(isSelected ? 1 : 0.86)
        }
        .contentShape(RoundedRectangle(cornerRadius: compact ? 12 : 16, style: .continuous))
        .buttonStyle(.plain)
    }
}

struct MetrologySectionPanel<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: () -> Content

    init(title: String, subtitle: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .rounded))
                    .foregroundStyle(MetrologyPalette.textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                }
            }

            content()
        }
        .padding(12)
        .metrologyCard()
    }
}

struct MetrologyFormSheetScaffold<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var accent: MetrologyPillTone = .neutral
    var bannerMessage: String? = nil
    var bannerTone: MetrologyPillTone = .neutral
    @ViewBuilder let content: () -> Content

    init(
        eyebrow: String,
        title: String,
        subtitle: String,
        accent: MetrologyPillTone = .neutral,
        bannerMessage: String? = nil,
        bannerTone: MetrologyPillTone = .neutral,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.bannerMessage = bannerMessage
        self.bannerTone = bannerTone
        self.content = content
    }

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    MetrologyPageHeroCard(
                        eyebrow: eyebrow,
                        title: title,
                        subtitle: subtitle,
                        accent: accent
                    )

                    if let bannerMessage, !bannerMessage.isEmpty {
                        MetrologyStatusBanner(message: bannerMessage, tone: bannerTone, compact: true)
                    }

                    content()
                }
                .padding(.horizontal, MetrologyLayout.pageHorizontalPadding)
                .padding(.top, 12)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }
}

struct MetrologyInlineValidationMessage: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(MetrologyPalette.statusExpired)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2)
    }
}

struct MetrologyStatusBanner: View {
    let message: String
    var tone: MetrologyPillTone = .neutral
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 7 : 8) {
            Circle()
                .fill(tone.tint)
                .frame(width: compact ? 7 : 8, height: compact ? 7 : 8)

            Text(message)
                .font(.system(size: compact ? 11 : 12, weight: .bold))
                .foregroundStyle(tone.tint)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 9 : 10)
        .background(
            RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                .fill(tone.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                .stroke(tone.stroke, lineWidth: 1)
        )
        .shadow(color: tone.tint.opacity(compact ? 0.06 : 0.09), radius: compact ? 4 : 7, x: 0, y: 2)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}

struct MetrologyEmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(MetrologyPalette.textMuted)

            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

struct MetrologyErrorStateView: View {
    let title: String
    let message: String
    var tone: MetrologyPillTone = .expired
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(tone.tint)

            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)

            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(MetrologySecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 22)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(tone.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(tone.stroke, lineWidth: 1)
        )
        .shadow(color: tone.tint.opacity(0.10), radius: 8, x: 0, y: 3)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
    }
}

struct MetrologyLoadingCard: View {
    let title: String
    var fraction: Double? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                Spacer()

                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MetrologyPalette.navActive)
                        .buttonStyle(.plain)
                }
            }

            if let fraction {
                ProgressView(value: fraction)
                    .controlSize(.small)
                    .tint(MetrologyPalette.navActive)
            } else {
                ProgressView()
                    .controlSize(.small)
                    .tint(MetrologyPalette.navActive)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(MetrologyPalette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(MetrologyPalette.stroke, lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x91A7C3, alpha: 0.08), radius: 6, x: 0, y: 3)
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
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
    var eyebrow: String = "Notice"
    var tone: MetrologyPillTone = .neutral
    var confirmTitle: String = "确定"
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(tone.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(tone.strongBackground)
                    )

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                MetrologyStatusBanner(message: message, tone: tone)

                Button(confirmTitle, action: onConfirm)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .buttonStyle(MetrologyPrimaryButtonStyle())
            }
            .padding(12)
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
        .preferredColorScheme(.light)
    }
}

struct MetrologyConfirmDialog: View {
    let title: String
    let message: String
    var eyebrow: String = "Confirm"
    var tone: MetrologyPillTone = .warning
    var cancelTitle: String = "取消"
    var confirmTitle: String = "确定"
    var destructive: Bool = false
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle((destructive ? MetrologyPillTone.expired : tone).tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill((destructive ? MetrologyPillTone.expired : tone).strongBackground)
                    )

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                MetrologyStatusBanner(
                    message: message,
                    tone: destructive ? .expired : tone
                )

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
            .padding(12)
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
        .preferredColorScheme(.light)
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
