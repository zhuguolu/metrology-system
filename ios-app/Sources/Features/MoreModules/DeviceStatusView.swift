import SwiftUI

struct DeviceStatusView: View {
    @StateObject private var viewModel = DeviceStatusViewModel()
    @State private var editor: DeviceStatusEditorState?
    @State private var deletingItem: DeviceStatusDto?

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    inputCard
                    hintLine
                    statusList
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)

            if let deletingItem {
                MetrologyConfirmDialog(
                    title: "\u{5220}\u{9664}\u{72b6}\u{6001}",
                    message: "确定删除“\(deletingName(deletingItem))”？",
                    cancelTitle: "\u{53d6}\u{6d88}",
                    confirmTitle: "\u{5220}\u{9664}",
                    destructive: true,
                    onCancel: {
                        self.deletingItem = nil
                    },
                    onConfirm: {
                        guard let id = deletingItem.id else {
                            self.deletingItem = nil
                            return
                        }
                        Task {
                            await viewModel.deleteStatus(id: id)
                            self.deletingItem = nil
                        }
                    }
                )
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
        .navigationTitle("使用状态")
        .task {
            await viewModel.initialLoad()
        }
        .sheet(item: $editor) { state in
            DeviceStatusEditorSheet(
                title: state.title,
                initialName: state.initialName,
                onCancel: {
                    editor = nil
                },
                onSave: { name in
                    Task {
                        let success = await viewModel.updateStatus(id: state.statusId, name: name)
                        if success {
                            editor = nil
                        }
                    }
                }
            )
        }
    }

    private var inputCard: some View {
        HStack(spacing: 8) {
            TextField("输入状态名称", text: $viewModel.newStatusName)
                .metrologyInput()

            Button("新增") {
                Task { await viewModel.createStatus() }
            }
            .buttonStyle(MetrologyPrimaryButtonStyle())
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0.45 : 1)
        }
        .padding(10)
        .metrologyCard()
    }

    private var hintLine: some View {
        HStack(spacing: 8) {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Text(viewModel.hint)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private var statusList: some View {
        VStack(spacing: 8) {
            if statusRows.isEmpty, !viewModel.isLoading {
                Text("暂无状态数据")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .metrologyCard()
            } else {
                ForEach(statusRows) { row in
                    DeviceStatusRow(
                        item: row.item,
                        onEdit: {
                            guard let id = row.item.id else {
                                viewModel.errorMessage = "状态ID无效"
                                return
                            }
                            editor = DeviceStatusEditorState(
                                statusId: id,
                                title: "编辑状态",
                                initialName: row.item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                            )
                        },
                        onDelete: { deletingItem = row.item }
                    )
                }
            }
        }
    }

    private var statusRows: [DeviceStatusRowItem] {
        var duplicated: [String: Int] = [:]
        return viewModel.statuses.map { item in
            let base = item.id.map { "id:\($0)" } ?? "tmp:\(item.name ?? "")"
            let count = duplicated[base, default: 0]
            duplicated[base] = count + 1
            let id = count == 0 ? base : "\(base)#\(count)"
            return DeviceStatusRowItem(id: id, item: item)
        }
    }

    private func deletingName(_ item: DeviceStatusDto) -> String {
        let value = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "\u{8be5}\u{72b6}\u{6001}" : value
    }
}

private struct DeviceStatusRowItem: Identifiable {
    let id: String
    let item: DeviceStatusDto
}

private struct DeviceStatusEditorState: Identifiable {
    let statusId: Int64
    let title: String
    let initialName: String

    var id: Int64 { statusId }
}

private struct DeviceStatusEditorSheet: View {
    let title: String
    let initialName: String
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var name: String
    @State private var validationMessage: String?

    init(
        title: String,
        initialName: String,
        onCancel: @escaping () -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.title = title
        self.initialName = initialName
        self.onCancel = onCancel
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MetrologyPalette.background.ignoresSafeArea()

                VStack(spacing: 10) {
                    VStack(spacing: 8) {
                        TextField("状态名称", text: $name)
                            .metrologyInput()
                    }
                    .padding(10)
                    .metrologyCard()

                    if let validationMessage, !validationMessage.isEmpty {
                        Text(validationMessage)
                            .font(.footnote)
                            .foregroundStyle(MetrologyPalette.statusExpired)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 2)
                    }

                    MetrologySaveCancelRow(
                        onCancel: onCancel,
                        onSave: {
                            let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else {
                                validationMessage = "状态名称不能为空"
                                return
                            }
                            validationMessage = nil
                            onSave(text)
                        }
                    )
                }
                .padding(12)
                .padding(.bottom, 18)
            }
            .navigationTitle(title)
        }
    }
}

private struct DeviceStatusRow: View {
    let item: DeviceStatusDto
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var displayName: String {
        let value = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "-" : value
    }

    private var style: StatusChipStyle {
        StatusChipStyle.resolve(displayName)
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text(displayName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(style.text)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(style.background)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(style.stroke, lineWidth: 1)
                    )

                Text("ID: \(item.id.map(String.init) ?? "-")")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textSecondary)
            }

            Spacer(minLength: 0)

            Button("编辑", action: onEdit)
                .buttonStyle(MetrologySecondaryButtonStyle())
                .controlSize(.small)

            Button("删除", action: onDelete)
                .buttonStyle(MetrologyDangerButtonStyle())
                .controlSize(.small)
        }
        .padding(10)
        .metrologyCard()
    }
}

private enum StatusChipStyle {
    case normal
    case warning
    case danger
    case neutral

    static func resolve(_ value: String) -> StatusChipStyle {
        if value.contains("正常") || value.contains("在用") || value.contains("使用中") {
            return .normal
        }
        if value.contains("故障") || value.contains("维修") || value.contains("校准") || value.contains("停用") || value.contains("待修") {
            return .warning
        }
        if value.contains("报废") || value.contains("停机") || value.contains("失效") || value.contains("丢失") {
            return .danger
        }
        return .neutral
    }

    var background: Color {
        switch self {
        case .normal: return Color(hex: 0xECFDF5)
        case .warning: return Color(hex: 0xFFFBEB)
        case .danger: return Color(hex: 0xFEF2F2)
        case .neutral: return Color(hex: 0xF5F9FF)
        }
    }

    var stroke: Color {
        switch self {
        case .normal: return Color(hex: 0xA7F3D0)
        case .warning: return Color(hex: 0xFCD34D)
        case .danger: return Color(hex: 0xFCA5A5)
        case .neutral: return Color(hex: 0xD8E4F6)
        }
    }

    var text: Color {
        switch self {
        case .normal: return MetrologyPalette.statusValid
        case .warning: return MetrologyPalette.statusWarning
        case .danger: return MetrologyPalette.statusExpired
        case .neutral: return MetrologyPalette.textSecondary
        }
    }
}

@MainActor
final class DeviceStatusViewModel: ObservableObject {
    @Published var newStatusName: String = ""
    @Published private(set) var statuses: [DeviceStatusDto] = []
    @Published private(set) var isLoading: Bool = false
    @Published var hint: String = ""
    @Published var errorMessage: String?

    private var loaded = false

    func initialLoad() async {
        guard !loaded else { return }
        loaded = true
        await load()
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let data = try await APIClient.shared.deviceStatuses()
            statuses = data
            if data.isEmpty {
                hint = "暂无状态数据"
            } else {
                hint = "共 \(data.count) 个状态"
            }
        } catch {
            statuses = []
            hint = ""
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func createStatus() async {
        let name = newStatusName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            errorMessage = "请输入状态名称"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await APIClient.shared.createDeviceStatus(name: name)
            newStatusName = ""
            let data = try await APIClient.shared.deviceStatuses()
            statuses = data
            hint = data.isEmpty ? "暂无状态数据" : "共 \(data.count) 个状态"
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func updateStatus(id: Int64, name: String) async -> Bool {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            errorMessage = "状态名称不能为空"
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await APIClient.shared.updateDeviceStatus(id: id, name: value)
            let data = try await APIClient.shared.deviceStatuses()
            statuses = data
            hint = data.isEmpty ? "暂无状态数据" : "共 \(data.count) 个状态"
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    func deleteStatus(id: Int64) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await APIClient.shared.deleteDeviceStatus(id: id)
            let data = try await APIClient.shared.deviceStatuses()
            statuses = data
            hint = data.isEmpty ? "暂无状态数据" : "共 \(data.count) 个状态"
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
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
