import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            DeviceListView(mode: .ledger)
            .tabItem {
                Label("台账", systemImage: "books.vertical")
            }

            DeviceListView(mode: .calibration)
            .tabItem {
                Label("校准", systemImage: "checkmark.seal")
            }

            DeviceListView(mode: .todo)
            .tabItem {
                Label("待办", systemImage: "list.bullet.clipboard")
            }

            AuditView()
            .tabItem {
                Label("审核", systemImage: "doc.text.magnifyingglass")
            }

            MoreHubView()
                .tabItem {
                    Label("更多", systemImage: "square.grid.2x2")
                }
        }
    }
}

struct MoreHubView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            List {
                Section("常用") {
                    NavigationLink("总览看板") {
                        DashboardView()
                    }
                    NavigationLink("我的文件") {
                        FilesView()
                    }
                }

                Section("账号") {
                    HStack {
                        Text("当前用户")
                        Spacer()
                        Text(appState.session?.username ?? "-")
                            .foregroundStyle(.secondary)
                    }
                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        Text("退出登录")
                    }
                }
            }
            .navigationTitle("更多模块")
        }
    }
}
