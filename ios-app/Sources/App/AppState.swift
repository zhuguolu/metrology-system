import Foundation
import Combine

struct Session: Codable {
    let token: String
    let username: String
    let role: String?
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var session: Session?

    var isAuthenticated: Bool {
        session != nil
    }

    init() {
        session = SessionStore.load()
        APIClient.shared.tokenProvider = { SessionStore.load()?.token }
    }

    func applyLogin(_ response: LoginResponse) {
        guard let token = response.token, !token.isEmpty else { return }
        let username = response.username?.isEmpty == false ? response.username! : "未命名用户"
        let value = Session(token: token, username: username, role: response.role)
        session = value
        SessionStore.save(value)
        APIClient.shared.tokenProvider = { SessionStore.load()?.token }
    }

    func logout() {
        session = nil
        SessionStore.clear()
        APIClient.shared.tokenProvider = { nil }
    }
}
