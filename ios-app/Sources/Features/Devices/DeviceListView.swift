import SwiftUI

struct DeviceListView: View {
    @StateObject private var viewModel: DeviceListViewModel
    @State private var selectedDevice: DeviceDto?

    init(mode: DeviceListMode) {
        _viewModel = StateObject(wrappedValue: DeviceListViewModel(mode: mode))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                filterPanel

                summaryPanel

                List {
                    ForEach(deviceRows) { row in
                        DeviceRowCard(
                            item: row.item,
                            mode: viewModel.mode,
                            onTap: {
                                selectedDevice = row.item
                            },
                            onQuickCalibrate: {
                                Task { await viewModel.quickCalibrate(row.item) }
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)

                pagerBar
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .navigationTitle(viewModel.mode.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("刷新") {
                        Task { await viewModel.reloadCurrentPage() }
                    }
                }
            }
            .task {
                await viewModel.initialLoad()
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("加载中...")
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
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
        if let id = item.id {
            return "id:\(id)"
        }
        return "tmp:\(item.metricNo ?? "")|\(item.assetNo ?? "")|\(item.name ?? "")|\(item.dept ?? "")"
    }

    private var filterPanel: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("搜索名称/编号/责任人", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                TextField("部门", text: $viewModel.deptFilter)
                    .textFieldStyle(.roundedBorder)
            }

            if viewModel.mode == .ledger {
                TextField("使用状态（可选）", text: $viewModel.useStatusFilter)
                    .textFieldStyle(.roundedBorder)
            } else {
                HStack(spacing: 8) {
                    TextField("有效性（有效/即将过期/失效）", text: $viewModel.validityFilter)
                        .textFieldStyle(.roundedBorder)
                    TextField("起始日期", text: $viewModel.nextDateFrom)
                        .textFieldStyle(.roundedBorder)
                    TextField("结束日期", text: $viewModel.nextDateTo)
                        .textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 10) {
                Button("查询") {
                    Task { await viewModel.load(page: 1) }
                }
                .buttonStyle(.borderedProminent)

                Button("重置") {
                    Task { await viewModel.resetFilters() }
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)
                Text(viewModel.hintMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var summaryPanel: some View {
        let labels = viewModel.mode.summaryLabels
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(labels, id: \.self) { label in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(summaryValue(label: label))")
                            .font(.headline)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
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
            .buttonStyle(.bordered)
            .disabled(viewModel.page <= 1 || viewModel.isLoading)

            Text("第 \(viewModel.page) / \(viewModel.totalPages) 页")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("下一页") {
                Task { await viewModel.nextPage() }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.page >= viewModel.totalPages || viewModel.isLoading)
        }
        .padding(.bottom, 8)
    }

    private func summaryValue(label: String) -> Int64 {
        if viewModel.mode == .ledger {
            return viewModel.useStatusSummary[label] ?? 0
        }
        return viewModel.summaryCounts[label] ?? 0
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(item.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if mode != .ledger {
                    Button("校准完成") {
                        onQuickCalibrate()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            Text("编号: \(item.metricNo ?? "-")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Text("部门: \(item.dept ?? "-")")
                Text("有效性: \(item.validity ?? "-")")
                Text("下次: \(item.nextDate ?? "-")")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
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
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 14)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    .background(.ultraThinMaterial)
                }
            }
            .sheet(isPresented: $showEditSheet) {
                DeviceEditView(device: device) { payload in
                    onSaveEdit?(payload)
                }
            }
        }
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
