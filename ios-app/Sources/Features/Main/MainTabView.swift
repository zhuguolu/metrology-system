import SwiftUI

private enum MainTab: String, CaseIterable, Hashable {
    case ledger
    case calibration
    case todo
    case audit
    case more

    var navTitle: String {
        switch self {
        case .ledger: return "设备台账"
        case .calibration: return "校准管理"
        case .todo: return "我的待办"
        case .audit: return "数据审核"
        case .more: return "更多模块"
        }
    }

    var tabTitle: String {
        switch self {
        case .ledger: return "台账"
        case .calibration: return "校准"
        case .todo: return "待办"
        case .audit: return "审核"
        case .more: return "更多"
        }
    }

    var icon: String {
        switch self {
        case .ledger: return "books.vertical"
        case .calibration: return "checkmark.seal"
        case .todo: return "clipboard"
        case .audit: return "doc.text.magnifyingglass"
        case .more: return "square.grid.2x2"
        }
    }

    var iconActive: String {
        switch self {
        case .ledger: return "books.vertical.fill"
        case .calibration: return "checkmark.seal.fill"
        case .todo: return "clipboard.fill"
        case .audit: return "doc.text.magnifyingglass"
        case .more: return "square.grid.2x2.fill"
        }
    }

    var iconOpticalScale: CGFloat {
        switch self {
        case .audit:
            return 1.10
        case .more:
            return 1.06
        default:
            return 1.0
        }
    }

    var showBackToBoard: Bool {
        switch self {
        case .ledger:
            return true
        case .calibration, .todo, .audit, .more:
            return false
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var selectedTab: MainTab = .ledger
    @State private var loadedTabs: Set<MainTab> = [.ledger]
    @State private var dashboardSheetOpen = false

    var body: some View {
        GeometryReader { proxy in
            let scale = AndroidScale(containerWidth: proxy.size.width, containerHeight: proxy.size.height)
            let horizontal = max(scale.px(16), 12)
            let topPadding = max(scale.vertical(12), 8)
            let contentTop = max(scale.vertical(10), 6)
            let bottomInset = proxy.safeAreaInsets.bottom
            let tabTopSpacing = max(scale.vertical(4), 2)
            let tabBottomSpacing: CGFloat = bottomInset > 0 ? 2 : 6

            ZStack {
                MetrologyPalette.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    if selectedTab != .more {
                        topBar
                            .padding(.horizontal, horizontal)
                            .padding(.top, topPadding)
                    }

                    tabContainer
                        .padding(.horizontal, selectedTab == .more ? 0 : horizontal)
                        .padding(.top, selectedTab == .more ? 0 : contentTop)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                AndroidStyleTabBar(selectedTab: $selectedTab) { tab in
                    loadedTabs.insert(tab)
                }
                .padding(.horizontal, horizontal)
                .padding(.top, tabTopSpacing)
                .padding(.bottom, tabBottomSpacing)
                .background(MetrologyPalette.background)
            }
            .animation(.easeOut(duration: 0.16), value: selectedTab)
            .sheet(isPresented: $dashboardSheetOpen) {
                NavigationStack {
                    DashboardView()
                }
            }
        }
    }

    private var tabContainer: some View {
        ZStack {
            if loadedTabs.contains(.ledger) {
                DeviceListView(mode: .ledger)
                    .opacity(selectedTab == .ledger ? 1 : 0)
                    .allowsHitTesting(selectedTab == .ledger)
            }
            if loadedTabs.contains(.calibration) {
                DeviceListView(mode: .calibration)
                    .opacity(selectedTab == .calibration ? 1 : 0)
                    .allowsHitTesting(selectedTab == .calibration)
            }
            if loadedTabs.contains(.todo) {
                DeviceListView(mode: .todo)
                    .opacity(selectedTab == .todo ? 1 : 0)
                    .allowsHitTesting(selectedTab == .todo)
            }
            if loadedTabs.contains(.audit) {
                AuditView()
                    .opacity(selectedTab == .audit ? 1 : 0)
                    .allowsHitTesting(selectedTab == .audit)
            }
            if loadedTabs.contains(.more) {
                MoreHubView(selectedTab: $selectedTab)
                    .opacity(selectedTab == .more ? 1 : 0)
                    .allowsHitTesting(selectedTab == .more)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var topBar: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(selectedTab.navTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                if selectedTab == .audit {
                    Text("当前用户：\(appState.session?.username ?? "-")")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                }
            }

            Spacer(minLength: 6)

            if selectedTab.showBackToBoard {
                Button("回看板") {
                    dashboardSheetOpen = true
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MetrologyPalette.navActive)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white, Color(hex: 0xF4F8FE)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color(hex: 0xCFDAEB), lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0xEEF5FF), Color(hex: 0xEAF8F3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0xD3E2F6), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x6485AA, alpha: 0.15), radius: 4, x: 0, y: 2)
    }
}

private struct AndroidStyleTabBar: View {
    @Binding var selectedTab: MainTab
    let onSelect: (MainTab) -> Void

    var body: some View {
        GeometryReader { proxy in
            let scale = AndroidScale(containerWidth: proxy.size.width, containerHeight: proxy.size.height)
            let horizontalPadding = max(scale.px(12), 10)
            let verticalPadding = max(scale.px(5), 4)
            let navHeight = max(scale.px(64), 60)
            let iconSize = max(scale.px(21), 19)
            let labelSize = max(scale.px(10.5), 10)
            let corner = max(scale.px(24), 20)

            HStack(spacing: max(scale.px(6), 4)) {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                        onSelect(tab)
                    } label: {
                        VStack(spacing: max(scale.px(2), 1)) {
                            Image(systemName: selectedTab == tab ? tab.iconActive : tab.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: iconSize * tab.iconOpticalScale, height: iconSize * tab.iconOpticalScale)
                                .opacity(selectedTab == tab ? 1 : 0.78)
                            Text(tab.tabTitle)
                                .font(.system(size: labelSize, weight: .bold))
                        }
                        .foregroundStyle(selectedTab == tab ? MetrologyPalette.navActive : MetrologyPalette.navInactive)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: max(scale.px(14), 12), style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: 0xF8FBFF), Color(hex: 0xD2E5FF)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: max(scale.px(14), 12), style: .continuous)
                                            .stroke(Color(hex: 0xAFC8F2), lineWidth: 1)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: max(scale.px(14), 12), style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white, Color(hex: 0xF4F8FF)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: max(scale.px(14), 12), style: .continuous)
                                            .stroke(Color(hex: 0xD7E3F3), lineWidth: 1)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: proxy.size.width, height: navHeight)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(hex: 0xE8F1FF)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: corner, style: .continuous)
                            .stroke(Color(hex: 0xC9DBF5), lineWidth: 1)
                    )
            )
            .shadow(color: Color(hex: 0x345A8F, alpha: 0.18), radius: 4, x: 0, y: 2)
        }
        .frame(height: 80)
    }
}

private struct MoreHubView: View {
    @Binding var selectedTab: MainTab
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let scale = AndroidScale(containerWidth: proxy.size.width, containerHeight: proxy.size.height)
                let gridSpacing = max(scale.px(10), 8)
                let columns: [GridItem] = Array(
                    repeating: GridItem(.flexible(), spacing: gridSpacing),
                    count: 4
                )

                ZStack {
                    LinearGradient(
                        colors: [MetrologyPalette.moreBgStart, MetrologyPalette.moreBgEnd],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: max(scale.vertical(18), 14)) {
                            header(scale: scale)
                            section(title: "协作与数据", scale: scale) {
                                LazyVGrid(columns: columns, spacing: gridSpacing) {
                                    NavigationLink { FilesView() } label: {
                                        moduleCardContent(icon: "folder.fill", title: "我的文件", tint: Color(hex: 0x1D4ED8), scale: scale)
                                    }
                                    NavigationLink { WebDavView() } label: {
                                        moduleCardContent(icon: "network", title: "网络挂载", tint: Color(hex: 0x047857), scale: scale)
                                    }
                                    NavigationLink { ChangeRecordView() } label: {
                                        moduleCardContent(icon: "clock.arrow.circlepath", title: "变更记录", tint: Color(hex: 0x1D4ED8), scale: scale)
                                    }
                                    NavigationLink { DeviceStatusView() } label: {
                                        moduleCardContent(icon: "waveform.path.ecg", title: "使用状态", tint: Color(hex: 0x047857), scale: scale)
                                    }
                                }
                            }

                            section(title: "管理与配置", scale: scale) {
                                LazyVGrid(columns: columns, spacing: gridSpacing) {
                                    NavigationLink { DepartmentView() } label: {
                                        moduleCardContent(icon: "building.2.fill", title: "部门管理", tint: Color(hex: 0xB45309), scale: scale)
                                    }
                                    NavigationLink { UserManagementView() } label: {
                                        moduleCardContent(icon: "person.2.fill", title: "用户管理", tint: Color(hex: 0x6D28D9), scale: scale)
                                    }
                                    NavigationLink { SystemMaintenanceView() } label: {
                                        moduleCardContent(icon: "gearshape.fill", title: "系统维护", tint: Color(hex: 0x334155), scale: scale)
                                    }
                                }
                            }

                            Button {
                                appState.logout()
                            } label: {
                                Text("退出登录")
                                    .font(.system(size: max(scale.px(14), 13), weight: .bold))
                                    .foregroundStyle(MetrologyPalette.textPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, max(scale.vertical(12), 10))
                            }
                            .buttonStyle(MetrologySecondaryButtonStyle())
                        }
                        .padding(.horizontal, max(scale.px(14), 12))
                        .padding(.top, max(scale.vertical(8), 6))
                        .padding(.bottom, max(scale.vertical(24), 18))
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func header(scale: AndroidScale) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("更多模块")
                    .font(.system(size: max(scale.px(22), 20), weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                Text("点击图标快速进入模块")
                    .font(.system(size: max(scale.px(12), 11), weight: .regular))
                    .foregroundStyle(MetrologyPalette.textSecondary)
            }
            Spacer(minLength: 8)
            Text("用户：\(appState.session?.username ?? "-")")
                .font(.system(size: max(scale.px(12), 11), weight: .medium))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color(hex: 0xE9F1FF))
                )
        }
    }

    private func section<Content: View>(title: String, scale: AndroidScale, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: max(scale.px(11), 10), weight: .bold))
                .foregroundStyle(Color(hex: 0x2D5DAF))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(
                    Capsule(style: .continuous).fill(Color(hex: 0xE9F1FF))
                )

            content()
        }
    }

    private func moduleCardContent(icon: String, title: String, tint: Color, scale: AndroidScale) -> some View {
        let iconContainer = max(scale.px(56), 48)
        let symbolSize = max(scale.px(24), 20)
        let cardHeight = max(scale.vertical(116), 104)
        let cardRadius = max(scale.px(18), 15)
        let opticalScale = moduleIconOpticalScale(icon)

        return VStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: max(scale.px(20), 16), style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(hex: 0xDBE9FF)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: max(scale.px(20), 16), style: .continuous)
                            .stroke(Color(hex: 0xD5E3F5), lineWidth: 1)
                    )
                    .frame(width: iconContainer, height: iconContainer)
                Image(systemName: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: symbolSize * opticalScale, height: symbolSize * opticalScale)
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.system(size: max(scale.px(11), 10), weight: .bold))
                .foregroundStyle(Color(hex: 0x233247))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: max(scale.vertical(30), 24), alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .frame(height: cardHeight)
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(hex: 0xF0F7FF)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: cardRadius, style: .continuous)
                .stroke(Color(hex: 0xD5E3F5), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x557CA5, alpha: 0.10), radius: 3, x: 0, y: 2)
    }

    private func moduleIconOpticalScale(_ icon: String) -> CGFloat {
        switch icon {
        case "network", "waveform.path.ecg", "doc.text.magnifyingglass":
            return 1.12
        case "rectangle.grid.1x2.fill":
            return 1.06
        default:
            return 1.0
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
