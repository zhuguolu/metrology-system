import SwiftUI

@main
struct MetrologyIOSApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appState = AppState()
    @State private var showsStartup: Bool = true

    init() {
        MetrologyAppearance.applyGlobal()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if showsStartup {
                    StartupView()
                } else if appState.isAuthenticated {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .preferredColorScheme(.light)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .environmentObject(appState)
            .task {
                guard showsStartup else { return }
                try? await Task.sleep(nanoseconds: 280_000_000)
                showsStartup = false
            }
            .onOpenURL { url in
                appState.handleIncomingFileURL(url)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    appState.refreshIncomingSharedFiles()
                }
            }
        }
    }
}
