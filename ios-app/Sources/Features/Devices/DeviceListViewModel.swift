import Foundation
import Combine

@MainActor
final class DeviceListViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var deptFilter: String = ""
    @Published var validityFilter: String = ""
    @Published var useStatusFilter: String = ""
    @Published var nextDateFrom: String = ""
    @Published var nextDateTo: String = ""
    @Published private(set) var departmentFilterOptions: [String] = []
    @Published private(set) var useStatusFilterOptions: [String] = []

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var items: [DeviceDto] = []
    @Published private(set) var total: Int64 = 0
    @Published private(set) var page: Int = 1
    @Published private(set) var totalPages: Int = 1
    @Published private(set) var overallTotal: Int64 = 0
    @Published private(set) var summaryCounts: [String: Int64] = [:]
    @Published private(set) var useStatusSummary: [String: Int64] = [:]
    @Published private(set) var overallSummaryCounts: [String: Int64] = [:]
    @Published private(set) var overallUseStatusSummary: [String: Int64] = [:]
    @Published var errorMessage: String?
    @Published var hintMessage: String = ""

    let mode: DeviceListMode
    private let pageSize: Int = 20
    private var currentLoadToken: UInt64 = 0
    private var activeLoadTask: Task<Void, Never>?

    init(mode: DeviceListMode) {
        self.mode = mode
        if mode == .calibration {
            useStatusFilter = "正常"
        }
    }

    func initialLoad() async {
        if !items.isEmpty {
            await refreshFilterSourceOptions()
            return
        }

        async let loadTask: Void = load(page: 1)
        async let optionsTask: Void = refreshFilterSourceOptions()
        _ = await (loadTask, optionsTask)
    }

    func reloadCurrentPage() async {
        await load(page: page)
    }

    func resetFilters() async {
        searchText = ""
        deptFilter = ""
        validityFilter = ""
        useStatusFilter = mode == .calibration ? "正常" : ""
        nextDateFrom = ""
        nextDateTo = ""
        await refreshFilterSourceOptions()
        await load(page: 1)
    }

    func load(page requestedPage: Int = 1) async {
        activeLoadTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoad(page: requestedPage)
        }
        activeLoadTask = task
        await task.value
    }

    private func performLoad(page requestedPage: Int = 1) async {
        let token = beginLoad()
        defer {
            if shouldApplyResult(for: token) {
                isLoading = false
            }
        }

        do {
            let safeRequestedPage = max(1, requestedPage)
            let requestUseStatus = useStatusFilterForRequest()
            let result = try await APIClient.shared.devicesPaged(
                mode: mode,
                search: searchText,
                dept: deptFilter,
                validity: validityFilter,
                useStatus: requestUseStatus,
                baselineUseStatus: baselineUseStatusFilter,
                nextDateFrom: mode == .ledger ? nil : nextDateFrom,
                nextDateTo: mode == .ledger ? nil : nextDateTo,
                page: safeRequestedPage,
                size: pageSize
            )
            guard shouldApplyResult(for: token) else { return }

            let pageItems = result.content ?? []
            let resolvedValiditySummary = resolveValiditySummary(
                serverSummary: result.summaryCounts,
                items: pageItems
            )
            let resolvedUseStatusSummary = resolveUseStatusSummary(
                serverSummary: result.useStatusSummary,
                items: pageItems
            )
            let resolvedOverallValiditySummary = resolveValiditySummary(
                serverSummary: result.overallSummaryCounts ?? result.summaryCounts,
                items: pageItems
            )
            let resolvedOverallUseStatusSummary = resolveUseStatusSummary(
                serverSummary: result.overallUseStatusSummary ?? result.useStatusSummary,
                items: pageItems
            )

            items = pageItems
            total = result.totalElements ?? 0
            page = max(1, result.page ?? safeRequestedPage)
            totalPages = max(1, result.totalPages ?? 1)
            summaryCounts = resolvedValiditySummary
            useStatusSummary = resolvedUseStatusSummary
            overallTotal = result.overallTotalElements ?? total
            overallSummaryCounts = resolvedOverallValiditySummary
            overallUseStatusSummary = resolvedOverallUseStatusSummary
            hintMessage = "共 \(total) 条，当前第 \(page)/\(totalPages) 页"
        } catch {
            guard shouldApplyResult(for: token) else { return }
            if error is CancellationError {
                return
            }
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            hintMessage = ""
        }
    }

    func refreshFilterSourceOptions() async {
        do {
            async let departmentsTask = APIClient.shared.departments(search: "")
            async let statusesTask = APIClient.shared.deviceStatuses()
            let departments = try await departmentsTask
            let statuses = try await statusesTask

            let departmentNames = departments.compactMap {
                $0.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let statusNames = statuses
                .sorted { lhs, rhs in
                    let left = lhs.sortOrder ?? Int.max
                    let right = rhs.sortOrder ?? Int.max
                    if left != right { return left < right }
                    return (lhs.id ?? Int64.max) < (rhs.id ?? Int64.max)
                }
                .compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }

            departmentFilterOptions = normalizedOptions(departmentNames + [deptFilter])
            useStatusFilterOptions = normalizedOptions(statusNames + [useStatusFilter])
        } catch {
            // Keep current options when lookup fails.
            departmentFilterOptions = normalizedOptions(departmentFilterOptions + [deptFilter])
            useStatusFilterOptions = normalizedOptions(useStatusFilterOptions + [useStatusFilter])
        }
    }

    func nextPage() async {
        guard page < totalPages else { return }
        await load(page: page + 1)
    }

    func prevPage() async {
        guard page > 1 else { return }
        await load(page: page - 1)
    }

    func quickCalibrate(_ item: DeviceDto) async {
        guard mode != .ledger else { return }
        guard let id = item.id else {
            errorMessage = "设备ID无效"
            return
        }

        let payload = DeviceCalibrationPayload(
            calDate: todayDateString(),
            cycle: item.cycle ?? 12,
            calibrationResult: "合格",
            remark: item.remark
        )

        _ = await saveCalibrationEdit(id: id, payload: payload, targetPage: page)
    }

    func quickEditCalibration(id: Int64, payload: DeviceCalibrationPayload) async -> Bool {
        guard mode != .ledger else { return false }
        return await saveCalibrationEdit(id: id, payload: payload, targetPage: page)
    }

    private func saveCalibrationEdit(id: Int64, payload: DeviceCalibrationPayload, targetPage: Int) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await APIClient.shared.updateDeviceCalibration(id: id, payload: payload)
            invalidateBaselineCache()
            await load(page: targetPage)
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    func updateDevice(id: Int64, payload: DeviceUpdatePayload) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await APIClient.shared.updateDevice(id: id, payload: payload)
            invalidateBaselineCache()
            await load(page: page)
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    func deleteDevice(id: Int64) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await APIClient.shared.deleteDevice(id: id)
            invalidateBaselineCache()
            let targetPage = (items.count <= 1 && page > 1) ? (page - 1) : page
            await load(page: targetPage)
            hintMessage = "删除已处理"
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    func createLedgerDevice(payload: DeviceUpdatePayload) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await APIClient.shared.createDevice(payload: payload)
            switch result {
            case .created:
                hintMessage = "设备新增成功"
            case let .submitted(message):
                let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                hintMessage = trimmed.isEmpty ? "新增申请已提交，等待审核" : trimmed
            }
            invalidateBaselineCache()
            await load(page: 1)
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    private func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private func beginLoad() -> UInt64 {
        currentLoadToken += 1
        let token = currentLoadToken
        isLoading = true
        errorMessage = nil
        return token
    }

    private func shouldApplyResult(for token: UInt64) -> Bool {
        token == currentLoadToken && !Task.isCancelled
    }

    private var baselineUseStatusFilter: String? {
        switch mode {
        case .ledger, .todo:
            return nil
        case .calibration:
            return "正常"
        }
    }

    private func useStatusFilterForRequest() -> String? {
        let normalized = normalizeStatusText(useStatusFilter)
        guard !normalized.isEmpty else { return nil }
        return normalized
    }

    private func invalidateBaselineCache() {
        // Kept for call-site compatibility after removing client-side baseline fetch cache.
    }

    private func resolveValiditySummary(
        serverSummary: [String: Int64]?,
        items: [DeviceDto]
    ) -> [String: Int64] {
        var summary: [String: Int64] = [
            "有效": 0,
            "即将过期": 0,
            "失效": 0
        ]

        if let serverSummary, !serverSummary.isEmpty {
            for (rawKey, rawValue) in serverSummary {
                guard let bucket = validityBucket(for: rawKey) else { continue }
                summary[bucket, default: 0] += max(rawValue, 0)
            }
        }

        if summary.values.reduce(0, +) == 0, !items.isEmpty {
            for item in items {
                guard let bucket = validityBucket(for: item.validity ?? item.status) else { continue }
                summary[bucket, default: 0] += 1
            }
        }

        return summary
    }

    private func resolveUseStatusSummary(
        serverSummary: [String: Int64]?,
        items: [DeviceDto]
    ) -> [String: Int64] {
        var summary: [String: Int64] = [
            "正常": 0,
            "故障": 0,
            "报废": 0,
            "其他": 0
        ]

        if let serverSummary, !serverSummary.isEmpty {
            for (rawKey, rawValue) in serverSummary {
                let bucket = useStatusBucketFromServerSummary(for: rawKey)
                summary[bucket, default: 0] += max(rawValue, 0)
            }
            return summary
        }

        if !items.isEmpty {
            for item in items {
                let bucket = useStatusBucketFromItem(for: item.useStatus)
                summary[bucket, default: 0] += 1
            }
        }

        return summary
    }

    private func validityBucket(for rawValue: String?) -> String? {
        let text = normalizeStatusText(rawValue)
        guard !text.isEmpty else { return nil }
        let upper = text.uppercased()

        if text.contains("即将过期") || text.contains("即将到期")
            || upper.contains("WARNING")
            || upper.contains("EXPIRING")
            || upper.contains("NEAR_EXPIRY")
            || upper.contains("NEAR-EXPIRY")
            || upper.contains("NEAR EXPIRY") {
            return "即将过期"
        }

        if text.contains("有效") || upper == "VALID" || upper == "NORMAL" {
            return "有效"
        }

        if text.contains("失效") || text.contains("过期")
            || upper.contains("EXPIRED")
            || upper.contains("INVALID") {
            return "失效"
        }

        return nil
    }

    private func useStatusBucketFromServerSummary(for rawValue: String?) -> String {
        let text = normalizeStatusText(rawValue)
        if text.isEmpty { return "其他" }
        let upper = text.uppercased()

        if text == "正常"
            || text == "在用"
            || text == "使用中"
            || upper == "NORMAL"
            || upper == "IN_USE"
            || upper == "INUSE"
            || upper == "ACTIVE" {
            return "正常"
        }

        if text == "故障"
            || text == "维修"
            || text == "保养"
            || upper == "FAULT"
            || upper == "BROKEN"
            || upper == "REPAIR"
            || upper == "MAINTENANCE" {
            return "故障"
        }

        if text == "报废"
            || upper == "SCRAP"
            || upper == "DISCARD" {
            return "报废"
        }

        if text == "其他"
            || upper == "OTHER"
            || upper == "OTHERS"
            || upper == "UNKNOWN"
            || upper == "UNCLASSIFIED" {
            return "其他"
        }

        return "其他"
    }

    private func useStatusBucketFromItem(for rawValue: String?) -> String {
        let text = normalizeStatusText(rawValue)
        if text.isEmpty { return "其他" }
        let upper = text.uppercased()

        if text.contains("正常") || text.contains("在用") || text.contains("使用中")
            || upper.contains("NORMAL")
            || upper.contains("IN_USE")
            || upper.contains("INUSE")
            || upper.contains("ACTIVE") {
            return "正常"
        }

        if text.contains("故障") || text.contains("维修") || text.contains("保养")
            || upper.contains("FAULT")
            || upper.contains("BROKEN")
            || upper.contains("REPAIR")
            || upper.contains("MAINTENANCE") {
            return "故障"
        }

        if text.contains("报废")
            || upper.contains("SCRAP")
            || upper.contains("DISCARD") {
            return "报废"
        }

        return "其他"
    }

    private func normalizeStatusText(_ rawValue: String?) -> String {
        (rawValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedOptions(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for raw in values {
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, !seen.contains(value) else { continue }
            seen.insert(value)
            result.append(value)
        }
        return result
    }
}

extension DeviceListMode {
    var title: String {
        switch self {
        case .ledger:
            return "设备台账"
        case .calibration:
            return "校准管理"
        case .todo:
            return "我的待办"
        }
    }

    var summaryLabels: [String] {
        switch self {
        case .ledger:
            return ["正常", "故障", "报废", "其他"]
        case .calibration, .todo:
            return ["有效", "即将过期", "失效"]
        }
    }
}
