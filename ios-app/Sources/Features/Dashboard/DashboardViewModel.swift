import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var total: Int64 = 0
    @Published var dueThisMonth: Int64 = 0
    @Published var valid: Int64 = 0
    @Published var risk: Int64 = 0

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await APIClient.shared.dashboard()
            total = result.total ?? 0
            dueThisMonth = result.dueThisMonth ?? 0
            valid = result.valid ?? 0
            risk = (result.warning ?? 0) + (result.expired ?? 0)
        } catch {
            if let apiError = error as? APIError {
                errorMessage = apiError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }
}
