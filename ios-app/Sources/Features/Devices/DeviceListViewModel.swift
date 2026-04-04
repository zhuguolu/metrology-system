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

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var items: [DeviceDto] = []
    @Published private(set) var total: Int64 = 0
    @Published private(set) var page: Int = 1
    @Published private(set) var totalPages: Int = 1
    @Published private(set) var summaryCounts: [String: Int64] = [:]
    @Published private(set) var useStatusSummary: [String: Int64] = [:]
    @Published var errorMessage: String?
    @Published var hintMessage: String = ""

    let mode: DeviceListMode
    private let pageSize: Int = 20
    private var currentLoadToken: UInt64 = 0

    init(mode: DeviceListMode) {
        self.mode = mode
        if mode == .calibration {
            useStatusFilter = "正常"
        }
    }

    func initialLoad() async {
        if !items.isEmpty { return }
        await load(page: 1)
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
        await load(page: 1)
    }

    func load(page requestedPage: Int = 1) async {
        let token = beginLoad()
        defer {
            if shouldApplyResult(for: token) {
                isLoading = false
            }
        }

        do {
            let result = try await APIClient.shared.devicesPaged(
                mode: mode,
                search: searchText,
                dept: deptFilter,
                validity: validityFilter,
                useStatus: useStatusFilter,
                nextDateFrom: mode == .ledger ? nil : nextDateFrom,
                nextDateTo: mode == .ledger ? nil : nextDateTo,
                page: max(1, requestedPage),
                size: pageSize
            )
            guard shouldApplyResult(for: token) else { return }

            items = result.content ?? []
            total = result.totalElements ?? 0
            page = max(1, result.page ?? requestedPage)
            totalPages = max(1, result.totalPages ?? 1)
            summaryCounts = result.summaryCounts ?? [:]
            useStatusSummary = result.useStatusSummary ?? [:]
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
            await load(page: targetPage)
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    func updateLedgerDevice(id: Int64, payload: DeviceUpdatePayload) async -> Bool {
        guard mode == .ledger else { return false }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await APIClient.shared.updateDevice(id: id, payload: payload)
            await load(page: page)
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
