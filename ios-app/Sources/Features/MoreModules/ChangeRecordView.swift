import SwiftUI

struct ChangeRecordView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ChangeRecordViewModel()
    @State private var detailItem: ChangeRecordDetailItem?
    @State private var activeDatePicker: DatePickerKind?

    private enum DatePickerKind: String, Identifiable {
        case from
        case to

        var id: String { rawValue }
    }

    private var isAdmin: Bool {
        (appState.session?.role ?? "").uppercased() == "ADMIN"
    }

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    filterCard
                    hintLine
                    recordsList
                    pagerBar
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            if let errorMessage = viewModel.errorMessage {
                MetrologyNoticeDialog(
                    title: "\u{63d0}\u{793a}",
                    message: errorMessage
                ) {
                    viewModel.errorMessage = nil
                }
            }
        }
        .navigationTitle("变更记录")
        .task {
            viewModel.configure(admin: isAdmin)
            await viewModel.initialLoad()
        }
        .onChange(of: appState.session?.role) {
            viewModel.configure(admin: isAdmin)
            Task { await viewModel.applyFilters() }
        }
        .onChange(of: viewModel.type) {
            Task { await viewModel.applyFilters() }
        }
        .onChange(of: viewModel.status) {
            Task { await viewModel.applyFilters() }
        }
        .sheet(item: $detailItem) { item in
            AuditDetailView(record: item.record)
        }
        .sheet(item: $activeDatePicker) { kind in
            ChangeRecordDatePickerSheet(
                title: kind == .from ? "开始日期" : "结束日期",
                initialDate: dateValue(for: kind),
                onClear: {
                    setDate(nil, for: kind)
                    Task { await viewModel.applyFilters() }
                },
                onSelect: { date in
                    setDate(date, for: kind)
                    Task { await viewModel.applyFilters() }
                }
            )
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("加载中...")
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MetrologyPalette.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(MetrologyPalette.stroke, lineWidth: 1)
                    )
            }
        }
    }

    private var filterCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("搜索设备名称/编号/备注", text: $viewModel.keyword)
                    .metrologyInput()
                    .submitLabel(.search)
                    .onSubmit {
                        Task { await viewModel.applyFilters() }
                    }

                Button("查询") {
                    Task { await viewModel.applyFilters() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())

                Button("重置") {
                    Task { await viewModel.resetFilters() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())
            }

            HStack(spacing: 8) {
                Menu {
                    Button("\u{5168}\u{90e8}") { viewModel.type = "" }
                    Button("\u{65b0}\u{589e}") { viewModel.type = "CREATE" }
                    Button("\u{4fee}\u{6539}") { viewModel.type = "UPDATE" }
                    Button("\u{5220}\u{9664}") { viewModel.type = "DELETE" }
                } label: {
                    MetrologySelectField(
                        title: "\u{64cd}\u{4f5c}\u{7c7b}\u{578b}",
                        value: typeLabel(viewModel.type),
                        compact: true
                    )
                }

                Menu {
                    Button("\u{5168}\u{90e8}") { viewModel.status = "" }
                    Button("\u{5f85}\u{5ba1}\u{6279}") { viewModel.status = "PENDING" }
                    Button("\u{5df2}\u{901a}\u{8fc7}") { viewModel.status = "APPROVED" }
                    Button("\u{5df2}\u{9a73}\u{56de}") { viewModel.status = "REJECTED" }
                } label: {
                    MetrologySelectField(
                        title: "\u{5904}\u{7406}\u{72b6}\u{6001}",
                        value: statusLabel(viewModel.status),
                        compact: true
                    )
                }
            }

            HStack(spacing: 8) {
                dateFilterField(title: "开始日期", value: viewModel.dateFrom) {
                    activeDatePicker = .from
                }
                dateFilterField(title: "结束日期", value: viewModel.dateTo) {
                    activeDatePicker = .to
                }
            }

            if isAdmin {
                TextField("提交人（管理员可筛选）", text: $viewModel.submittedBy)
                    .metrologyInput()
            }

            statsLine
        }
        .padding(10)
        .metrologyCard()
    }

    private var statsLine: some View {
        HStack(spacing: 8) {
            statChip(title: "总数", value: viewModel.stats.total, style: .neutral)
            statChip(title: "待审批", value: viewModel.stats.pending, style: .warning)
            statChip(title: "已通过", value: viewModel.stats.approved, style: .valid)
            statChip(title: "已驳回", value: viewModel.stats.rejected, style: .danger)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statChip(title: String, value: Int64, style: RecordChipStyle) -> some View {
        Text("\(title) \(formatCount(value))")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(style.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(style.background)
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(style.stroke, lineWidth: 1)
            )
    }

    private var hintLine: some View {
        HStack(spacing: 8) {
            Text(viewModel.hint)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private var recordsList: some View {
        VStack(spacing: 8) {
            if rowItems.isEmpty, !viewModel.isLoading {
                Text("暂无变更记录")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .metrologyCard()
            } else {
                ForEach(rowItems) { row in
                    ChangeRecordRowCard(
                        item: row.item,
                        onView: {
                            Task {
                                if let detail = await viewModel.loadDetail(row.item) {
                                    detailItem = ChangeRecordDetailItem(record: detail)
                                }
                            }
                        }
                    )
                }
            }
        }
    }

    private var pagerBar: some View {
        HStack(spacing: 12) {
            Button("上一页") {
                Task { await viewModel.prevPage() }
            }
            .buttonStyle(MetrologySecondaryButtonStyle())
            .disabled(viewModel.page <= 1 || viewModel.isLoading)
            .opacity((viewModel.page <= 1 || viewModel.isLoading) ? 0.45 : 1)

            Text("\(viewModel.page) / \(viewModel.totalPages) 页")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MetrologyPalette.textSecondary)

            Button("下一页") {
                Task { await viewModel.nextPage() }
            }
            .buttonStyle(MetrologyPrimaryButtonStyle())
            .disabled(viewModel.page >= viewModel.totalPages || viewModel.isLoading)
            .opacity((viewModel.page >= viewModel.totalPages || viewModel.isLoading) ? 0.45 : 1)
        }
    }

    private var rowItems: [ChangeRecordRowItem] {
        var duplicated: [String: Int] = [:]
        return viewModel.items.map { item in
            let base = item.id.map { "id:\($0)" } ?? "tmp:\(item.deviceName ?? "")|\(item.submittedAt ?? "")|\(item.submittedBy ?? "")"
            let count = duplicated[base, default: 0]
            duplicated[base] = count + 1
            let id = count == 0 ? base : "\(base)#\(count)"
            return ChangeRecordRowItem(id: id, item: item)
        }
    }

    private func typeLabel(_ value: String) -> String {
        switch value {
        case "CREATE":
            return "新增"
        case "UPDATE":
            return "修改"
        case "DELETE":
            return "删除"
        default:
            return "全部"
        }
    }

    private func statusLabel(_ value: String) -> String {
        switch value {
        case "PENDING":
            return "待审批"
        case "APPROVED":
            return "已通过"
        case "REJECTED":
            return "已驳回"
        default:
            return "全部"
        }
    }

    private func formatCount(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func dateFilterField(
        title: String,
        value: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? title : value)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(
                        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? MetrologyPalette.textMuted
                            : MetrologyPalette.textPrimary
                    )
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "calendar")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MetrologyPalette.textMuted)
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(MetrologyPalette.stroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func dateValue(for kind: DatePickerKind) -> Date {
        let raw: String
        switch kind {
        case .from:
            raw = viewModel.dateFrom
        case .to:
            raw = viewModel.dateTo
        }
        return Self.parseDate(raw) ?? Date()
    }

    private func setDate(_ date: Date?, for kind: DatePickerKind) {
        let value = date.map(Self.formatDate) ?? ""
        switch kind {
        case .from:
            viewModel.dateFrom = value
        case .to:
            viewModel.dateTo = value
        }
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func parseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: trimmed)
    }
}

private struct ChangeRecordDatePickerSheet: View {
    let title: String
    let initialDate: Date
    let onClear: () -> Void
    let onSelect: (Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate: Date

    init(
        title: String,
        initialDate: Date,
        onClear: @escaping () -> Void,
        onSelect: @escaping (Date) -> Void
    ) {
        self.title = title
        self.initialDate = initialDate
        self.onClear = onClear
        self.onSelect = onSelect
        _selectedDate = State(initialValue: initialDate)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                DatePicker("", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()

                HStack(spacing: 10) {
                    Button("清空") {
                        onClear()
                        dismiss()
                    }
                    .buttonStyle(MetrologySecondaryButtonStyle())

                    Button("确定") {
                        onSelect(selectedDate)
                        dismiss()
                    }
                    .buttonStyle(MetrologyPrimaryButtonStyle())
                }
            }
            .padding(14)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

private struct ChangeRecordRowItem: Identifiable {
    let id: String
    let item: ChangeRecordItemDto
}

private struct ChangeRecordDetailItem: Identifiable {
    let id = UUID()
    let record: AuditRecordDto
}

private struct ChangeRecordRowCard: View {
    let item: ChangeRecordItemDto
    let onView: () -> Void

    private var typeCode: String {
        (item.type ?? "").uppercased()
    }

    private var typeText: String {
        switch typeCode {
        case "CREATE":
            return "新增"
        case "UPDATE":
            return "修改"
        case "DELETE":
            return "删除"
        default:
            return item.type?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.type ?? "" : "-"
        }
    }

    private var typeStyle: RecordChipStyle {
        switch typeCode {
        case "CREATE":
            return .valid
        case "UPDATE":
            return .warning
        case "DELETE":
            return .danger
        default:
            return .neutral
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.deviceName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.deviceName ?? "" : "未关联设备")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(typeText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(typeStyle.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(typeStyle.background)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(typeStyle.stroke, lineWidth: 1)
                    )
            }
            Text("编号: \(item.metricNo?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.metricNo ?? "" : "-")   状态: \(item.status?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.status ?? "" : "-")")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)
            Text("提交人: \(item.submittedBy?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.submittedBy ?? "" : "-")   时间: \(item.submittedAt?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.submittedAt ?? "" : "-")")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)

            HStack {
                Spacer(minLength: 0)
                Button("查看详情", action: onView)
                    .buttonStyle(MetrologySecondaryButtonStyle())
                    .controlSize(.small)
            }
        }
        .padding(10)
        .metrologyCard()
        .contentShape(Rectangle())
        .onTapGesture {
            onView()
        }
    }
}

private enum RecordChipStyle {
    case neutral
    case valid
    case warning
    case danger

    var background: Color {
        switch self {
        case .neutral: return Color(hex: 0xF5F9FF)
        case .valid: return Color(hex: 0xECFDF5)
        case .warning: return Color(hex: 0xFFFBEB)
        case .danger: return Color(hex: 0xFEF2F2)
        }
    }

    var stroke: Color {
        switch self {
        case .neutral: return Color(hex: 0xD8E4F6)
        case .valid: return Color(hex: 0xA7F3D0)
        case .warning: return Color(hex: 0xFCD34D)
        case .danger: return Color(hex: 0xFCA5A5)
        }
    }

    var text: Color {
        switch self {
        case .neutral: return MetrologyPalette.navActive
        case .valid: return MetrologyPalette.statusValid
        case .warning: return MetrologyPalette.statusWarning
        case .danger: return MetrologyPalette.statusExpired
        }
    }
}

@MainActor
final class ChangeRecordViewModel: ObservableObject {
    @Published var keyword: String = ""
    @Published var type: String = ""
    @Published var status: String = ""
    @Published var submittedBy: String = ""
    @Published var dateFrom: String = ""
    @Published var dateTo: String = ""

    @Published private(set) var isLoading: Bool = false
    @Published private(set) var items: [ChangeRecordItemDto] = []
    @Published private(set) var page: Int = 1
    @Published private(set) var totalPages: Int = 1
    @Published private(set) var total: Int64 = 0
    @Published private(set) var stats: ChangeRecordSummary = .empty
    @Published var hint: String = ""
    @Published var errorMessage: String?

    private let pageSize = 20
    private var loaded = false
    private var isAdmin = false

    func configure(admin: Bool) {
        isAdmin = admin
        if !admin {
            submittedBy = ""
        }
    }

    func initialLoad() async {
        guard !loaded else { return }
        loaded = true
        await load(page: 1)
    }

    func applyFilters() async {
        await load(page: 1)
    }

    func resetFilters() async {
        keyword = ""
        type = ""
        status = ""
        submittedBy = ""
        dateFrom = ""
        dateTo = ""
        await load(page: 1)
    }

    func prevPage() async {
        guard page > 1 else { return }
        await load(page: page - 1)
    }

    func nextPage() async {
        guard page < totalPages else { return }
        await load(page: page + 1)
    }

    func loadDetail(_ item: ChangeRecordItemDto) async -> AuditRecordDto? {
        guard let id = item.id else {
            errorMessage = "记录ID无效"
            return nil
        }
        do {
            return try await APIClient.shared.changeRecordDetail(id: id)
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return nil
        }
    }

    private func load(page targetPage: Int) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await APIClient.shared.changeRecords(
                page: max(1, targetPage),
                size: pageSize,
                keyword: trim(keyword),
                type: trim(type),
                status: trim(status),
                submittedBy: isAdmin ? trim(submittedBy) : nil,
                dateFrom: trim(dateFrom),
                dateTo: trim(dateTo)
            )
            let list = result.items ?? []
            let totalValue = result.total ?? Int64(list.count)
            let totalPagesValue = max(1, Int((totalValue + Int64(pageSize) - 1) / Int64(pageSize)))

            items = list
            total = totalValue
            page = max(1, result.page ?? targetPage)
            totalPages = totalPagesValue
            stats = ChangeRecordSummary(
                total: result.stats?.total ?? totalValue,
                pending: result.stats?.pending ?? 0,
                approved: result.stats?.approved ?? 0,
                rejected: result.stats?.rejected ?? 0
            )
            hint = "共 \(totalValue) 条记录"
        } catch {
            items = []
            total = 0
            page = max(1, targetPage)
            totalPages = 1
            stats = .empty
            hint = ""
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    private func trim(_ value: String) -> String? {
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

struct ChangeRecordSummary {
    let total: Int64
    let pending: Int64
    let approved: Int64
    let rejected: Int64

    static let empty = ChangeRecordSummary(total: 0, pending: 0, approved: 0, rejected: 0)
}

private extension Color {
    init(hex: Int, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

