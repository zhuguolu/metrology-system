import SwiftUI

@main
struct MetrologyIOSApp: App {
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
            .environmentObject(appState)
            .task {
                guard showsStartup else { return }
                try? await Task.sleep(nanoseconds: 1_050_000_000)
                showsStartup = false
            }
        }
    }
}
