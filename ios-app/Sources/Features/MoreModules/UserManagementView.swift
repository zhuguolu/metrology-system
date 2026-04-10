import SwiftUI

struct UserManagementView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = UserManagementViewModel()

    @State private var createSheetOpen = false
    @State private var permissionEditor: PermissionEditorState?
    @State private var resetPasswordEditor: ResetPasswordEditorState?
    @State private var deleteTarget: UserDto?

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    topCard
                    hintLine
                    userList
                }
                .padding(.horizontal, MetrologyLayout.pageHorizontalPadding)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)

            if let deleteTarget {
                MetrologyConfirmDialog(
                    title: "删除用户",
                    message: "确定删除用户“\(displayUsername(deleteTarget))”？",
                    eyebrow: "Delete",
                    tone: .expired,
                    cancelTitle: "取消",
                    confirmTitle: "删除",
                    destructive: true,
                    onCancel: {
                        self.deleteTarget = nil
                    },
                    onConfirm: {
                        Task {
                            let success = await viewModel.deleteUser(user: deleteTarget)
                            if success {
                                self.deleteTarget = nil
                            }
                        }
                    }
                )
            }

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
        .overlay {
            if viewModel.isLoading {
                MetrologyLoadingCard(title: "加载中...")
            }
        }
        .navigationTitle("用户管理")
        .task {
            viewModel.configure(currentUsername: appState.session?.username)
            await viewModel.initialLoad()
        }
        .onChange(of: appState.session?.username) {
            viewModel.configure(currentUsername: appState.session?.username)
            Task { await viewModel.loadUsers() }
        }
        .sheet(isPresented: $createSheetOpen) {
            UserCreateSheet(
                onCancel: {
                    createSheetOpen = false
                },
                onSave: { draft in
                    Task {
                        let success = await viewModel.createUser(draft: draft)
                        if success {
                            createSheetOpen = false
                        }
                    }
                }
            )
        }
        .sheet(item: $permissionEditor) { state in
            UserPermissionSheet(
                user: state.user,
                selectedPermissions: state.selectedPermissions,
                onCancel: {
                    permissionEditor = nil
                },
                onSave: { permissions in
                    Task {
                        let success = await viewModel.updatePermissions(user: state.user, permissions: permissions)
                        if success {
                            permissionEditor = nil
                        }
                    }
                }
            )
        }
        .sheet(item: $resetPasswordEditor) { state in
            ResetPasswordSheet(
                user: state.user,
                onCancel: {
                    resetPasswordEditor = nil
                },
                onSave: { password in
                    Task {
                        let success = await viewModel.resetPassword(user: state.user, newPassword: password)
                        if success {
                            resetPasswordEditor = nil
                        }
                    }
                }
            )
        }
    }

    private var topCard: some View {
        HStack(spacing: 8) {
            Text(viewModel.summaryText)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("刷新") {
                Task { await viewModel.loadUsers() }
            }
            .buttonStyle(MetrologySecondaryButtonStyle())

            Button("新增用户") {
                createSheetOpen = true
            }
            .buttonStyle(MetrologyPrimaryButtonStyle())
        }
        .padding(10)
        .metrologyCard()
    }

    private var hintLine: some View {
        MetrologyStatusBanner(message: viewModel.hint, tone: .neutral, compact: true)
    }

    private var userList: some View {
        VStack(spacing: 8) {
            if userRows.isEmpty, !viewModel.isLoading {
                MetrologyEmptyStateView(
                    icon: "person.2",
                    title: "暂无用户数据",
                    message: "可以直接新增一个用户，或稍后刷新再试。"
                )
                .metrologyCard()
            } else {
                ForEach(userRows) { row in
                    UserRowCard(
                        user: row.item,
                        currentUsername: viewModel.currentUsername,
                        onPermission: {
                            let role = (row.item.role ?? "USER").uppercased()
                            guard role != "ADMIN" else { return }
                            permissionEditor = PermissionEditorState(
                                user: row.item,
                                selectedPermissions: Set(row.item.permissions ?? Array(UserPermissionCatalog.defaultCodes))
                            )
                        },
                        onResetPassword: {
                            resetPasswordEditor = ResetPasswordEditorState(user: row.item)
                        },
                        onDelete: {
                            deleteTarget = row.item
                        }
                    )
                }
            }
        }
    }

    private var userRows: [UserRowItem] {
        var duplicated: [String: Int] = [:]
        return viewModel.users.map { item in
            let base = item.id.map { "id:\($0)" } ?? "tmp:\(item.username ?? "")|\(item.createdAt ?? "")"
            let count = duplicated[base, default: 0]
            duplicated[base] = count + 1
            let id = count == 0 ? base : "\(base)#\(count)"
            return UserRowItem(id: id, item: item)
        }
    }

    private func displayUsername(_ user: UserDto?) -> String {
        let text = user?.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "-" : text
    }
}

private struct UserRowItem: Identifiable {
    let id: String
    let item: UserDto
}

private struct UserRowCard: View {
    let user: UserDto
    let currentUsername: String
    let onPermission: () -> Void
    let onResetPassword: () -> Void
    let onDelete: () -> Void

    private var username: String {
        let value = user.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return "-" }
        if value == currentUsername {
            return "\(value)（当前）"
        }
        return value
    }

    private var role: String {
        (user.role ?? "USER").uppercased()
    }

    private var departmentText: String {
        let list = user.departments ?? []
        let trimmedList = list
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !trimmedList.isEmpty {
            return trimmedList.joined(separator: "、")
        }
        let fallback = user.department?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fallback.isEmpty ? "-" : fallback
    }

    private var createdAtText: String {
        let value = user.createdAt?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "-" : value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(username)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(role == "ADMIN" ? "管理员" : "普通用户")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(role == "ADMIN" ? MetrologyPalette.navActive : MetrologyPalette.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(hex: 0xF5F9FF))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color(hex: 0xD8E4F6), lineWidth: 1)
                    )
            }

            Text("部门: \(departmentText)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)

            Text("权限数: \(user.permissions?.count ?? 0)   创建: \(createdAtText)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)

            HStack(spacing: 8) {
                Button("权限设置", action: onPermission)
                    .buttonStyle(MetrologySecondaryButtonStyle())
                    .controlSize(.small)
                    .disabled(role == "ADMIN")
                    .opacity(role == "ADMIN" ? 0.45 : 1)

                Button("重置密码", action: onResetPassword)
                    .buttonStyle(MetrologySecondaryButtonStyle())
                    .controlSize(.small)

                Button("删除", action: onDelete)
                    .buttonStyle(MetrologyDangerButtonStyle())
                    .controlSize(.small)
                    .disabled(user.username == currentUsername)
                    .opacity(user.username == currentUsername ? 0.45 : 1)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(10)
        .metrologyCard()
    }
}

private struct PermissionEditorState: Identifiable {
    let id = UUID()
    let user: UserDto
    let selectedPermissions: Set<String>
}

private struct ResetPasswordEditorState: Identifiable {
    let id = UUID()
    let user: UserDto
}

struct UserCreateDraft {
    var username: String = ""
    var password: String = ""
    var admin: Bool = false
    var permissions: Set<String> = UserPermissionCatalog.defaultCodes
}

private struct UserCreateSheet: View {
    let onCancel: () -> Void
    let onSave: (UserCreateDraft) -> Void

    @State private var draft = UserCreateDraft()
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            MetrologyFormSheetScaffold(
                eyebrow: "User",
                title: "新增用户",
                subtitle: "创建账号并配置基础权限，普通用户的访问范围可在这里一次性完成。",
                accent: .neutral,
                bannerMessage: draft.admin ? "管理员默认拥有全量权限，普通用户权限设置将自动收起。" : "普通用户可按模块勾选权限，后续也可以再进入详情调整。",
                bannerTone: draft.admin ? .warning : .valid
            ) {
                MetrologySectionPanel(
                    title: "基础信息",
                    subtitle: "先填写用户名与登录密码。"
                ) {
                    VStack(spacing: 8) {
                        TextField("用户名", text: $draft.username)
                            .metrologyInput()
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        SecureField("密码（至少6位）", text: $draft.password)
                            .metrologyInput()

                        Toggle("设为管理员", isOn: $draft.admin)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(MetrologyPalette.textPrimary)
                    }
                }

                MetrologySectionPanel(
                    title: "普通用户权限",
                    subtitle: "仅在普通用户模式下生效。"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(UserPermissionCatalog.options) { option in
                            Toggle(
                                option.label,
                                isOn: Binding(
                                    get: {
                                        draft.permissions.contains(option.code)
                                    },
                                    set: { enabled in
                                        if enabled {
                                            draft.permissions.insert(option.code)
                                        } else {
                                            draft.permissions.remove(option.code)
                                        }
                                    }
                                )
                            )
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(MetrologyPalette.textPrimary)
                            .disabled(draft.admin)
                            .opacity(draft.admin ? 0.45 : 1)
                        }
                    }
                }

                if let validationMessage, !validationMessage.isEmpty {
                    MetrologyInlineValidationMessage(message: validationMessage)
                }

                MetrologySaveCancelRow(
                    cancelTitle: "取消",
                    saveTitle: "保存用户",
                    onCancel: onCancel,
                    onSave: {
                        let username = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !username.isEmpty else {
                            validationMessage = "用户名不能为空"
                            return
                        }
                        guard draft.password.count >= 6 else {
                            validationMessage = "密码至少 6 位"
                            return
                        }
                        validationMessage = nil
                        draft.username = username
                        onSave(draft)
                    }
                )
            }
            .navigationTitle("新增用户")
        }
    }
}

private struct UserPermissionSheet: View {
    let user: UserDto
    let selectedPermissions: Set<String>
    let onCancel: () -> Void
    let onSave: (Set<String>) -> Void

    @State private var editingPermissions: Set<String>

    init(
        user: UserDto,
        selectedPermissions: Set<String>,
        onCancel: @escaping () -> Void,
        onSave: @escaping (Set<String>) -> Void
    ) {
        self.user = user
        self.selectedPermissions = selectedPermissions
        self.onCancel = onCancel
        self.onSave = onSave
        _editingPermissions = State(initialValue: selectedPermissions)
    }

    var body: some View {
        NavigationStack {
            MetrologyFormSheetScaffold(
                eyebrow: "Permissions",
                title: "权限设置",
                subtitle: "按模块控制普通用户的访问与维护能力，变更后会立即生效。",
                accent: .warning,
                bannerMessage: "管理员账号默认拥有全量权限，这里只调整普通用户的可访问模块。",
                bannerTone: .warning
            ) {
                MetrologySectionPanel(
                    title: "当前用户",
                    subtitle: "确认本次要调整权限的账号。"
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("用户")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MetrologyPalette.textPrimary)
                        Text(user.username?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? user.username ?? "" : "-")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(MetrologyPalette.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                MetrologySectionPanel(
                    title: "普通用户权限",
                    subtitle: "勾选后即可开放对应模块能力。"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(UserPermissionCatalog.options) { option in
                            Toggle(
                                option.label,
                                isOn: Binding(
                                    get: {
                                        editingPermissions.contains(option.code)
                                    },
                                    set: { enabled in
                                        if enabled {
                                            editingPermissions.insert(option.code)
                                        } else {
                                            editingPermissions.remove(option.code)
                                        }
                                    }
                                )
                            )
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(MetrologyPalette.textPrimary)
                        }
                    }
                }

                MetrologySaveCancelRow(
                    cancelTitle: "取消",
                    saveTitle: "保存权限",
                    onCancel: onCancel,
                    onSave: {
                        onSave(editingPermissions)
                    }
                )
            }
            .navigationTitle("权限设置")
        }
    }
}

private struct ResetPasswordSheet: View {
    let user: UserDto
    let onCancel: () -> Void
    let onSave: (String) -> Void

    @State private var password: String = ""
    @State private var validationMessage: String?

    private var username: String {
        let value = user.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "-" : value
    }

    var body: some View {
        NavigationStack {
            MetrologyFormSheetScaffold(
                eyebrow: "Security",
                title: "重置密码",
                subtitle: "为指定账号设置新的登录密码，保存后旧密码将立即失效。",
                accent: .expired,
                bannerMessage: "新密码至少需要 6 位，建议使用大小写与数字组合。",
                bannerTone: .expired
            ) {
                MetrologySectionPanel(
                    title: "用户账号",
                    subtitle: "确认当前重置对象后再输入新密码。"
                ) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("用户: \(username)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(MetrologyPalette.textSecondary)

                        SecureField("输入新密码（至少6位）", text: $password)
                            .metrologyInput()
                    }
                }

                if let validationMessage, !validationMessage.isEmpty {
                    MetrologyInlineValidationMessage(message: validationMessage)
                }

                MetrologySaveCancelRow(
                    cancelTitle: "取消",
                    saveTitle: "保存密码",
                    onCancel: onCancel,
                    onSave: {
                        guard password.count >= 6 else {
                            validationMessage = "密码至少 6 位"
                            return
                        }
                        validationMessage = nil
                        onSave(password)
                    }
                )
            }
            .navigationTitle("重置密码")
        }
    }
}

@MainActor
final class UserManagementViewModel: ObservableObject {
    @Published private(set) var users: [UserDto] = []
    @Published private(set) var isLoading: Bool = false
    @Published var hint: String = ""
    @Published var errorMessage: String?

    private(set) var currentUsername: String = ""
    private var loaded = false

    var summaryText: String {
        "用户数量: \(users.count)"
    }

    func configure(currentUsername: String?) {
        self.currentUsername = currentUsername?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func initialLoad() async {
        guard !loaded else { return }
        loaded = true
        await loadUsers()
    }

    func loadUsers() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let list = try await APIClient.shared.users()
            users = list
            hint = list.isEmpty ? "暂无用户数据" : "可新增、删除用户，并管理普通用户权限"
        } catch {
            users = []
            hint = ""
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func createUser(draft: UserCreateDraft) async -> Bool {
        let username = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else {
            errorMessage = "用户名不能为空"
            return false
        }
        guard draft.password.count >= 6 else {
            errorMessage = "密码至少 6 位"
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let payload = UserCreatePayload(
                username: username,
                password: draft.password,
                role: draft.admin ? "ADMIN" : "USER",
                departments: [],
                permissions: draft.admin ? [] : Array(draft.permissions).sorted(),
                readonlyFolderIds: []
            )
            _ = try await APIClient.shared.createUser(payload: payload)
            let list = try await APIClient.shared.users()
            users = list
            hint = list.isEmpty ? "暂无用户数据" : "可新增、删除用户，并管理普通用户权限"
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    func updatePermissions(user: UserDto, permissions: Set<String>) async -> Bool {
        guard let id = user.id else {
            errorMessage = "用户ID无效"
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let payload = UserRolePermissionPayload(
                role: "USER",
                departments: resolveDepartments(user),
                permissions: Array(permissions).sorted(),
                readonlyFolderIds: user.readonlyFolderIds ?? []
            )
            _ = try await APIClient.shared.updateUserRolePermissions(id: id, payload: payload)
            let list = try await APIClient.shared.users()
            users = list
            hint = list.isEmpty ? "暂无用户数据" : "可新增、删除用户，并管理普通用户权限"
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    func resetPassword(user: UserDto, newPassword: String) async -> Bool {
        guard let id = user.id else {
            errorMessage = "用户ID无效"
            return false
        }
        let password = newPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard password.count >= 6 else {
            errorMessage = "密码长度不足"
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await APIClient.shared.resetUserPassword(id: id, password: password)
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    func deleteUser(user: UserDto) async -> Bool {
        guard let id = user.id else {
            errorMessage = "用户ID无效"
            return false
        }

        let username = user.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !currentUsername.isEmpty, username == currentUsername {
            errorMessage = "不能删除当前登录用户"
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await APIClient.shared.deleteUser(id: id)
            let list = try await APIClient.shared.users()
            users = list
            hint = list.isEmpty ? "暂无用户数据" : "可新增、删除用户，并管理普通用户权限"
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    private func resolveDepartments(_ user: UserDto) -> [String] {
        let fromList = (user.departments ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !fromList.isEmpty {
            return Array(Set(fromList)).sorted()
        }

        let fallback = user.department?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if fallback.isEmpty {
            return []
        }
        let parts = fallback
            .replacingOccurrences(of: "、", with: ",")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(parts)).sorted()
    }
}

private struct UserPermissionOption: Identifiable {
    let code: String
    let label: String

    var id: String { code }
}

private enum UserPermissionCatalog {
    static let options: [UserPermissionOption] = [
        UserPermissionOption(code: "DEVICE_VIEW", label: "设备查看"),
        UserPermissionOption(code: "DEVICE_CREATE", label: "设备新增"),
        UserPermissionOption(code: "DEVICE_UPDATE", label: "设备编辑"),
        UserPermissionOption(code: "DEVICE_DELETE", label: "设备删除"),
        UserPermissionOption(code: "CALIBRATION_RECORD", label: "校准记录"),
        UserPermissionOption(code: "STATUS_MANAGE", label: "使用状态管理"),
        UserPermissionOption(code: "FILE_ACCESS", label: "我的文件"),
        UserPermissionOption(code: "WEBDAV_ACCESS", label: "网络挂载"),
        UserPermissionOption(code: "USER_MANAGE", label: "用户管理")
    ]

    static let defaultCodes: Set<String> = [
        "DEVICE_VIEW",
        "DEVICE_CREATE",
        "DEVICE_UPDATE",
        "DEVICE_DELETE",
        "CALIBRATION_RECORD",
        "STATUS_MANAGE",
        "FILE_ACCESS",
        "WEBDAV_ACCESS"
    ]
}

private extension Color {
    init(hex: Int, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
