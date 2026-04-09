import SwiftUI

struct DashboardTrendPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Int64
}

struct DashboardDeptStat: Identifiable {
    let id = UUID()
    let name: String
    let total: Int64
    let valid: Int64
    let warning: Int64
    let expired: Int64

    var validRate: Int {
        guard total > 0 else { return 0 }
        return Int(((Double(valid) / Double(total)) * 100).rounded())
    }
}

private struct DashboardSnapshot: Codable {
    struct TrendItem: Codable {
        let label: String
        let value: Int64
    }

    struct DeptItem: Codable {
        let name: String
        let total: Int64
        let valid: Int64
        let warning: Int64
        let expired: Int64
    }

    let savedAt: Date
    let total: Int64
    let dueThisMonth: Int64
    let valid: Int64
    let warning: Int64
    let expired: Int64
    let risk: Int64
    let trend: [TrendItem]
    let deptStats: [DeptItem]
}

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hintText: String = "\u{6570}\u{636E}\u{66F4}\u{65B0}\u{65F6}\u{95F4}\u{FF1A}\u{521A}\u{521A}"

    @Published var total: Int64 = 0
    @Published var dueThisMonth: Int64 = 0
    @Published var valid: Int64 = 0
    @Published var warning: Int64 = 0
    @Published var expired: Int64 = 0
    @Published var risk: Int64 = 0

    @Published var trend: [DashboardTrendPoint] = []
    @Published var deptStats: [DashboardDeptStat] = []

    private let snapshotKey = "dashboard.snapshot.v1"

    init() {
        restoreSnapshotIfAvailable()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await APIClient.shared.dashboard()
            total = result.total ?? 0
            dueThisMonth = result.dueThisMonth ?? 0
            valid = result.valid ?? 0
            warning = result.warning ?? 0
            expired = result.expired ?? 0
            risk = warning + expired

            trend = parseTrend(result.monthlyTrend)
            deptStats = parseDeptStats(result.deptStats)
            hintText = "\u{6570}\u{636E}\u{66F4}\u{65B0}\u{65F6}\u{95F4}\u{FF1A}\u{521A}\u{521A}"
            saveSnapshot()
        } catch {
            if let apiError = error as? APIError {
                errorMessage = apiError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func parseTrend(_ raw: [DashboardTrendPointRaw]?) -> [DashboardTrendPoint] {
        guard let raw, !raw.isEmpty else { return [] }
        var parsed: [DashboardTrendPoint] = []
        for (index, row) in raw.enumerated() {
            let value = max(0, row.count ?? row.total ?? row.value ?? row.num ?? row.deviceCount ?? 0)
            let source = row.month ?? row.label ?? row.period ?? row.name ?? row.x ?? "M\(index + 1)"
            parsed.append(
                DashboardTrendPoint(
                    label: normalizeMonthLabel(source),
                    value: value
                )
            )
        }
        return Array(parsed.suffix(6))
    }

    private func parseDeptStats(_ raw: [DashboardDeptStatRaw]?) -> [DashboardDeptStat] {
        guard let raw, !raw.isEmpty else { return [] }

        var merged: [String: (total: Int64, valid: Int64, warning: Int64, expired: Int64)] = [:]

        for (index, row) in raw.enumerated() {
            let name = normalizedDeptName(
                row.dept ??
                row.deptName ??
                row.department ??
                row.name ??
                row.label
            ) ?? "\u{90E8}\u{95E8}\(index + 1)"

            let valid = max(0, row.valid ?? row.validCount ?? row.normal ?? 0)
            let warning = max(0, row.warning ?? row.warningCount ?? row.aboutToExpire ?? 0)
            let expired = max(0, row.expired ?? row.expiredCount ?? row.invalid ?? 0)
            let total = max(
                0,
                row.total ?? row.count ?? row.deviceCount ?? row.value ?? row.num ?? (valid + warning + expired)
            )

            let current = merged[name] ?? (0, 0, 0, 0)
            merged[name] = (
                total: current.total + total,
                valid: current.valid + valid,
                warning: current.warning + warning,
                expired: current.expired + expired
            )
        }

        return merged.map { name, counter in
            DashboardDeptStat(
                name: name,
                total: counter.total,
                valid: counter.valid,
                warning: counter.warning,
                expired: counter.expired
            )
        }
        .sorted { $0.total > $1.total }
    }

    private func normalizedDeptName(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    private func normalizeMonthLabel(_ value: String) -> String {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "-" }

        let yyyyMmPattern = #"(\d{4})[-/.年](\d{1,2})"#
        if let match = text.range(of: yyyyMmPattern, options: .regularExpression) {
            let hit = String(text[match])
            let parts = hit.components(separatedBy: CharacterSet(charactersIn: "-/.年"))
            if let mm = parts.last, let month = Int(mm) {
                return String(format: "%02d\u{6708}", month)
            }
        }

        let mmPattern = #"^(\d{1,2})(月)?$"#
        if let match = text.range(of: mmPattern, options: .regularExpression) {
            let hit = String(text[match]).replacingOccurrences(of: "月", with: "")
            if let month = Int(hit) {
                return String(format: "%02d\u{6708}", month)
            }
        }

        return text
    }

    private func restoreSnapshotIfAvailable() {
        guard let data = UserDefaults.standard.data(forKey: snapshotKey) else { return }
        guard let snapshot = try? JSONDecoder().decode(DashboardSnapshot.self, from: data) else { return }

        total = snapshot.total
        dueThisMonth = snapshot.dueThisMonth
        valid = snapshot.valid
        warning = snapshot.warning
        expired = snapshot.expired
        risk = snapshot.risk
        trend = snapshot.trend.map { DashboardTrendPoint(label: $0.label, value: $0.value) }
        deptStats = snapshot.deptStats.map {
            DashboardDeptStat(
                name: $0.name,
                total: $0.total,
                valid: $0.valid,
                warning: $0.warning,
                expired: $0.expired
            )
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.unitsStyle = .short
        let relative = formatter.localizedString(for: snapshot.savedAt, relativeTo: Date())
        hintText = "\u{6570}\u{636E}\u{66F4}\u{65B0}\u{65F6}\u{95F4}\u{FF1A}\(relative)"
    }

    private func saveSnapshot() {
        let snapshot = DashboardSnapshot(
            savedAt: Date(),
            total: total,
            dueThisMonth: dueThisMonth,
            valid: valid,
            warning: warning,
            expired: expired,
            risk: risk,
            trend: trend.map { DashboardSnapshot.TrendItem(label: $0.label, value: $0.value) },
            deptStats: deptStats.map {
                DashboardSnapshot.DeptItem(
                    name: $0.name,
                    total: $0.total,
                    valid: $0.valid,
                    warning: $0.warning,
                    expired: $0.expired
                )
            }
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: snapshotKey)
    }
}
