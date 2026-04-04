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
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: DeviceListViewModel
    @State private var selectedDevice: DeviceDto?
    @State private var quickEditDevice: DeviceDto?
    @State private var filterExpanded = false
    @State private var moreActionsExpanded = false

    init(mode: DeviceListMode) {
        _viewModel = StateObject(wrappedValue: DeviceListViewModel(mode: mode))
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = DeviceLayoutMetrics(containerWidth: proxy.size.width, containerHeight: proxy.size.height)

            ZStack {
                MetrologyPalette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 12) {
                        filterCard(metrics: metrics)
                        statusLine
                        listPanel(metrics: metrics)
                        pagerBar
                    }
                    .padding(.bottom, 8)
                }
                .scrollIndicators(.hidden)

                if viewModel.isLoading {
                    loadingOverlay
                }

                if let errorMessage = viewModel.errorMessage {
                    MetrologyNoticeDialog(
                        title: "\u{63d0}\u{793a}",
                        message: errorMessage
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
                    onRefresh: {
                        Task { await viewModel.reloadCurrentPage() }
                    },
                    onQuickCalibrate: {
                        selectedDevice = nil
                        DispatchQueue.main.async {
                            quickEditDevice = device
                        }
                    },
                    onSaveEdit: { payload in
                        guard let id = device.id else {
                            viewModel.errorMessage = "设备ID无效"
                            return
                        }
                        Task {
                            let success = await viewModel.updateLedgerDevice(id: id, payload: payload)
                            if success { selectedDevice = nil }
                        }
                    }
                )
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
                            if success {
                                quickEditDevice = nil
                            }
                        }
                    }
                )
            }
        }
    }

    private func filterCard(metrics: DeviceLayoutMetrics) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("搜索名称/编号/责任人", text: $viewModel.searchText)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .padding(.horizontal, 12)
                    .frame(height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color(hex: 0xD6E2F2), lineWidth: 1)
                    )

                Button(filterExpanded ? "收起" : "筛选") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        filterExpanded.toggle()
                    }
                }
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)
                .frame(width: 64, height: 40)
                .buttonStyle(MetrologySecondaryButtonStyle())
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

                        if viewModel.mode == .ledger {
                            Button("重置筛选") {
                                Task { await viewModel.resetFilters() }
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MetrologyPalette.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .buttonStyle(MetrologySecondaryButtonStyle())
                        } else {
                            HStack(spacing: 6) {
                                field("起始日期", text: $viewModel.nextDateFrom, metrics: metrics)
                                Text("~")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(MetrologyPalette.textSecondary)
                                field("结束日期", text: $viewModel.nextDateTo, metrics: metrics)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    if viewModel.mode != .ledger {
                        Divider().overlay(MetrologyPalette.stroke)

                        Button(moreActionsExpanded ? "收起更多" : "更多功能") {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                moreActionsExpanded.toggle()
                            }
                        }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .buttonStyle(MetrologySecondaryButtonStyle())

                        if moreActionsExpanded {
                            Button("重置筛选") {
                                Task { await viewModel.resetFilters() }
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MetrologyPalette.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .buttonStyle(MetrologySecondaryButtonStyle())
                        }
                    }

                    HStack(spacing: 10) {
                        Button("查询") {
                            Task { await viewModel.load(page: 1) }
                        }
                        .buttonStyle(MetrologyPrimaryButtonStyle())

                        Button("重置") {
                            Task { await viewModel.resetFilters() }
                        }
                        .buttonStyle(MetrologySecondaryButtonStyle())

                        Spacer(minLength: 0)

                        Text(viewModel.hintMessage)
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(MetrologyPalette.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            summaryTiles
        }
        .padding(12)
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
        .shadow(color: Color(hex: 0x7A95B8, alpha: 0.12), radius: 5, x: 0, y: 2)
    }

    private var summaryTiles: some View {
        let columns: [GridItem] = viewModel.mode == .ledger
            ? Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)
            : Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

        return LazyVGrid(columns: columns, spacing: 8) {
            if viewModel.mode == .ledger {
                summaryTile(
                    title: "正常",
                    value: viewModel.useStatusSummary["正常"] ?? 0,
                    style: .valid,
                    isSelected: viewModel.useStatusFilter == "正常"
                ) {
                    applySummaryFilter("正常")
                }
                summaryTile(
                    title: "故障",
                    value: viewModel.useStatusSummary["故障"] ?? 0,
                    style: .warning,
                    isSelected: viewModel.useStatusFilter == "故障"
                ) {
                    applySummaryFilter("故障")
                }
                summaryTile(
                    title: "报废",
                    value: viewModel.useStatusSummary["报废"] ?? 0,
                    style: .expired,
                    isSelected: viewModel.useStatusFilter == "报废"
                ) {
                    applySummaryFilter("报废")
                }
                summaryTile(
                    title: "其他",
                    value: viewModel.useStatusSummary["其他"] ?? 0,
                    style: .neutral,
                    isSelected: viewModel.useStatusFilter == "其他"
                ) {
                    applySummaryFilter("其他")
                }
            } else {
                summaryTile(
                    title: "有效",
                    value: viewModel.summaryCounts["有效"] ?? 0,
                    style: .valid,
                    isSelected: viewModel.validityFilter == "有效"
                ) {
                    applySummaryFilter("有效")
                }
                summaryTile(
                    title: "即将过期",
                    value: viewModel.summaryCounts["即将过期"] ?? 0,
                    style: .warning,
                    isSelected: viewModel.validityFilter == "即将过期"
                ) {
                    applySummaryFilter("即将过期")
                }
                summaryTile(
                    title: "失效",
                    value: viewModel.summaryCounts["失效"] ?? 0,
                    style: .expired,
                    isSelected: viewModel.validityFilter == "失效"
                ) {
                    applySummaryFilter("失效")
                }
            }
        }
    }

    private func summaryTile(
        title: String,
        value: Int64,
        style: ChipStyle,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(style.textColor)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(style.textColor)
                    }
                }
                Text(formatCount(value))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(style.textColor)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? style.selectedBackground : style.background)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? style.selectedStroke : style.stroke, lineWidth: isSelected ? 2 : 1)
            )
            .shadow(color: isSelected ? style.selectedStroke.opacity(0.22) : .clear, radius: 4, x: 0, y: 2)
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var statusLine: some View {
        Group {
            if viewModel.isLoading {
                Text("加载中...")
            } else if deviceRows.isEmpty {
                Text("暂无数据")
            } else {
                Text("共 \(formatCount(viewModel.total)) 条")
            }
        }
        .font(.system(size: 12, weight: .regular))
        .foregroundStyle(MetrologyPalette.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private func listPanel(metrics: DeviceLayoutMetrics) -> some View {
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
                                selectedDevice = row.item
                            } else {
                                quickEditDevice = row.item
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

            Text("第 \(viewModel.page) / \(viewModel.totalPages) 页")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(MetrologyPalette.textSecondary)

            Button("下一页") {
                Task { await viewModel.nextPage() }
            }
            .buttonStyle(MetrologyPrimaryButtonStyle())
            .disabled(viewModel.page >= viewModel.totalPages || viewModel.isLoading)
            .opacity((viewModel.page >= viewModel.totalPages || viewModel.isLoading) ? 0.45 : 1)
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
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
                value.wrappedValue = ""
            }
            ForEach(options, id: \.self) { option in
                Button(option) {
                    value.wrappedValue = option
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
        let sessionValues: [String] = appState.session?.departments ?? []
        let currentValues = viewModel.items.compactMap {
            $0.dept?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let merged = sessionValues + currentValues + [viewModel.deptFilter]
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
        if viewModel.mode == .calibration {
            return normalizedOptions(["正常", viewModel.useStatusFilter])
        }
        return normalizedOptions([
            "正常",
            "故障",
            "报废",
            "其他",
            viewModel.useStatusFilter
        ])
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

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.18).ignoresSafeArea()
            ProgressView("加载中...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MetrologyPalette.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 8) {
                Text(item.displayName)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(chipText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(chipStyle.textColor)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous).fill(chipStyle.background)
                    )
                    .overlay(
                        Capsule(style: .continuous).stroke(chipStyle.stroke, lineWidth: 1)
                    )
            }

            Text("编号: \(item.metricNo ?? "-")")
                .font(.system(size: 12))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .padding(.top, 8)
                .lineLimit(1)

            Text("部门: \(item.dept ?? "-")    责任人: \(item.responsiblePerson ?? "-")")
                .font(.system(size: 12))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .padding(.top, 3)
                .lineLimit(1)

            HStack(alignment: .bottom, spacing: 8) {
                Text("下次校准: \(item.nextDate ?? "-")")
                    .font(.system(size: 12))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("快改") {
                    onQuickAction()
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(mode == .ledger ? Color(hex: 0x047857) : MetrologyPalette.navActive)
                .frame(minWidth: 56, minHeight: 28)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(mode == .ledger ? Color(hex: 0x059669, alpha: 0.13) : Color(hex: 0x2563EB, alpha: 0.13))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(mode == .ledger ? Color(hex: 0x059669, alpha: 0.40) : Color(hex: 0x2563EB, alpha: 0.40), lineWidth: 1)
                )
            }
            .padding(.top, 3)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(hex: 0xF6FAFF)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0xD5E2F2), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x7A95B8, alpha: 0.10), radius: 4, x: 0, y: 2)
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
            ZStack {
                MetrologyPalette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        if let validationMessage {
                            Text(validationMessage)
                                .font(.footnote)
                                .foregroundStyle(MetrologyPalette.statusExpired)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 2)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(device.displayName)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(MetrologyPalette.textPrimary)

                            Text("编号: \(device.metricNo ?? "-")")
                                .font(.system(size: 12, weight: .regular))
                                .foregroundStyle(MetrologyPalette.textSecondary)

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
                                TextField("YYYY-MM-DD", text: $calDate)
                                    .metrologyInput()
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("备注")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(MetrologyPalette.textPrimary)
                                TextEditor(text: $remark)
                                    .font(.system(size: 15, weight: .regular))
                                    .foregroundStyle(MetrologyPalette.textPrimary)
                                    .frame(minHeight: 88)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
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
                        .padding(10)
                        .metrologyCard()

                        HStack(spacing: 10) {
                            Button("取消") { dismiss() }
                                .buttonStyle(MetrologySecondaryButtonStyle())
                            Button("保存") { handleSave() }
                                .buttonStyle(MetrologyPrimaryButtonStyle())
                        }
                    }
                    .padding(12)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle(mode == .todo ? "待办快改" : "校准快改")
        }
        .presentationDetents([.medium, .large])
    }

    private let cycleOptions: [(title: String, months: Int)] = [
        ("半年", 6),
        ("一年", 12),
        ("两年", 24)
    ]

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
    let onRefresh: () -> Void
    let onQuickCalibrate: () -> Void
    let onSaveEdit: ((DeviceUpdatePayload) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet = false

    var body: some View {
        NavigationStack {
            List {
                Section("基础信息") {
                    DetailRow(label: "设备名称", value: device.displayName)
                    DetailRow(label: "计量编号", value: device.metricNo ?? "-")
                    DetailRow(label: "资产编号", value: device.assetNo ?? "-")
                    DetailRow(label: "ABC分类", value: device.abcClass ?? "-")
                    DetailRow(label: "使用部门", value: device.dept ?? "-")
                    DetailRow(label: "责任人", value: device.responsiblePerson ?? "-")
                    DetailRow(label: "使用状态", value: device.useStatus ?? "-")
                }

                Section("校准信息") {
                    DetailRow(label: "检定周期", value: formatCycle(device.cycle))
                    DetailRow(label: "上次校准", value: device.calDate ?? "-")
                    DetailRow(label: "下次校准", value: device.nextDate ?? "-")
                    DetailRow(label: "校准结果", value: device.calibrationResult ?? "-")
                    DetailRow(label: "有效性", value: device.validity ?? "-")
                }

                Section("扩展信息") {
                    DetailRow(label: "设备型号", value: device.model ?? "-")
                    DetailRow(label: "制造厂", value: device.manufacturer ?? "-")
                    DetailRow(label: "设备位置", value: device.location ?? "-")
                    DetailRow(label: "备注", value: device.remark ?? "-")
                }
            }
            .scrollContentBackground(.hidden)
            .background(MetrologyPalette.background)
            .navigationTitle("设备详情")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("刷新") { onRefresh() }
                }
                if mode == .ledger {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("编辑") { showEditSheet = true }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if mode != .ledger {
                    Button {
                        dismiss()
                        onQuickCalibrate()
                    } label: {
                        Text("快改")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(MetrologyPrimaryButtonStyle())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(MetrologyPalette.background)
                }
            }
            .sheet(isPresented: $showEditSheet) {
                DeviceEditView(device: device) { payload in
                    onSaveEdit?(payload)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func formatCycle(_ cycle: Int?) -> String {
        guard let cycle else { return "-" }
        if cycle == 6 { return "半年" }
        if cycle == 12 { return "一年" }
        return "\(cycle)个月"
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
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
}

private extension Color {
    init(hex: Int, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
