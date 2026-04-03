import SwiftUI
import UIKit

enum MetrologyPalette {
    static let background = Color(red: 0.02, green: 0.03, blue: 0.06)
    static let surface = Color(red: 0.08, green: 0.10, blue: 0.14)
    static let card = Color(red: 0.10, green: 0.12, blue: 0.17)
    static let stroke = Color.white.opacity(0.08)
    static let accent = Color(red: 0.09, green: 0.55, blue: 1.00)
    static let textPrimary = Color.white
    static let textSecondary = Color(red: 0.63, green: 0.66, blue: 0.72)
    static let textMuted = Color(red: 0.47, green: 0.50, blue: 0.56)
}

enum MetrologyAppearance {
    static func applyGlobal() {
        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 0.96)
        tab.shadowColor = UIColor.white.withAlphaComponent(0.08)

        let normalColor = UIColor(red: 0.52, green: 0.55, blue: 0.62, alpha: 1)
        let selectedColor = UIColor(red: 0.09, green: 0.55, blue: 1.00, alpha: 1)

        tab.stackedLayoutAppearance.normal.iconColor = normalColor
        tab.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        tab.stackedLayoutAppearance.selected.iconColor = selectedColor
        tab.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(red: 0.03, green: 0.04, blue: 0.07, alpha: 1)
        nav.shadowColor = UIColor.clear
        nav.titleTextAttributes = [.foregroundColor: UIColor.white]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
        UINavigationBar.appearance().tintColor = selectedColor
    }
}

struct MetrologyCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(MetrologyPalette.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(MetrologyPalette.stroke, lineWidth: 1)
            )
    }
}

struct MetrologyInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(MetrologyPalette.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(MetrologyPalette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MetrologyPalette.stroke, lineWidth: 1)
            )
    }
}

struct MetrologyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(MetrologyPalette.accent.opacity(configuration.isPressed ? 0.72 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct MetrologySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(MetrologyPalette.accent)
            .padding(.horizontal, 22)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(MetrologyPalette.surface.opacity(configuration.isPressed ? 0.72 : 1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(MetrologyPalette.stroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct MetrologyGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(MetrologyPalette.accent.opacity(configuration.isPressed ? 0.68 : 1))
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
