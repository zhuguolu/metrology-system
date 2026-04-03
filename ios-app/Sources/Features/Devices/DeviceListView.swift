import SwiftUI

private struct DeviceLayoutMetrics {
    let scale: AndroidScale
    let width: CGFloat

    init(containerWidth: CGFloat) {
        scale = AndroidScale(containerWidth: containerWidth)
        width = containerWidth
    }

    var cardRadius: CGFloat { max(scale.px(18), 14) }
    var fieldRadius: CGFloat { max(scale.px(12), 10) }
}

struct DeviceListView: View {
    @StateObject private var viewModel: DeviceListViewModel
    @State private var selectedDevice: DeviceDto?
    @State private var filterExpanded = false
    @State private var moreActionsExpanded = false

    init(mode: DeviceListMode) {
        _viewModel = StateObject(wrappedValue: DeviceListViewModel(mode: mode))
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = DeviceLayoutMetrics(containerWidth: proxy.size.width)

            ZStack {
                MetrologyPalette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        filterCard(metrics: metrics)
                        statusLine
                        listPanel(metrics: metrics)
                        pagerBar(metrics: metrics)
                    }
                    .padding(.bottom, 4)
                }
                .scrollIndicators(.hidden)

                if viewModel.isLoading {
                    loadingOverlay
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.initialLoad()
        }
        .alert(
            "提示",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { value in
                    if !value { viewModel.errorMessage = nil }
                }
            )
        ) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
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
                        Task {
                            await viewModel.quickCalibrate(device)
                            selectedDevice = nil
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
    }

    private func filterCard(metrics: DeviceLayoutMetrics) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("搜索设备名称、编号、责任人", text: $viewModel.searchText)
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

                Button(filterExpanded ? "收起" : "展开") {
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
                        field("使用部门", text: $viewModel.deptFilter, metrics: metrics)
                        field("有效性", text: $viewModel.validityFilter, metrics: metrics)
                    }

                    HStack(spacing: 8) {
                        field("使用状态", text: $viewModel.useStatusFilter, metrics: metrics)
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
                                field("开始日期", text: $viewModel.nextDateFrom, metrics: metrics)
                                Text("~")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(MetrologyPalette.textSecondary)
                                field("结束日期", text: $viewModel.nextDateTo, metrics: metrics)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    if viewModel.mode != .ledger {
                        Divider()
                            .overlay(MetrologyPalette.stroke)

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

                        if viewModel.mode == .ledger {
                            Button("重置") {
                                Task { await viewModel.resetFilters() }
                            }
                            .buttonStyle(MetrologySecondaryButtonStyle())
                        }

                        Spacer(minLength: 0)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            summaryChips
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

    private var summaryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                summaryChip(
                    title: "总数 \(formatCount(viewModel.total))",
                    style: .neutral
                ) {
                    applySummaryFilter(nil)
                }

                if viewModel.mode == .ledger {
                    summaryChip(
                        title: "正常 \(formatCount(viewModel.useStatusSummary["正常"] ?? 0))",
                        style: .valid
                    ) {
                        applySummaryFilter("正常")
                    }
                    summaryChip(
                        title: "故障 \(formatCount(viewModel.useStatusSummary["故障"] ?? 0))",
                        style: .warning
                    ) {
                        applySummaryFilter("故障")
                    }
                    summaryChip(
                        title: "报废 \(formatCount(viewModel.useStatusSummary["报废"] ?? 0))",
                        style: .expired
                    ) {
                        applySummaryFilter("报废")
                    }
                    summaryChip(
                        title: "其他 \(formatCount(viewModel.useStatusSummary["其他"] ?? 0))",
                        style: .neutral
                    ) {
                        applySummaryFilter("其他")
                    }
                } else {
                    summaryChip(
                        title: "有效 \(formatCount(viewModel.summaryCounts["有效"] ?? 0))",
                        style: .valid
                    ) {
                        applySummaryFilter("有效")
                    }
                    summaryChip(
                        title: "即将过期 \(formatCount(viewModel.summaryCounts["即将过期"] ?? 0))",
                        style: .warning
                    ) {
                        applySummaryFilter("即将过期")
                    }
                    summaryChip(
                        title: "失效 \(formatCount(viewModel.summaryCounts["失效"] ?? 0))",
                        style: .expired
                    ) {
                        applySummaryFilter("失效")
                    }
                }
            }
            .padding(.horizontal, 1)
            .padding(.vertical, 2)
        }
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
        .font(.system(size: 10.5, weight: .regular))
        .foregroundStyle(MetrologyPalette.textMuted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .padding(.top, 2)
        .padding(.bottom, 1)
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
                                Task { await viewModel.quickCalibrate(row.item) }
                            }
                        }
                    )
                }
            }
        }
    }

    private func pagerBar(metrics: DeviceLayoutMetrics) -> some View {
        HStack(spacing: 6) {
            pagerArrowButton(symbol: "chevron.left", disabled: viewModel.page <= 1 || viewModel.isLoading) {
                Task { await viewModel.prevPage() }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(pageItems, id: \.self) { page in
                        Button("\(page)") {
                            Task { await viewModel.load(page: page) }
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(page == viewModel.page ? Color.white : MetrologyPalette.textPrimary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    page == viewModel.page
                                        ? AnyShapeStyle(
                                            LinearGradient(
                                                colors: [Color(hex: 0x4DA3FF), Color(hex: 0x2F80ED)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        : AnyShapeStyle(Color(hex: 0xF3F6FC))
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(
                                    page == viewModel.page ? Color(hex: 0x2A74D8) : Color(hex: 0xE3EAF5),
                                    lineWidth: 1
                                )
                        )
                        .disabled(viewModel.isLoading)
                    }
                }
                .padding(.horizontal, 2)
            }

            pagerArrowButton(symbol: "chevron.right", disabled: viewModel.page >= viewModel.totalPages || viewModel.isLoading) {
                Task { await viewModel.nextPage() }
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private func pagerArrowButton(symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(MetrologySecondaryButtonStyle())
        .disabled(disabled)
        .opacity(disabled ? 0.45 : 1)
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

    private func summaryChip(title: String, style: ChipStyle, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(style.textColor)
                .padding(.horizontal, 12)
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
        .buttonStyle(.plain)
    }

    private func applySummaryFilter(_ value: String?) {
        if viewModel.mode == .ledger {
            viewModel.useStatusFilter = value ?? ""
        } else {
            viewModel.validityFilter = value ?? ""
        }
        Task { await viewModel.load(page: 1) }
    }

    private var pageItems: [Int] {
        guard viewModel.totalPages > 1 else { return [1] }
        let start = max(1, viewModel.page - 2)
        let end = min(viewModel.totalPages, viewModel.page + 2)
        return Array(start...end)
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

            Text("计量编号：\(item.metricNo ?? "-")")
                .font(.system(size: 12))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .padding(.top, 8)
                .lineLimit(1)

            Text("使用部门：\(item.dept ?? "-")    责任人：\(item.responsiblePerson ?? "-")")
                .font(.system(size: 12))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .padding(.top, 3)
                .lineLimit(1)

            HStack(alignment: .bottom, spacing: 8) {
                Text("下次校准：\(item.nextDate ?? "-")")
                    .font(.system(size: 12))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(mode == .ledger ? "快改" : "校准完成") {
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
                        onQuickCalibrate()
                    } label: {
                        Text("标记本次已校准")
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
