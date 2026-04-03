import SwiftUI

struct DepartmentView: View {
    @StateObject private var viewModel = DepartmentViewModel()
    @State private var editor: DepartmentEditorState?
    @State private var deletingItem: DepartmentDto?

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    searchCard
                    hintLine
                    contentList
                }
                .padding(12)
                .padding(.bottom, 18)
            }

            if let deletingItem {
                MetrologyConfirmDialog(
                    title: "\u{5220}\u{9664}\u{90e8}\u{95e8}",
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
                            await viewModel.deleteDepartment(id: id)
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
        .navigationTitle("部门管理")
        .task {
            await viewModel.initialLoad()
        }
        .onChange(of: viewModel.searchText) { _ in
            viewModel.scheduleSearch()
        }
        .sheet(item: $editor) { state in
            DepartmentEditorSheet(
                title: state.title,
                draft: state.draft,
                onCancel: { editor = nil },
                onSave: { draft in
                    Task {
                        let success = await viewModel.saveDepartment(draft: draft, editingId: state.editingId)
                        if success {
                            editor = nil
                        }
                    }
                }
            )
        }
    }

    private var searchCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("搜索部门名称或编码", text: $viewModel.searchText)
                    .metrologyInput()

                Button("查询") {
                    Task { await viewModel.load(search: viewModel.searchText) }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())
            }

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                Button("刷新") {
                    Task { await viewModel.load(search: viewModel.searchText) }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())

                Button("新增部门") {
                    editor = DepartmentEditorState(
                        title: "新增部门",
                        editingId: nil,
                        draft: DepartmentDraft()
                    )
                }
                .buttonStyle(MetrologyPrimaryButtonStyle())
            }
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

    private var contentList: some View {
        VStack(spacing: 8) {
            if departmentRows.isEmpty, !viewModel.isLoading {
                Text("暂无部门数据")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
                    .metrologyCard()
            } else {
                ForEach(departmentRows) { row in
                    DepartmentRow(
                        item: row.item,
                        parentName: viewModel.parentName(of: row.item),
                        onEdit: {
                            editor = DepartmentEditorState(
                                title: "编辑部门",
                                editingId: row.item.id,
                                draft: DepartmentDraft(item: row.item)
                            )
                        },
                        onDelete: {
                            deletingItem = row.item
                        }
                    )
                }
            }
        }
    }

    private var departmentRows: [DepartmentRowItem] {
        var duplicated: [String: Int] = [:]
        return viewModel.items.map { item in
            let base = item.id.map { "id:\($0)" } ?? "tmp:\(item.name ?? "")|\(item.code ?? "")"
            let count = duplicated[base, default: 0]
            duplicated[base] = count + 1
            let id = count == 0 ? base : "\(base)#\(count)"
            return DepartmentRowItem(id: id, item: item)
        }
    }

    private func deletingName(_ item: DepartmentDto) -> String {
        let value = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "\u{8be5}\u{90e8}\u{95e8}" : value
    }
}

private struct DepartmentRowItem: Identifiable {
    let id: String
    let item: DepartmentDto
}

private struct DepartmentRow: View {
    let item: DepartmentDto
    let parentName: String
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(item.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.name ?? "" : "-")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("编辑", action: onEdit)
                    .buttonStyle(MetrologySecondaryButtonStyle())
                    .controlSize(.small)

                Button("删除", action: onDelete)
                    .buttonStyle(MetrologyDangerButtonStyle())
                    .controlSize(.small)
            }

            Text("编码: \(item.code?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.code ?? "" : "-")   排序: \(item.sortOrder ?? 0)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)

            Text("上级: \(parentName)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)
        }
        .padding(10)
        .metrologyCard()
    }
}

private struct DepartmentEditorState: Identifiable {
    let id = UUID()
    let title: String
    let editingId: Int64?
    let draft: DepartmentDraft
}

struct DepartmentDraft {
    var name: String = ""
    var code: String = ""
    var sortOrder: String = "0"
    var parentId: String = ""

    init() {}

    init(item: DepartmentDto) {
        name = item.name ?? ""
        code = item.code ?? ""
        sortOrder = String(item.sortOrder ?? 0)
        parentId = item.parentId.map(String.init) ?? ""
    }
}

private struct DepartmentEditorSheet: View {
    let title: String
    let draft: DepartmentDraft
    let onCancel: () -> Void
    let onSave: (DepartmentDraft) -> Void

    @State private var editing: DepartmentDraft
    @State private var validationMessage: String?

    init(
        title: String,
        draft: DepartmentDraft,
        onCancel: @escaping () -> Void,
        onSave: @escaping (DepartmentDraft) -> Void
    ) {
        self.title = title
        self.draft = draft
        self.onCancel = onCancel
        self.onSave = onSave
        _editing = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                MetrologyPalette.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 10) {
                        VStack(spacing: 8) {
                            TextField("部门名称", text: $editing.name)
                                .metrologyInput()
                            TextField("部门编码（可选）", text: $editing.code)
                                .metrologyInput()
                            TextField("排序值（数字）", text: $editing.sortOrder)
                                .metrologyInput()
                                .keyboardType(.numberPad)
                            TextField("上级部门ID（可空）", text: $editing.parentId)
                                .metrologyInput()
                                .keyboardType(.numberPad)
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

                        HStack(spacing: 10) {
                            Button("取消", action: onCancel)
                                .buttonStyle(MetrologySecondaryButtonStyle())

                            Button("保存") {
                                let trimmed = editing.name.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else {
                                    validationMessage = "部门名称不能为空"
                                    return
                                }
                                validationMessage = nil
                                editing.name = trimmed
                                editing.code = editing.code.trimmingCharacters(in: .whitespacesAndNewlines)
                                editing.parentId = editing.parentId.trimmingCharacters(in: .whitespacesAndNewlines)
                                onSave(editing)
                            }
                            .buttonStyle(MetrologyPrimaryButtonStyle())
                        }
                    }
                    .padding(12)
                    .padding(.bottom, 18)
                }
            }
            .navigationTitle(title)
        }
    }
}

@MainActor
final class DepartmentViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published private(set) var items: [DepartmentDto] = []
    @Published private(set) var isLoading: Bool = false
    @Published var hint: String = ""
    @Published var errorMessage: String?

    private var loaded = false
    private var searchTask: Task<Void, Never>?
    private var namesById: [Int64: String] = [:]

    func initialLoad() async {
        guard !loaded else { return }
        loaded = true
        await load(search: "")
    }

    func scheduleSearch() {
        searchTask?.cancel()
        let keyword = searchText
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.load(search: keyword)
        }
    }

    func load(search: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let list = try await APIClient.shared.departments(search: search.trimmingCharacters(in: .whitespacesAndNewlines))
            items = list
            rebuildNamesMap()
            hint = list.isEmpty ? "暂无部门数据" : "共 \(list.count) 个部门"
        } catch {
            items = []
            namesById = [:]
            hint = ""
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func saveDepartment(draft: DepartmentDraft, editingId: Int64?) async -> Bool {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = draft.code.trimmingCharacters(in: .whitespacesAndNewlines)
        let sortOrder = Int(draft.sortOrder.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let parentId = Int64(draft.parentId.trimmingCharacters(in: .whitespacesAndNewlines))

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if let editingId {
                _ = try await APIClient.shared.updateDepartment(
                    id: editingId,
                    name: name,
                    code: code,
                    sortOrder: sortOrder,
                    parentId: parentId
                )
            } else {
                _ = try await APIClient.shared.createDepartment(
                    name: name,
                    code: code,
                    sortOrder: sortOrder,
                    parentId: parentId
                )
            }
            let list = try await APIClient.shared.departments(search: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
            items = list
            rebuildNamesMap()
            hint = list.isEmpty ? "暂无部门数据" : "共 \(list.count) 个部门"
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    func deleteDepartment(id: Int64) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await APIClient.shared.deleteDepartment(id: id)
            let list = try await APIClient.shared.departments(search: searchText.trimmingCharacters(in: .whitespacesAndNewlines))
            items = list
            rebuildNamesMap()
            hint = list.isEmpty ? "暂无部门数据" : "共 \(list.count) 个部门"
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func parentName(of item: DepartmentDto) -> String {
        guard let parentId = item.parentId else { return "-" }
        return namesById[parentId] ?? "-"
    }

    private func rebuildNamesMap() {
        var map: [Int64: String] = [:]
        for dto in items {
            guard let id = dto.id else { continue }
            let name = dto.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            map[id] = name.isEmpty ? "-" : name
        }
        namesById = map
    }
}
