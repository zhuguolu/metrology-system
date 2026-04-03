import Foundation

enum SessionStore {
    private static let key = "metrology.ios.session"

    static func save(_ session: Session) {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(session) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> Session? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        return try? decoder.decode(Session.self, from: data)
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
