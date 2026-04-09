import Foundation
import Combine

@MainActor
final class AuditViewModel: ObservableObject {
    @Published var mode: AuditListMode = .my {
        didSet { persistIfNeeded() }
    }
    @Published private(set) var isAdmin: Bool = false
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var items: [AuditRecordDto] = []
    @Published var errorMessage: String?

    @Published var historyStatusFilter: String = "" {
        didSet { persistIfNeeded() }
    }
    @Published var historyTypeFilter: String = "" {
        didSet { persistIfNeeded() }
    }
    @Published var historyKeyword: String = "" {
        didSet { persistIfNeeded() }
    }
    @Published private(set) var historyPage: Int = 1 {
        didSet { persistIfNeeded() }
    }
    @Published private(set) var historyTotalPages: Int = 1
    @Published private(set) var historyTotal: Int64 = 0
    @Published private(set) var historyHint: String = ""
    @Published private(set) var historyFallbackHint: String?

    private let historyPageSize: Int = 20
    private let defaults = UserDefaults.standard
    private var isRestoringState = false
    private var currentLoadToken: UInt64 = 0
    private var storageScope: String = "anonymous"

    private enum CacheKey {
        static let mode = "mode"
        static let historyStatusFilter = "history_status_filter"
        static let historyTypeFilter = "history_type_filter"
        static let historyKeyword = "history_keyword"
        static let historyPage = "history_page"
    }

    init() {
        restoreState()
    }

    func configure(role: String?, username: String?) {
        let admin = role?.uppercased() == "ADMIN"
        isAdmin = admin

        let nextScope = resolveStorageScope(username: username)
        if storageScope != nextScope {
            storageScope = nextScope
            restoreState()
        }

        if !admin {
            mode = .my
        } else if !AuditListMode.allCases.contains(mode) {
            mode = .pending
        }

        persistIfNeeded()
    }

    func loadCurrent() async {
        let requestedMode = mode
        let token = beginLoad()
        defer {
            if shouldApplyResult(for: token) {
                isLoading = false
            }
        }

        do {
            switch requestedMode {
            case .pending:
                let pending = try await APIClient.shared.pendingAudit()
                guard shouldApplyResult(for: token) else { return }
                items = pending
                historyHint = ""
                historyFallbackHint = nil
            case .my:
                let mine = try await APIClient.shared.myAudit()
                guard shouldApplyResult(for: token) else { return }
                items = mine
                historyHint = ""
                historyFallbackHint = nil
            case .history:
                let keyword = normalizedFilter(historyKeyword)
                let type = normalizedFilter(historyTypeFilter)
                let status = normalizedFilter(historyStatusFilter)

                do {
                    let pageResult = try await APIClient.shared.allAudit(
                        page: historyPage,
                        size: historyPageSize,
                        keyword: keyword,
                        type: type,
                        status: status
                    )
                    guard shouldApplyResult(for: token) else { return }
                    applyHistoryPageResult(pageResult)
                    historyFallbackHint = nil
                    updateHistoryHint(currentPageCount: items.count, isDegraded: false)
                } catch {
                    guard shouldApplyResult(for: token) else { return }
                    guard shouldFallbackToLocalFilter(error: error, keyword: keyword, type: type, status: status) else {
                        throw error
                    }

                    let fallbackResult = try await APIClient.shared.allAudit(
                        page: historyPage,
                        size: historyPageSize
                    )
                    guard shouldApplyResult(for: token) else { return }
                    let rawPageItems = fallbackResult.content ?? []
                    let filteredItems = filterHistoryItemsLocally(
                        source: rawPageItems,
                        keyword: keyword,
                        type: type,
                        status: status
                    )

                    items = filteredItems
                    historyTotal = fallbackResult.totalElements ?? Int64(rawPageItems.count)
                    historyPage = max(1, fallbackResult.page ?? historyPage)
                    historyTotalPages = max(1, fallbackResult.totalPages ?? 1)
                    historyFallbackHint = "\u{670d}\u{52a1}\u{7aef}\u{7b5b}\u{9009}\u{5931}\u{8d25}\u{ff0c}\u{5df2}\u{964d}\u{7ea7}\u{4e3a}\u{672c}\u{5730}\u{7b5b}\u{9009}\u{ff08}\u{4ec5}\u{5f53}\u{524d}\u{9875}\u{ff09}\u{3002}"
                    updateHistoryHint(currentPageCount: rawPageItems.count, isDegraded: true)
                    errorMessage = nil
                }
            }
        } catch {
            guard shouldApplyResult(for: token) else { return }
            if error is CancellationError {
                return
            }
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            items = []
            if requestedMode == .history {
                historyHint = ""
                historyFallbackHint = nil
            }
        }
    }

    func applyHistoryFilters() async {
        guard mode == .history else { return }
        historyPage = 1
        await loadCurrent()
    }

    func resetHistoryFilters() async {
        guard mode == .history else { return }
        historyStatusFilter = ""
        historyTypeFilter = ""
        historyKeyword = ""
        historyPage = 1
        await loadCurrent()
    }

    func nextHistoryPage() async {
        guard mode == .history else { return }
        guard historyPage < historyTotalPages else { return }
        historyPage += 1
        await loadCurrent()
    }

    func prevHistoryPage() async {
        guard mode == .history else { return }
        guard historyPage > 1 else { return }
        historyPage -= 1
        await loadCurrent()
    }

    func approve(_ item: AuditRecordDto) async {
        guard let id = item.id else {
            errorMessage = "\u{5ba1}\u{6279}\u{8bb0}\u{5f55}\u{49}\u{44}\u{65e0}\u{6548}"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await APIClient.shared.approveAudit(id: id)
            await loadCurrent()
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func reject(_ item: AuditRecordDto, reason: String?) async {
        guard let id = item.id else {
            errorMessage = "\u{5ba1}\u{6279}\u{8bb0}\u{5f55}\u{49}\u{44}\u{65e0}\u{6548}"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await APIClient.shared.rejectAudit(id: id, reason: reason)
            await loadCurrent()
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func loadDetail(_ item: AuditRecordDto) async -> AuditRecordDto? {
        guard let id = item.id else {
            errorMessage = "\u{5ba1}\u{6279}\u{8bb0}\u{5f55}\u{49}\u{44}\u{65e0}\u{6548}"
            return nil
        }
        do {
            return try await APIClient.shared.auditDetail(id: id)
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return nil
        }
    }

    private func applyHistoryPageResult(_ pageResult: PageResult<AuditRecordDto>) {
        items = pageResult.content ?? []
        historyTotal = pageResult.totalElements ?? Int64(items.count)
        historyPage = max(1, pageResult.page ?? historyPage)
        historyTotalPages = max(1, pageResult.totalPages ?? 1)
    }

    private func normalizedFilter(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func hasAnyFilter(keyword: String?, type: String?, status: String?) -> Bool {
        keyword != nil || type != nil || status != nil
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

    private func shouldFallbackToLocalFilter(
        error: Error,
        keyword: String?,
        type: String?,
        status: String?
    ) -> Bool {
        guard hasAnyFilter(keyword: keyword, type: type, status: status) else {
            return false
        }
        if error is CancellationError {
            return false
        }
        if error is URLError {
            return false
        }

        guard let apiError = error as? APIError else {
            return false
        }

        switch apiError {
        case .unauthorized:
            return false
        case .forbidden:
            return false
        case let .httpStatus(code, message, _):
            guard (400...499).contains(code), code != 401 else {
                return false
            }
            return isFilterUnsupportedMessage(message)
        case let .serverMessage(message):
            return isFilterUnsupportedMessage(message)
        case .invalidURL, .decodingFailed, .unknown:
            return false
        }
    }

    private func isFilterUnsupportedMessage(_ message: String?) -> Bool {
        guard let message else { return false }
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        let lower = text.lowercased()

        let unsupportedHints = [
            "unsupported",
            "not support",
            "unknown parameter",
            "invalid parameter",
            "unrecognized parameter",
            "unexpected parameter",
            "\u{53c2}\u{6570}\u{4e0d}\u{652f}\u{6301}",
            "\u{672a}\u{77e5}\u{53c2}\u{6570}",
            "\u{975e}\u{6cd5}\u{53c2}\u{6570}",
            "\u{4e0d}\u{652f}\u{6301}"
        ]

        let filterFieldHints = [
            "keyword",
            "status",
            "type",
            "filter",
            "\u{7b5b}\u{9009}",
            "\u{8fc7}\u{6ee4}",
            "\u{67e5}\u{8be2}\u{6761}\u{4ef6}"
        ]

        let hasUnsupportedHint = unsupportedHints.contains { hint in
            lower.contains(hint) || text.contains(hint)
        }
        let hasFilterFieldHint = filterFieldHints.contains { hint in
            lower.contains(hint) || text.contains(hint)
        }
        if hasUnsupportedHint && hasFilterFieldHint {
            return true
        }
        if hasUnsupportedHint && (lower.contains("parameter") || text.contains("\u{53c2}\u{6570}")) {
            return true
        }
        return false
    }

    private func filterHistoryItemsLocally(
        source: [AuditRecordDto],
        keyword: String?,
        type: String?,
        status: String?
    ) -> [AuditRecordDto] {
        let upperType = type?.uppercased()
        let upperStatus = status?.uppercased()
        let lookup = keyword?.trimmingCharacters(in: .whitespacesAndNewlines)

        return source.filter { item in
            if let upperType, !upperType.isEmpty, (item.type ?? "").uppercased() != upperType {
                return false
            }
            if let upperStatus, !upperStatus.isEmpty, (item.status ?? "").uppercased() != upperStatus {
                return false
            }
            if let lookup, !lookup.isEmpty, !containsKeyword(item: item, keyword: lookup) {
                return false
            }
            return true
        }
    }

    private func containsKeyword(item: AuditRecordDto, keyword: String) -> Bool {
        let candidates: [String?] = [
            item.type,
            item.entityType,
            item.status,
            item.submittedBy,
            item.approvedBy,
            item.remark,
            item.rejectReason,
            extractDeviceField(item: item, key: "name"),
            extractDeviceField(item: item, key: "metricNo"),
            extractDeviceField(item: item, key: "meteringNo")
        ]
        return candidates.contains { ($0 ?? "").localizedCaseInsensitiveContains(keyword) }
    }

    private func extractDeviceField(item: AuditRecordDto, key: String) -> String? {
        let source = (item.type ?? "").uppercased() == "DELETE" ? item.originalData : item.newData
        guard let source, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        guard let data = source.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let value = object[key] as? String {
            return value
        }
        return object[key].map { "\($0)" }
    }

    private func updateHistoryHint(currentPageCount: Int, isDegraded: Bool) {
        if isDegraded {
            historyHint = "\u{5171} \(historyTotal) \u{6761}\u{ff0c}\u{5f53}\u{524d}\u{7b2c} \(historyPage)/\(historyTotalPages) \u{9875}\u{ff0c}\u{672c}\u{9875}\u{7b5b}\u{9009}\u{540e} \(items.count)/\(currentPageCount) \u{6761}"
        } else {
            historyHint = "\u{5171} \(historyTotal) \u{6761}\u{ff0c}\u{5f53}\u{524d}\u{7b2c} \(historyPage)/\(historyTotalPages) \u{9875}"
        }
    }

    private func restoreState() {
        isRestoringState = true
        defer { isRestoringState = false }

        if let rawMode = defaults.string(forKey: storageKey(CacheKey.mode)),
           let storedMode = AuditListMode(rawValue: rawMode) {
            mode = storedMode
        }

        historyStatusFilter = defaults.string(forKey: storageKey(CacheKey.historyStatusFilter)) ?? ""
        historyTypeFilter = defaults.string(forKey: storageKey(CacheKey.historyTypeFilter)) ?? ""
        historyKeyword = defaults.string(forKey: storageKey(CacheKey.historyKeyword)) ?? ""

        let cachedPage = defaults.integer(forKey: storageKey(CacheKey.historyPage))
        historyPage = max(1, cachedPage)
    }

    private func persistIfNeeded() {
        guard !isRestoringState else { return }
        defaults.set(mode.rawValue, forKey: storageKey(CacheKey.mode))
        defaults.set(historyStatusFilter, forKey: storageKey(CacheKey.historyStatusFilter))
        defaults.set(historyTypeFilter, forKey: storageKey(CacheKey.historyTypeFilter))
        defaults.set(historyKeyword, forKey: storageKey(CacheKey.historyKeyword))
        defaults.set(historyPage, forKey: storageKey(CacheKey.historyPage))
    }

    private func storageKey(_ key: String) -> String {
        "audit_view.\(storageScope).\(key)"
    }

    private func resolveStorageScope(username: String?) -> String {
        let text = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return "anonymous" }
        let lower = text.lowercased()
        let safe = lower.replacingOccurrences(of: "[^a-z0-9_.-]", with: "_", options: .regularExpression)
        return safe.isEmpty ? "anonymous" : safe
    }
}

enum AuditListMode: String, CaseIterable, Identifiable {
    case pending
    case my
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending:
            return "\u{5f85}\u{5ba1}\u{6279}"
        case .my:
            return "\u{6211}\u{7684}\u{7533}\u{8bf7}"
        case .history:
            return "\u{5ba1}\u{6279}\u{5386}\u{53f2}"
        }
    }
}
