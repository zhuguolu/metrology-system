import SwiftUI

private struct DeviceLayoutMetrics {
    let scale: AndroidScale
    let width: CGFloat

    init(containerWidth: CGFloat, containerHeight: CGFloat) {
        scale = AndroidScale(containerWidth: containerWidth, containerHeight: containerHeight)
        width = containerWidth
    }

    var cardRadius: CGFloat { max(scale.px(18), 14) }
    var fieldRadius: CGFloat { max(scale.px(12), 10) }
}

struct DeviceListView: View {
    @StateObject private var viewModel: DeviceListViewModel
    @State private var selectedDevice: DeviceDto?
    @State private var ledgerEditDevice: DeviceDto?
    @State private var quickEditDevice: DeviceDto?
    @State private var createDeviceSheetOpen = false
    @State private var filterExpanded = false
    @State private var searchDebounceTask: Task<Void, Never>?

    init(mode: DeviceListMode) {
        _viewModel = StateObject(wrappedValue: DeviceListViewModel(mode: mode))
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = DeviceLayoutMetrics(containerWidth: proxy.size.width, containerHeight: proxy.size.height)

            ZStack {
                MetrologyPalette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        pageHeroCard
                        filterCard(metrics: metrics)
                        statusLine
                        listPanel(metrics: metrics)
                        pagerBar
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)

                if let errorMessage = viewModel.errorMessage {
                    MetrologyNoticeDialog(
                        title: "提示",
                        message: errorMessage,
                        eyebrow: "Notice",
                        tone: .warning
                    ) {
                        viewModel.errorMessage = nil
                    }
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.initialLoad()
        }
        .onChange(of: filterExpanded) { _, isExpanded in
            if isExpanded {
                Task { await viewModel.refreshFilterSourceOptions() }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { selectedDevice != nil },
                set: { value in
                    if !value { selectedDevice = nil }
                }
            )
        ) {
            if let device = selectedDevice {
                DeviceDetailView(
                    device: device,
                    mode: viewModel.mode,
                    onSaveEdit: { payload in
                        guard let id = device.id else {
                            viewModel.errorMessage = "设备ID无效"
                            return
                        }
                        Task {
                            let success = await viewModel.updateDevice(id: id, payload: payload)
                            if success { selectedDevice = nil }
                        }
                    },
                    onDelete: viewModel.mode == .ledger ? { id in
                        await viewModel.deleteDevice(id: id)
                    } : nil
                )
            }
        }
        .sheet(
            isPresented: Binding(
                get: { ledgerEditDevice != nil },
                set: { value in
                    if !value { ledgerEditDevice = nil }
                }
            )
        ) {
            if let device = ledgerEditDevice {
                DeviceEditView(device: device) { payload in
                    guard let id = device.id else {
                        viewModel.errorMessage = "设备ID无效"
                        return
                    }
                    Task {
                        let success = await viewModel.updateDevice(id: id, payload: payload)
                        if success { ledgerEditDevice = nil }
                    }
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { quickEditDevice != nil },
                set: { value in
                    if !value { quickEditDevice = nil }
                }
            )
        ) {
            if let device = quickEditDevice {
                QuickCalibrationEditView(
                    device: device,
                    mode: viewModel.mode,
                    onSave: { payload in
                        guard let id = device.id else {
                            viewModel.errorMessage = "设备ID无效"
                            return
                        }
                        Task {
                            let success = await viewModel.quickEditCalibration(id: id, payload: payload)
                            if success { quickEditDevice = nil }
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $createDeviceSheetOpen) {
            DeviceEditView(device: .empty, title: "新增设备") { payload in
                Task {
                    let success = await viewModel.createLedgerDevice(payload: payload)
                    if success {
                        createDeviceSheetOpen = false
                    }
                }
            }
        }
    }

    private var pageHeroCard: some View {
        MetrologyPageHeroCard(
            eyebrow: heroEyebrow,
            title: heroTitle,
            subtitle: heroSubtitle,
            accent: heroAccent
        ) {
            VStack(alignment: .trailing, spacing: 8) {
                Text("当前")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)

                Text("\(formatCount(displayedOverallTotal))")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(heroAccent.tint)

                Text(heroCountLabel)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(heroAccent.stroke.opacity(0.8), lineWidth: 1)
            )
        }
    }

    private func filterCard(metrics: DeviceLayoutMetrics) -> some View {
        let useStackedActions = metrics.width < 380

        return MetrologySectionPanel(
            title: filterExpanded ? "筛选已展开" : "快速筛选",
            subtitle: filterExpanded ? "按部门、有效性和使用状态快速收窄范围。" : "先搜索，再按状态胶囊快速切换。"
        ) {
            VStack(spacing: 10) {
                if useStackedActions {
                    searchField
                    actionButtons(compact: true)
                } else {
                    HStack(spacing: 8) {
                        searchField
                        actionButtons(compact: false)
                    }
                }

                if filterExpanded {
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            filterSelect(
                                title: "部门",
                                value: $viewModel.deptFilter,
                                allLabel: "全部部门",
                                options: departmentOptions
                            )
                            filterSelect(
                                title: "有效性",
                                value: $viewModel.validityFilter,
                                allLabel: "全部有效性",
                                options: validityOptions
                            )
                        }

                        HStack(spacing: 8) {
                            filterSelect(
                                title: "使用状态",
                                value: $viewModel.useStatusFilter,
                                allLabel: "全部状态",
                                options: useStatusOptions
                            )
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                summaryTiles
            }
        }
    }

    private var searchField: some View {
        TextField("搜索名称/编号/责任人", text: $viewModel.searchText)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(MetrologyPalette.textPrimary)
            .padding(.horizontal, 12)
            .frame(height: 40)
            .submitLabel(.search)
            .onSubmit {
                Task { await viewModel.load(page: 1) }
            }
            .onChange(of: viewModel.searchText) { _, _ in
                scheduleSearchReload()
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(hex: 0xD6E2F2), lineWidth: 1)
            )
            .layoutPriority(0)
    }

    private func actionButtons(compact: Bool) -> some View {
        HStack(spacing: 8) {
            if viewModel.mode == .ledger {
                toolbarButton(title: "新增", primary: true) {
                    createDeviceSheetOpen = true
                }
            }

            toolbarButton(title: filterExpanded ? "收起" : "筛选", primary: false) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    filterExpanded.toggle()
                }
            }

            toolbarButton(title: "重置", primary: false) {
                searchDebounceTask?.cancel()
                Task { await viewModel.resetFilters() }
            }
        }
        .frame(maxWidth: compact ? .infinity : nil, alignment: .leading)
    }

    @ViewBuilder
    private func toolbarButton(title: String, primary: Bool, action: @escaping () -> Void) -> some View {
        if primary {
            Button(action: action) {
                toolbarButtonLabel(title)
            }
            .frame(minWidth: 56, minHeight: 40)
            .buttonStyle(MetrologyPrimaryButtonStyle())
            .layoutPriority(1)
        } else {
            Button(action: action) {
                toolbarButtonLabel(title)
            }
            .frame(minWidth: 56, minHeight: 40)
            .buttonStyle(MetrologySecondaryButtonStyle())
            .layoutPriority(1)
        }
    }

    private func toolbarButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 14, weight: .bold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .allowsTightening(true)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var summaryTiles: some View {
        let columnsCount: Int
        switch viewModel.mode {
        case .ledger:
            columnsCount = 5
        case .calibration:
            columnsCount = 4
        case .todo:
            columnsCount = 3
        }
        let columns: [GridItem] = Array(
            repeating: GridItem(.flexible(minimum: 0), spacing: 6),
            count: columnsCount
        )

        return LazyVGrid(columns: columns, spacing: 8) {
            if viewModel.mode == .ledger {
                summaryTile(
                    title: "共",
                    valueText: "\(formatCount(displayedOverallTotal))台",
                    style: .neutral,
                    isSelected: ledgerSummaryAllSelected,
                    compact: true
                ) {
                    applySummaryFilter(nil)
                }
                summaryTile(
                    title: "正常",
                    value: displayedOverallUseStatus("正常"),
                    style: .valid,
                    isSelected: viewModel.useStatusFilter == "正常",
                    compact: true
                ) {
                    applySummaryFilter("正常")
                }
                summaryTile(
                    title: "故障",
                    value: displayedOverallUseStatus("故障"),
                    style: .warning,
                    isSelected: viewModel.useStatusFilter == "故障",
                    compact: true
                ) {
                    applySummaryFilter("故障")
                }
                summaryTile(
                    title: "报废",
                    value: displayedOverallUseStatus("报废"),
                    style: .expired,
                    isSelected: viewModel.useStatusFilter == "报废",
                    compact: true
                ) {
                    applySummaryFilter("报废")
                }
                summaryTile(
                    title: "其他",
                    value: displayedLedgerOtherCount,
                    style: .neutral,
                    isSelected: viewModel.useStatusFilter == "其他",
                    compact: true
                ) {
                    applySummaryFilter("其他")
                }
            } else if viewModel.mode == .calibration {
                summaryTile(
                    title: "共",
                    valueText: "\(formatCount(displayedOverallTotal))台",
                    style: .neutral,
                    isSelected: validitySummaryAllSelected,
                    compact: true
                ) {
                    applySummaryFilter(nil)
                }
                summaryTile(
                    title: "有效",
                    value: displayedOverallValidity("有效"),
                    style: .valid,
                    isSelected: viewModel.validityFilter == "有效",
                    compact: true
                ) {
                    applySummaryFilter("有效")
                }
                summaryTile(
                    title: "即将过期",
                    value: displayedOverallValidity("即将过期"),
                    style: .warning,
                    isSelected: viewModel.validityFilter == "即将过期",
                    compact: true
                ) {
                    applySummaryFilter("即将过期")
                }
                summaryTile(
                    title: "失效",
                    value: displayedOverallValidity("失效"),
                    style: .expired,
                    isSelected: viewModel.validityFilter == "失效",
                    compact: true
                ) {
                    applySummaryFilter("失效")
                }
            } else {
                summaryTile(
                    title: "共",
                    valueText: "\(formatCount(displayedOverallTotal))台",
                    style: .neutral,
                    isSelected: validitySummaryAllSelected,
                    compact: true
                ) {
                    applySummaryFilter(nil)
                }
                summaryTile(
                    title: "即将过期",
                    value: displayedOverallValidity("即将过期"),
                    style: .warning,
                    isSelected: viewModel.validityFilter == "即将过期",
                    compact: true
                ) {
                    applySummaryFilter("即将过期")
                }
                summaryTile(
                    title: "失效",
                    value: displayedOverallValidity("失效"),
                    style: .expired,
                    isSelected: viewModel.validityFilter == "失效",
                    compact: true
                ) {
                    applySummaryFilter("失效")
                }
            }
        }
    }

    private var ledgerSummaryAllSelected: Bool {
        viewModel.useStatusFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var validitySummaryAllSelected: Bool {
        viewModel.validityFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayedOverallTotal: Int64 {
        if viewModel.overallTotal > 0 || !viewModel.overallUseStatusSummary.isEmpty || !viewModel.overallSummaryCounts.isEmpty {
            return viewModel.overallTotal
        }
        return viewModel.total
    }

    private func displayedOverallUseStatus(_ key: String) -> Int64 {
        if let value = viewModel.overallUseStatusSummary[key] {
            return value
        }
        return viewModel.useStatusSummary[key] ?? 0
    }

    private var displayedLedgerOtherCount: Int64 {
        if let overallOther = viewModel.overallUseStatusSummary["其他"] {
            return max(0, overallOther)
        }
        if let pageOther = viewModel.useStatusSummary["其他"] {
            return max(0, pageOther)
        }
        let known = displayedOverallUseStatus("正常")
            + displayedOverallUseStatus("故障")
            + displayedOverallUseStatus("报废")
        return max(0, displayedOverallTotal - known)
    }

    private func displayedOverallValidity(_ key: String) -> Int64 {
        if let value = viewModel.overallSummaryCounts[key] {
            return value
        }
        return viewModel.summaryCounts[key] ?? 0
    }

    private func summaryTile(
        title: String,
        value: Int64,
        style: ChipStyle,
        isSelected: Bool,
        compact: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        summaryTile(
            title: title,
            valueText: formatCount(value),
            style: style,
            isSelected: isSelected,
            compact: compact,
            action: action
        )
    }

    private func summaryTile(
        title: String,
        valueText: String,
        style: ChipStyle,
        isSelected: Bool,
        compact: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        MetrologyInteractivePill(
            title: title,
            value: valueText,
            tone: style.tone,
            isSelected: isSelected,
            compact: compact,
            action: action
        )
    }

    private var statusLine: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text("列表状态")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundStyle(MetrologyPalette.textPrimary)

                if deviceRows.isEmpty {
                    Text("暂无数据")
                } else {
                    Text("共 \(formatCount(viewModel.total)) 条")
                }
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(MetrologyPalette.textSecondary)

            Spacer(minLength: 0)

            if !viewModel.hintMessage.isEmpty {
                Text(viewModel.hintMessage)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.navActive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(hex: 0xE9F1FF))
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.86))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0xD5E2F2), lineWidth: 1)
        )
    }

    private func listPanel(metrics: DeviceLayoutMetrics) -> some View {
        MetrologySectionPanel(
            title: listPanelTitle,
            subtitle: listPanelSubtitle
        ) {
            VStack(spacing: 0) {
                if deviceRows.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.system(size: 26))
                            .foregroundStyle(MetrologyPalette.textMuted)
                        Text("暂无设备数据")
                            .font(.system(size: 13))
                            .foregroundStyle(MetrologyPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(
                        RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.white, Color(hex: 0xF6FAFF)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: metrics.cardRadius, style: .continuous)
                            .stroke(Color(hex: 0xD5E2F2), lineWidth: 1)
                    )
                } else {
                    ForEach(deviceRows) { row in
                        DeviceRowCard(
                            item: row.item,
                            mode: viewModel.mode,
                            onTap: { selectedDevice = row.item },
                            onQuickAction: {
                                if viewModel.mode == .ledger {
                                    ledgerEditDevice = row.item
                                } else {
                                    quickEditDevice = row.item
                                }
                            }
                        )
                    }
                }
            }
        }
    }

    private var pagerBar: some View {
        MetrologySectionPanel(
            title: "翻页导航",
            subtitle: "当前第 \(viewModel.page) / \(viewModel.totalPages) 页"
        ) {
            HStack(spacing: 12) {
                Button("上一页") {
                    Task { await viewModel.prevPage() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())
                .disabled(viewModel.page <= 1 || viewModel.isLoading)
                .opacity((viewModel.page <= 1 || viewModel.isLoading) ? 0.45 : 1)

                Text("第 \(viewModel.page) / \(viewModel.totalPages) 页")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .frame(maxWidth: .infinity)

                Button("下一页") {
                    Task { await viewModel.nextPage() }
                }
                .buttonStyle(MetrologyPrimaryButtonStyle())
                .disabled(viewModel.page >= viewModel.totalPages || viewModel.isLoading)
                .opacity((viewModel.page >= viewModel.totalPages || viewModel.isLoading) ? 0.45 : 1)
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>, metrics: DeviceLayoutMetrics) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 13))
            .foregroundStyle(MetrologyPalette.textPrimary)
            .padding(.horizontal, 10)
            .frame(height: 38)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: metrics.fieldRadius, style: .continuous)
                    .fill(Color.white)
            )
            .overlay(
                RoundedRectangle(cornerRadius: metrics.fieldRadius, style: .continuous)
                    .stroke(Color(hex: 0xD6E2F2), lineWidth: 1)
            )
    }

    private func filterSelect(
        title: String,
        value: Binding<String>,
        allLabel: String,
        options: [String]
    ) -> some View {
        Menu {
            Button(allLabel) {
                applyFilterValue(value, newValue: "")
            }
            ForEach(options, id: \.self) { option in
                Button(option) {
                    applyFilterValue(value, newValue: option)
                }
            }
        } label: {
            MetrologySelectField(
                title: title,
                value: value.wrappedValue.isEmpty ? allLabel : value.wrappedValue,
                compact: true
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, minHeight: 38)
    }

    private var departmentOptions: [String] {
        let currentValues = viewModel.items.compactMap {
            $0.dept?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let merged = viewModel.departmentFilterOptions + currentValues + [viewModel.deptFilter]
        return normalizedOptions(merged)
    }

    private var validityOptions: [String] {
        normalizedOptions([
            "有效",
            "即将过期",
            "失效",
            viewModel.validityFilter
        ])
    }

    private var useStatusOptions: [String] {
        normalizedOptions(viewModel.useStatusFilterOptions + [viewModel.useStatusFilter])
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

    private func applySummaryFilter(_ value: String?) {
        if viewModel.mode == .ledger {
            viewModel.useStatusFilter = value ?? ""
        } else {
            viewModel.validityFilter = value ?? ""
        }
        Task { await viewModel.load(page: 1) }
    }

    private func scheduleSearchReload() {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            await viewModel.load(page: 1)
        }
    }

    private func applyFilterValue(_ value: Binding<String>, newValue: String) {
        let resolved = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.wrappedValue != resolved else { return }
        value.wrappedValue = resolved
        Task { await viewModel.load(page: 1) }
    }

    private var deviceRows: [DeviceListRow] {
        var duplicated: [String: Int] = [:]
        return viewModel.items.map { item in
            let base = baseDeviceRowID(item)
            let count = duplicated[base, default: 0]
            duplicated[base] = count + 1
            let id = count == 0 ? base : "\(base)#\(count)"
            return DeviceListRow(id: id, item: item)
        }
    }

    private func baseDeviceRowID(_ item: DeviceDto) -> String {
        if let id = item.id { return "id:\(id)" }
        return "tmp:\(item.metricNo ?? "")|\(item.assetNo ?? "")|\(item.name ?? "")|\(item.dept ?? "")"
    }

    private func formatCount(_ value: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private var heroEyebrow: String {
        switch viewModel.mode {
        case .ledger:
            return "Ledger"
        case .calibration:
            return "Calibration"
        case .todo:
            return "Todo"
        }
    }

    private var heroTitle: String {
        switch viewModel.mode {
        case .ledger:
            return "设备台账"
        case .calibration:
            return "校准管理"
        case .todo:
            return "我的待办"
        }
    }

    private var heroSubtitle: String {
        switch viewModel.mode {
        case .ledger:
            return "统一查看设备资产、使用状态与校准节点，适合做日常盘点与快速修订。"
        case .calibration:
            return "聚焦正常设备的校准任务，优先处理有效性与下次校准时间。"
        case .todo:
            return "把即将过期与失效设备集中收口，适合做日常待办清理。"
        }
    }

    private var heroAccent: MetrologyPillTone {
        switch viewModel.mode {
        case .ledger:
            return .neutral
        case .calibration:
            return .warning
        case .todo:
            return .expired
        }
    }

    private var heroCountLabel: String {
        switch viewModel.mode {
        case .ledger:
            return "设备总数"
        case .calibration:
            return "在管设备"
        case .todo:
            return "待处理项"
        }
    }

    private var listPanelTitle: String {
        switch viewModel.mode {
        case .ledger:
            return "设备清单"
        case .calibration:
            return "校准设备"
        case .todo:
            return "待办设备"
        }
    }

    private var listPanelSubtitle: String {
        switch viewModel.mode {
        case .ledger:
            return "点击卡片查看设备全量属性，右下角可直接快改。"
        case .calibration:
            return "点击设备查看校准记录与详情，快改仅修改本次校准信息。"
        case .todo:
            return "优先处理高风险设备，保持待办和校准记录同步。"
        }
    }
}

private struct DeviceListRow: Identifiable {
    let id: String
    let item: DeviceDto
}

private struct DeviceRowCard: View {
    let item: DeviceDto
    let mode: DeviceListMode
    let onTap: () -> Void
    let onQuickAction: () -> Void

    private var chipText: String {
        if mode == .ledger {
            return normalizeStatus(item.useStatus)
        }
        return normalizeStatus(item.validity)
    }

    private var chipStyle: ChipStyle {
        let raw = chipText
        if raw.contains("有效") || raw.contains("正常") {
            return .valid
        }
        if raw.contains("过期") || raw.contains("故障") || raw.contains("预警") {
            return .warning
        }
        if raw.contains("失效") || raw.contains("报废") {
            return .expired
        }
        return .neutral
    }

    private var isExpiredDevice: Bool {
        let validity = normalizeStatus(item.validity)
        return validity.contains("失效") || validity.contains("过期")
    }

    private var nextDateColor: Color {
        isExpiredDevice ? MetrologyPalette.statusExpired : MetrologyPalette.textSecondary
    }

    private var valueFont: Font {
        .system(size: 12, weight: .bold)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.cardEyebrow)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(chipStyle.textColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(chipStyle.background)
                        )

                    Text(item.displayName)
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text(chipText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(chipStyle.textColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous).fill(chipStyle.selectedBackground)
                    )
                    .overlay(
                        Capsule(style: .continuous).stroke(chipStyle.selectedStroke.opacity(0.78), lineWidth: 1)
                    )
            }

            Text("编号: \(item.metricNo ?? "-")")
                .font(valueFont)
                .foregroundStyle(MetrologyPalette.textSecondary)
                .padding(.top, 8)
                .lineLimit(1)

            Text("部门: \(item.dept ?? "-")    责任人: \(item.responsiblePerson ?? "-")")
                .font(valueFont)
                .foregroundStyle(MetrologyPalette.textSecondary)
                .padding(.top, 3)
                .lineLimit(1)

            Text("设备位置: \(item.location ?? "-")")
                .font(valueFont)
                .foregroundStyle(MetrologyPalette.textSecondary)
                .padding(.top, 3)
                .lineLimit(1)

            Text("上次校准: \(item.calDate ?? "-")")
                .font(valueFont)
                .foregroundStyle(MetrologyPalette.textSecondary)
                .padding(.top, 3)
                .lineLimit(1)

            HStack(alignment: .bottom, spacing: 8) {
                Text("下次校准: \(item.nextDate ?? "-")")
                    .font(valueFont)
                    .foregroundStyle(nextDateColor)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("快改") {
                    onQuickAction()
                }
                .font(.system(size: 11, weight: .black))
                .foregroundStyle(mode == .ledger ? Color(hex: 0x047857) : MetrologyPalette.navActive)
                .frame(minWidth: 62, minHeight: 32)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(mode == .ledger ? Color(hex: 0x059669, alpha: 0.14) : Color(hex: 0x2563EB, alpha: 0.14))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(mode == .ledger ? Color(hex: 0x059669, alpha: 0.42) : Color(hex: 0x2563EB, alpha: 0.42), lineWidth: 1)
                )
                .shadow(color: (mode == .ledger ? Color(hex: 0x059669) : Color(hex: 0x2563EB)).opacity(0.10), radius: 6, x: 0, y: 3)
            }
            .padding(.top, 3)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(hex: 0xF6FAFF)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: 0xD5E2F2), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x7A95B8, alpha: 0.12), radius: 8, x: 0, y: 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private func normalizeStatus(_ value: String?) -> String {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "其他" : text
    }
}

private struct QuickCalibrationEditView: View {
    let device: DeviceDto
    let mode: DeviceListMode
    let onSave: (DeviceCalibrationPayload) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var validationMessage: String?
    @State private var calDate: String
    @State private var cycle: Int
    @State private var calibrationResult: String
    @State private var remark: String
    @FocusState private var focusedField: QuickField?

    init(device: DeviceDto, mode: DeviceListMode, onSave: @escaping (DeviceCalibrationPayload) -> Void) {
        self.device = device
        self.mode = mode
        self.onSave = onSave
        _calDate = State(initialValue: device.calDate?.isEmpty == false ? (device.calDate ?? "") : Self.todayDateString())
        _cycle = State(initialValue: device.cycle ?? 12)
        _calibrationResult = State(initialValue: Self.resolveCalibrationResult(device.calibrationResult))
        _remark = State(initialValue: device.remark ?? "")
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let horizontalPadding = min(max(proxy.size.width * 0.045, 12), 22)
                let editorMinHeight = min(max(proxy.size.height * 0.20, 96), 170)

                MetrologyFormSheetScaffold(
                    eyebrow: mode == .todo ? "Todo" : "Calibration",
                    title: mode == .todo ? "待办快改" : "校准快改",
                    subtitle: "只修改本次校准时间、周期、结果和备注，减少无关字段干扰。",
                    accent: mode == .todo ? .expired : .warning,
                    bannerMessage: mode == .todo ? "适合快速处理待办设备，保存后会同步影响校准状态。" : "适合做当次校准更新，优先保证日期与结果准确。",
                    bannerTone: mode == .todo ? .expired : .warning
                ) {
                    if let validationMessage {
                        MetrologyInlineValidationMessage(message: validationMessage)
                    }

                    quickHeaderCard
                    quickFormCard(editorMinHeight: editorMinHeight)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    quickActionBar(
                        horizontalPadding: horizontalPadding,
                        bottomInset: proxy.safeAreaInsets.bottom
                    )
                }
            }
            .navigationTitle(mode == .todo ? "待办快改" : "校准快改")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .font(.system(size: 13, weight: .semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(22)
    }

    private var quickHeaderCard: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(device.displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .lineLimit(2)
                Text("编号: \(device.metricNo ?? "-")")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textSecondary)
            }
            Spacer(minLength: 8)
            Text(mode == .todo ? "待办" : "校准")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(mode == .todo ? Color(hex: 0x0EA5E9) : MetrologyPalette.navActive)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(mode == .todo ? Color(hex: 0xE0F2FE) : Color(hex: 0xE9F1FF))
                )
        }
        .padding(12)
        .metrologyCard()
    }

    private func quickFormCard(editorMinHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            quickMenuField(
                title: "检定周期",
                value: cycleLabel(cycle),
                options: cycleOptions.map { $0.title }
            ) { selected in
                if let matched = cycleOptions.first(where: { $0.title == selected }) {
                    cycle = matched.months
                }
            }

            quickMenuField(
                title: "校准结果",
                value: calibrationResult,
                options: calibrationResultOptions
            ) { selected in
                calibrationResult = selected
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("校准日期")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                HStack(spacing: 8) {
                    TextField("YYYY-MM-DD", text: $calDate)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .calDate)
                        .metrologyInput()
                    Button("今天") {
                        calDate = Self.todayDateString()
                        focusedField = nil
                    }
                    .buttonStyle(MetrologySecondaryButtonStyle())
                    .frame(width: 70)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("备注")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                TextEditor(text: $remark)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .frame(minHeight: editorMinHeight)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .focused($focusedField, equals: .remark)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(MetrologyPalette.stroke, lineWidth: 1)
                    )
            }
        }
        .padding(12)
        .metrologyCard()
    }

    private func quickActionBar(horizontalPadding: CGFloat, bottomInset: CGFloat) -> some View {
        VStack(spacing: 0) {
            Divider().overlay(Color(hex: 0xD5E2F2))
            MetrologySaveCancelRow(
                cancelTitle: "取消",
                saveTitle: "保存快改",
                onCancel: {
                    focusedField = nil
                    dismiss()
                },
                onSave: {
                    focusedField = nil
                    handleSave()
                }
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 10)
            .padding(.bottom, max(bottomInset, 8))
            .background(MetrologyPalette.background)
        }
    }

    private let cycleOptions: [(title: String, months: Int)] = [
        ("半年", 6),
        ("一年", 12),
        ("两年", 24)
    ]

    private enum QuickField: Hashable {
        case calDate
        case remark
    }

    private let calibrationResultOptions: [String] = ["合格", "不合格"]

    private func cycleLabel(_ value: Int) -> String {
        if let matched = cycleOptions.first(where: { $0.months == value }) {
            return matched.title
        }
        return "\(value)个月"
    }

    private func quickMenuField(
        title: String,
        value: String,
        options: [String],
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) { onSelect(option) }
                }
            } label: {
                MetrologySelectField(title: title, value: value)
            }
            .buttonStyle(.plain)
        }
    }

    private func handleSave() {
        validationMessage = nil

        let resolvedDate = calDate.trimmingCharacters(in: .whitespacesAndNewlines)
        if resolvedDate.isEmpty {
            validationMessage = "校准日期不能为空"
            return
        }

        let payload = DeviceCalibrationPayload(
            calDate: resolvedDate,
            cycle: cycle,
            calibrationResult: calibrationResult,
            remark: remark.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        onSave(payload)
    }

    private static func resolveCalibrationResult(_ value: String?) -> String {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "合格" : text
    }

    private static func todayDateString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

private struct DeviceDetailView: View {
    let device: DeviceDto
    let mode: DeviceListMode
    let onSaveEdit: ((DeviceUpdatePayload) -> Void)?
    let onDelete: ((Int64) async -> Bool)?

    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false
    @State private var deletingConfirmOpen = false
    @State private var deletingInProgress = false
    @State private var deletingErrorMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    heroSection

                    if deletingInProgress {
                        MetrologyStatusBanner(message: "正在删除设备，请稍候。", tone: .warning, compact: true)
                    }

                    detailSection(title: "基本信息", subtitle: "台账主数据与责任信息保持统一展示。") {
                        detailPairRow(leftLabel: "仪器名称", leftValue: device.displayName, rightLabel: "计量编号", rightValue: device.metricNo)
                        detailPairRow(leftLabel: "资产编号", leftValue: device.assetNo, rightLabel: "出厂编号", rightValue: device.serialNo)
                        detailPairRow(leftLabel: "ABC分类", leftValue: device.abcClass, rightLabel: "设备型号", rightValue: device.model)
                        detailPairRow(leftLabel: "制造厂", leftValue: device.manufacturer, rightLabel: "使用部门", rightValue: device.dept)
                        detailPairRow(leftLabel: "设备位置", leftValue: device.location, rightLabel: "使用责任人", rightValue: device.responsiblePerson)
                        detailPairRow(leftLabel: "使用状态", leftValue: device.useStatus, leftStyle: .useStatus)
                    }

                    detailSection(title: "采购信息", subtitle: "采购时间、价格和寿命参数统一收口。") {
                        detailPairRow(leftLabel: "采购时间", leftValue: device.purchaseDate, rightLabel: "采购价格", rightValue: purchasePriceText)
                        detailPairRow(leftLabel: "使用年限", leftValue: serviceLifeText)
                    }

                    detailSection(title: "技术参数", subtitle: "量程、分度值与允许误差集中展示。") {
                        detailPairRow(leftLabel: "分度值", leftValue: device.graduationValue, rightLabel: "测试范围", rightValue: device.testRange)
                        detailPairRow(leftLabel: "允许误差", leftValue: device.allowableError)
                    }

                    detailSection(title: "校准信息", subtitle: "下次校准和有效状态保持重点强调。") {
                        detailPairRow(leftLabel: "检定周期", leftValue: formatCycle(device.cycle), rightLabel: "上次校准", rightValue: device.calDate)
                        detailPairRow(leftLabel: "下次校准", leftValue: device.nextDate, leftStyle: .nextDate, rightLabel: "有效状态", rightValue: device.validity, rightStyle: .validity)
                        detailPairRow(leftLabel: "校准结果", leftValue: device.calibrationResult)
                    }
                }
                .padding(12)
                .padding(.bottom, 128)
            }
            .scrollIndicators(.hidden)

            footerBar

            if deletingConfirmOpen {
                MetrologyConfirmDialog(
                    title: "删除设备",
                    message: "确定删除“\(device.displayName)”吗？此操作不可撤销。",
                    eyebrow: "Delete",
                    tone: .expired,
                    cancelTitle: "取消",
                    confirmTitle: deletingInProgress ? "处理中..." : "确认删除",
                    destructive: true,
                    onCancel: {
                        if !deletingInProgress {
                            deletingConfirmOpen = false
                        }
                    },
                    onConfirm: {
                        handleDeleteConfirm()
                    }
                )
            }

            if let deletingErrorMessage {
                MetrologyNoticeDialog(
                    title: "删除失败",
                    message: deletingErrorMessage,
                    eyebrow: "Warning",
                    tone: .expired
                ) {
                    self.deletingErrorMessage = nil
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            DeviceEditView(device: device) { payload in
                onSaveEdit?(payload)
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.light)
    }

    private var heroSection: some View {
        MetrologyPageHeroCard(
            eyebrow: mode == .ledger ? "Ledger Detail" : "Calibration Detail",
            title: device.displayName,
            subtitle: "完整属性、校准信息和责任归属统一展示，底部动作区保持一致。",
            accent: validityTone
        ) {
            VStack(alignment: .trailing, spacing: 8) {
                Text("当前状态")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                statusBadge(text: normalized(device.validity).isEmpty ? "待确认" : normalized(device.validity), tint: validityColor)
                statusBadge(text: normalized(device.useStatus).isEmpty ? "待确认" : normalized(device.useStatus), tint: useStatusColor)
            }
        }
    }

    private var footerBar: some View {
        VStack(spacing: 0) {
            Divider().overlay(Color(hex: 0xD5E2F2))
            HStack(spacing: 10) {
                footerButton(title: "关闭", icon: "xmark", tone: .muted, prominent: false, disabled: deletingInProgress) {
                    dismiss()
                }

                if onSaveEdit != nil {
                    footerButton(title: "编辑", icon: "pencil", tone: .neutral, prominent: true, disabled: deletingInProgress) {
                        showEditSheet = true
                    }
                }

                if mode == .ledger, onDelete != nil, device.id != nil {
                    footerButton(
                        title: deletingInProgress ? "删除中" : "删除",
                        icon: deletingInProgress ? "hourglass" : "trash",
                        tone: .expired,
                        prominent: false,
                        disabled: deletingInProgress
                    ) {
                        deletingConfirmOpen = true
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(MetrologyPalette.background)
        }
    }

    private func footerButton(
        title: String,
        icon: String,
        tone: MetrologyPillTone,
        prominent: Bool,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .black))
                Text(title)
                    .font(.system(size: 13, weight: .bold))
            }
            .frame(maxWidth: .infinity, minHeight: 22)
            .padding(.vertical, 10)
            .foregroundStyle(prominent ? Color.white : tone.tint)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(prominent ? tone.tint : tone.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(prominent ? tone.tint.opacity(0.88) : tone.stroke, lineWidth: prominent ? 0 : 1)
            )
            .shadow(color: prominent ? tone.tint.opacity(0.22) : Color.clear, radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
    }

    private func handleDeleteConfirm() {
        guard !deletingInProgress else { return }
        guard let id = device.id else {
            deletingConfirmOpen = false
            deletingErrorMessage = "设备ID无效"
            return
        }
        guard let onDelete else {
            deletingConfirmOpen = false
            deletingErrorMessage = "当前不支持删除"
            return
        }

        deletingInProgress = true
        Task {
            let success = await onDelete(id)
            await MainActor.run {
                deletingInProgress = false
                deletingConfirmOpen = false
                if success {
                    dismiss()
                } else {
                    deletingErrorMessage = "删除失败，请稍后重试"
                }
            }
        }
    }

    private func detailSection<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        MetrologySectionPanel(title: title, subtitle: subtitle) {
            VStack(spacing: 10) {
                content()
            }
        }
    }

    private func detailPairRow(
        leftLabel: String,
        leftValue: String?,
        leftStyle: DetailValueStyle = .normal,
        rightLabel: String? = nil,
        rightValue: String? = nil,
        rightStyle: DetailValueStyle = .normal
    ) -> some View {
        HStack(alignment: .top, spacing: 16) {
            detailField(label: leftLabel, value: leftValue, style: leftStyle)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let rightLabel {
                detailField(label: rightLabel, value: rightValue, style: rightStyle)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer(minLength: 0)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func detailField(
        label: String,
        value: String?,
        style: DetailValueStyle
    ) -> some View {
        let text = normalized(value)
        return VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)
            detailValueView(text.isEmpty ? "-" : text, style: style)
        }
    }

    @ViewBuilder
    private func detailValueView(_ text: String, style: DetailValueStyle) -> some View {
        switch style {
        case .normal:
            Text(text)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)
        case .nextDate:
            Text(text)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(nextDateColor)
        case .useStatus:
            statusBadge(text: text, tint: useStatusColor)
        case .validity:
            statusBadge(text: text, tint: validityColor)
        }
    }

    private func statusBadge(text: String, tint: Color) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.13))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.30), lineWidth: 1)
            )
    }

    private var nextDateColor: Color {
        let validity = normalized(device.validity)
        if validity.contains("失效") || validity.contains("过期") {
            return MetrologyPalette.statusExpired
        }
        if validity.contains("即将过期") || validity.contains("预警") {
            return MetrologyPalette.statusWarning
        }
        if validity.contains("有效") {
            return MetrologyPalette.statusValid
        }
        return MetrologyPalette.textPrimary
    }

    private var useStatusColor: Color {
        let status = normalized(device.useStatus)
        if status.contains("报废") {
            return MetrologyPalette.statusExpired
        }
        if status.contains("故障") {
            return MetrologyPalette.statusWarning
        }
        if status.contains("正常") {
            return MetrologyPalette.statusValid
        }
        return MetrologyPalette.navActive
    }

    private var validityColor: Color {
        let validity = normalized(device.validity)
        if validity.contains("失效") || validity.contains("过期") {
            return MetrologyPalette.statusExpired
        }
        if validity.contains("即将过期") || validity.contains("预警") {
            return MetrologyPalette.statusWarning
        }
        if validity.contains("有效") {
            return MetrologyPalette.statusValid
        }
        return MetrologyPalette.navActive
    }

    private var validityTone: MetrologyPillTone {
        let validity = normalized(device.validity)
        if validity.contains("失效") || validity.contains("过期") {
            return .expired
        }
        if validity.contains("即将过期") || validity.contains("预警") {
            return .warning
        }
        if validity.contains("有效") {
            return .valid
        }
        return .neutral
    }

    private var purchasePriceText: String {
        guard let value = device.purchasePrice else { return "-" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let number = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "¥\(number)"
    }

    private var serviceLifeText: String {
        guard let value = device.serviceLife else { return "-" }
        return "\(value) 年"
    }

    private func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func formatCycle(_ cycle: Int?) -> String {
        guard let cycle else { return "-" }
        if cycle == 6 { return "半年" }
        if cycle == 12 { return "一年" }
        return "\(cycle)个月"
    }
}

private enum DetailValueStyle {
    case normal
    case nextDate
    case useStatus
    case validity
}

private enum ChipStyle {
    case neutral
    case valid
    case warning
    case expired

    var background: Color {
        switch self {
        case .neutral: return Color(hex: 0xF5F9FF)
        case .valid: return Color(hex: 0xECFDF5)
        case .warning: return Color(hex: 0xFFFBEB)
        case .expired: return Color(hex: 0xFEF2F2)
        }
    }

    var stroke: Color {
        switch self {
        case .neutral: return Color(hex: 0xD8E4F6)
        case .valid: return Color(hex: 0xA7F3D0)
        case .warning: return Color(hex: 0xFCD34D)
        case .expired: return Color(hex: 0xFCA5A5)
        }
    }

    var selectedBackground: Color {
        switch self {
        case .neutral: return Color(hex: 0xE8F1FF)
        case .valid: return Color(hex: 0xDDF7EA)
        case .warning: return Color(hex: 0xFFF3D6)
        case .expired: return Color(hex: 0xFFE3E3)
        }
    }

    var selectedStroke: Color {
        switch self {
        case .neutral: return Color(hex: 0x4F7ED0)
        case .valid: return Color(hex: 0x059669)
        case .warning: return Color(hex: 0xD97706)
        case .expired: return Color(hex: 0xDC2626)
        }
    }

    var textColor: Color {
        switch self {
        case .neutral: return MetrologyPalette.textSecondary
        case .valid: return MetrologyPalette.statusValid
        case .warning: return MetrologyPalette.statusWarning
        case .expired: return MetrologyPalette.statusExpired
        }
    }

    var tone: MetrologyPillTone {
        switch self {
        case .neutral: return .neutral
        case .valid: return .valid
        case .warning: return .warning
        case .expired: return .expired
        }
    }
}

private extension DeviceListMode {
    var cardEyebrow: String {
        switch self {
        case .ledger:
            return "LEDGER"
        case .calibration:
            return "CALIBRATION"
        case .todo:
            return "TODO"
        }
    }
}

private extension Color {
    init(hex: Int, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
