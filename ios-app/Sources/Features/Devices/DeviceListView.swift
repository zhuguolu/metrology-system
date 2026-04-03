import SwiftUI

struct DeviceListView: View {
    @StateObject private var viewModel: DeviceListViewModel
    @State private var selectedDevice: DeviceDto?

    init(mode: DeviceListMode) {
        _viewModel = StateObject(wrappedValue: DeviceListViewModel(mode: mode))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MetrologyPalette.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerBar

                    ScrollView {
                        LazyVStack(spacing: 14) {
                            filterPanel
                            summaryPanel
                            listPanel
                            pagerBar
                        }
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                        .padding(.bottom, 18)
                    }
                    .scrollIndicators(.hidden)
                }

                if viewModel.isLoading {
                    loadingOverlay
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
                        if !value {
                            viewModel.errorMessage = nil
                        }
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
                        if !value {
                            selectedDevice = nil
                        }
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
                                if success {
                                    selectedDevice = nil
                                }
                            }
                        }
                    )
                }
            }
        }
    }

    private var headerBar: some View {
        HStack(alignment: .center) {
            Text(viewModel.mode.title)
                .font(.system(size: 58, weight: .black))
                .foregroundStyle(MetrologyPalette.textPrimary)
                .minimumScaleFactor(0.72)
                .lineLimit(1)

            Spacer(minLength: 8)

            Button("刷新") {
                Task { await viewModel.reloadCurrentPage() }
            }
            .buttonStyle(MetrologyGhostButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var filterPanel: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                TextField("搜索名称/编号/责任人", text: $viewModel.searchText)
                    .metrologyInput()
                TextField("部门", text: $viewModel.deptFilter)
                    .metrologyInput()
            }

            if viewModel.mode == .ledger {
                TextField("使用状态（可选）", text: $viewModel.useStatusFilter)
                    .metrologyInput()
            } else {
                HStack(spacing: 8) {
                    TextField("有效性", text: $viewModel.validityFilter)
                        .metrologyInput()
                    TextField("起始日期", text: $viewModel.nextDateFrom)
                        .metrologyInput()
                    TextField("结束日期", text: $viewModel.nextDateTo)
                        .metrologyInput()
                }
            }

            HStack(spacing: 8) {
                Button("查询") {
                    Task { await viewModel.load(page: 1) }
                }
                .buttonStyle(MetrologyPrimaryButtonStyle())

                Button("重置") {
                    Task { await viewModel.resetFilters() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())

                Spacer(minLength: 4)

                Text(viewModel.hintMessage)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .metrologyCard()
    }

    private var summaryPanel: some View {
        let labels = viewModel.mode.summaryLabels
        return HStack(spacing: 8) {
            ForEach(labels, id: \.self) { label in
                VStack(alignment: .leading, spacing: 6) {
                    Text(label)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                    Text(formatCount(summaryValue(label: label)))
                        .font(.system(size: 25, weight: .bold))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
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
        .padding(12)
        .metrologyCard()
    }

    private var listPanel: some View {
        VStack(spacing: 10) {
            if deviceRows.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 30))
                        .foregroundStyle(MetrologyPalette.textMuted)
                    Text("暂无设备数据")
                        .font(.system(size: 16))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .metrologyCard()
            } else {
                ForEach(deviceRows) { row in
                    DeviceRowCard(
                        item: row.item,
                        mode: viewModel.mode,
                        onTap: { selectedDevice = row.item },
                        onQuickCalibrate: {
                            Task { await viewModel.quickCalibrate(row.item) }
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
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .lineLimit(1)

            Button("下一页") {
                Task { await viewModel.nextPage() }
            }
            .buttonStyle(MetrologyPrimaryButtonStyle())
            .disabled(viewModel.page >= viewModel.totalPages || viewModel.isLoading)
            .opacity((viewModel.page >= viewModel.totalPages || viewModel.isLoading) ? 0.45 : 1)
        }
        .padding(12)
        .metrologyCard()
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.32).ignoresSafeArea()
            ProgressView("加载中...")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(MetrologyPalette.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MetrologyPalette.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(MetrologyPalette.stroke, lineWidth: 1)
                )
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isLoading)
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

    private func summaryValue(label: String) -> Int64 {
        if viewModel.mode == .ledger {
            return viewModel.useStatusSummary[label] ?? 0
        }
        return viewModel.summaryCounts[label] ?? 0
    }

    private func baseDeviceRowID(_ item: DeviceDto) -> String {
        if let id = item.id {
            return "id:\(id)"
        }
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
    let onQuickCalibrate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text(item.displayName)
                    .font(.system(size: 46, weight: .black))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 8)

                if mode != .ledger {
                    Button("校准完成") {
                        onQuickCalibrate()
                    }
                    .buttonStyle(MetrologyPrimaryButtonStyle())
                }
            }

            Text("编号: \(item.metricNo ?? "-")")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .lineLimit(1)

            HStack(spacing: 10) {
                metaChip(title: "部门", value: item.dept ?? "-")
                if mode == .ledger {
                    metaChip(title: "状态", value: item.useStatus ?? "-")
                } else {
                    metaChip(title: "有效性", value: item.validity ?? "-")
                }
                metaChip(title: "下次", value: item.nextDate ?? "-")
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .metrologyCard()
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private func metaChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(MetrologyPalette.textMuted)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(MetrologyPalette.surface.opacity(0.7))
        )
    }
}

private struct DeviceDetailView: View {
    let device: DeviceDto
    let mode: DeviceListMode
    let onRefresh: () -> Void
    let onQuickCalibrate: () -> Void
    let onSaveEdit: ((DeviceUpdatePayload) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showEditSheet: Bool = false

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
                    Button("关闭") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("刷新") {
                        onRefresh()
                    }
                }
                if mode == .ledger {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("编辑") {
                            showEditSheet = true
                        }
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
