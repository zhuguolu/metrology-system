import SwiftUI

private enum MainTab: Hashable {
    case ledger
    case calibration
    case todo
    case audit
    case more
}

struct MainTabView: View {
    @State private var selectedTab: MainTab = .ledger

    var body: some View {
        TabView(selection: $selectedTab) {
            DeviceListView(mode: .ledger)
                .tabItem {
                    Label("台账", systemImage: selectedTab == .ledger ? "books.vertical.fill" : "books.vertical")
                }
                .tag(MainTab.ledger)

            DeviceListView(mode: .calibration)
                .tabItem {
                    Label("校准", systemImage: selectedTab == .calibration ? "checkmark.seal.fill" : "checkmark.seal")
                }
                .tag(MainTab.calibration)

            DeviceListView(mode: .todo)
                .tabItem {
                    Label("待办", systemImage: selectedTab == .todo ? "clipboard.fill" : "clipboard")
                }
                .tag(MainTab.todo)

            AuditView()
                .tabItem {
                    Label("审核", systemImage: selectedTab == .audit ? "doc.text.magnifyingglass" : "doc.text")
                }
                .tag(MainTab.audit)

            MoreHubView()
                .tabItem {
                    Label("更多", systemImage: selectedTab == .more ? "square.grid.2x2.fill" : "square.grid.2x2")
                }
                .tag(MainTab.more)
        }
        .tint(MetrologyPalette.accent)
    }
}

struct MoreHubView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ZStack {
                MetrologyPalette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        sectionCard(title: "常用模块") {
                            NavigationLink {
                                DashboardView()
                            } label: {
                                menuRow(icon: "rectangle.grid.1x2.fill", title: "总览看板", subtitle: "查看关键业务指标")
                            }
                            NavigationLink {
                                FilesView()
                            } label: {
                                menuRow(icon: "folder.fill", title: "我的文件", subtitle: "浏览与预览共享文件")
                            }
                        }

                        sectionCard(title: "当前账号") {
                            HStack {
                                Text("用户")
                                    .foregroundStyle(MetrologyPalette.textSecondary)
                                Spacer()
                                Text(appState.session?.username ?? "-")
                                    .foregroundStyle(MetrologyPalette.textPrimary)
                            }
                            Button(role: .destructive) {
                                appState.logout()
                            } label: {
                                Text("退出登录")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                            }
                            .buttonStyle(MetrologySecondaryButtonStyle())
                        }
                    }
                    .padding(16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("更多")
            .toolbarTitleDisplayMode(.inline)
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MetrologyPalette.textSecondary)
            content()
        }
        .padding(14)
        .metrologyCard()
    }

    private func menuRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(MetrologyPalette.accent)
                .frame(width: 34, height: 34)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(MetrologyPalette.surface)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(MetrologyPalette.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(MetrologyPalette.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MetrologyPalette.textMuted)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}
