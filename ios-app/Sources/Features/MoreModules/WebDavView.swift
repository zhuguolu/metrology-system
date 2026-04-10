import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct WebDavView: View {
    @StateObject private var viewModel = WebDavViewModel()
    @State private var mountEditor: WebDavMountEditorState?
    @State private var fileActionItem: WebDavFileDto?
    @State private var fileImporterOpen = false
    @State private var shareItem: ShareSheetItem?

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    mountCard
                    hintLine
                    fileList
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            if let fileActionItem {
                fileActionDialog(item: fileActionItem)
            }

            if viewModel.deleteConfirmOpen {
                MetrologyConfirmDialog(
                    title: "删除挂载点",
                    message: "确定删除挂载点“\(viewModel.selectedMountName)”？",
                    eyebrow: "Delete",
                    tone: .expired,
                    cancelTitle: "取消",
                    confirmTitle: "删除",
                    destructive: true,
                    onCancel: {
                        viewModel.deleteConfirmOpen = false
                    },
                    onConfirm: {
                        Task {
                            await viewModel.deleteSelectedMount()
                            viewModel.deleteConfirmOpen = false
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
        .navigationTitle("网络挂载")
        .task {
            await viewModel.initialLoad()
        }
        .sheet(item: $mountEditor) { state in
            WebDavMountEditorSheet(
                title: state.title,
                draft: state.draft,
                onCancel: {
                    mountEditor = nil
                },
                onTest: { draft in
                    Task { await viewModel.testConnection(draft: draft) }
                },
                onSave: { draft in
                    Task {
                        let success = await viewModel.saveMount(draft: draft, editingId: state.editingId)
                        if success {
                            mountEditor = nil
                        }
                    }
                }
            )
        }
        .sheet(item: $viewModel.previewItem, onDismiss: {
            viewModel.handlePreviewDismiss()
        }) { item in
            WebDavPreviewFullScreenView(item: item)
        }
        .sheet(item: $shareItem, onDismiss: {
            viewModel.cleanupSharedFiles()
            shareItem = nil
        }) { item in
            ActivitySheet(items: [item.url])
        }
        .fileImporter(
            isPresented: $fileImporterOpen,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case let .success(urls):
                Task { await viewModel.uploadFiles(urls: urls) }
            case let .failure(error):
                viewModel.errorMessage = error.localizedDescription
            }
        }
        .overlay {
            if viewModel.isLoading {
                MetrologyLoadingCard(title: "加载中...")
            }
        }
    }

    private func fileActionDialog(item: WebDavFileDto) -> some View {
        let displayName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? item.name ?? ""
            : "文件操作"

        return ZStack {
            Color.black.opacity(0.24).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 10) {
                Text(displayName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("请选择文件操作")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("下载到本地") {
                    Task {
                        if let url = await viewModel.download(item: item, openAfterDownload: false) {
                            shareItem = ShareSheetItem(url: url)
                        }
                        fileActionItem = nil
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 42)
                .buttonStyle(MetrologySecondaryButtonStyle())

                Button("下载并预览") {
                    Task {
                        _ = await viewModel.download(item: item, openAfterDownload: true)
                        fileActionItem = nil
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 42)
                .buttonStyle(MetrologyPrimaryButtonStyle())

                Button("取消") {
                    fileActionItem = nil
                }
                .frame(maxWidth: .infinity, minHeight: 42)
                .buttonStyle(MetrologySecondaryButtonStyle())
            }
            .padding(14)
            .frame(maxWidth: 360)
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
            .shadow(color: Color(hex: 0x456B96, alpha: 0.22), radius: 14, x: 0, y: 6)
            .padding(.horizontal, 20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(1000)
    }

    private var mountCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Menu {
                    if viewModel.mounts.isEmpty {
                        Text("无可用挂载点")
                    } else {
                        ForEach(Array(viewModel.mounts.enumerated()), id: \.offset) { _, mount in
                            Button(mount.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? mount.name ?? "" : "未命名挂载点") {
                                viewModel.selectMount(id: mount.id)
                            }
                        }
                    }
                } label: {
                    MetrologySelectField(
                        title: "挂载点",
                        value: viewModel.selectedMountName
                    )
                }
                .frame(maxWidth: .infinity)

                Button("刷新") {
                    Task { await viewModel.loadMounts() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())
            }

            HStack(spacing: 8) {
                Button("新增") {
                    mountEditor = WebDavMountEditorState(
                        title: "新增挂载点",
                        editingId: nil,
                        draft: WebDavMountDraft()
                    )
                }
                .buttonStyle(MetrologyPrimaryButtonStyle())

                Button("编辑") {
                    guard let selected = viewModel.selectedMount else { return }
                    mountEditor = WebDavMountEditorState(
                        title: "编辑挂载点",
                        editingId: selected.id,
                        draft: WebDavMountDraft(item: selected)
                    )
                }
                .buttonStyle(MetrologySecondaryButtonStyle())
                .disabled(viewModel.selectedMount == nil)
                .opacity(viewModel.selectedMount == nil ? 0.45 : 1)

                Button("删除") {
                    viewModel.deleteConfirmOpen = true
                }
                .buttonStyle(MetrologyDangerButtonStyle())
                .disabled(viewModel.selectedMount == nil)
                .opacity(viewModel.selectedMount == nil ? 0.45 : 1)

                Button("测试") {
                    Task { await viewModel.testSelectedMount() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())
                .disabled(viewModel.selectedMount == nil)
                .opacity(viewModel.selectedMount == nil ? 0.45 : 1)
            }

            Text("路径: /\(viewModel.currentPath)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Button("根目录") {
                    Task { await viewModel.goRoot() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())

                Button("上级") {
                    Task { await viewModel.goBack() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())

                Button("刷新目录") {
                    Task { await viewModel.loadFiles() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())

                Button("上传") {
                    fileImporterOpen = true
                }
                .buttonStyle(MetrologyPrimaryButtonStyle())
                .disabled(viewModel.selectedMount == nil)
                .opacity(viewModel.selectedMount == nil ? 0.45 : 1)
            }
        }
        .padding(10)
        .metrologyCard()
    }

    private var hintLine: some View {
        MetrologyStatusBanner(message: viewModel.hint, tone: .neutral, compact: true)
    }

    private var fileList: some View {
        VStack(spacing: 8) {
            if viewModel.files.isEmpty, !viewModel.isLoading {
                MetrologyEmptyStateView(
                    icon: "externaldrive",
                    title: "当前目录暂无文件",
                    message: "可以切换挂载点、返回上级目录，或上传文件到当前路径。"
                )
                .metrologyCard()
            } else {
                ForEach(fileRows) { row in
                    WebDavFileRowCard(
                        item: row.item,
                        onOpen: {
                            if row.item.isDirectory == true {
                                Task { await viewModel.openDirectory(item: row.item) }
                            } else {
                                fileActionItem = row.item
                            }
                        }
                    )
                }
            }
        }
    }

    private var fileRows: [WebDavFileRowItem] {
        var duplicated: [String: Int] = [:]
        return viewModel.files.map { item in
            let base = item.path ?? item.name ?? UUID().uuidString
            let count = duplicated[base, default: 0]
            duplicated[base] = count + 1
            let id = count == 0 ? base : "\(base)#\(count)"
            return WebDavFileRowItem(id: id, item: item)
        }
    }
}

private struct WebDavFileRowItem: Identifiable {
    let id: String
    let item: WebDavFileDto
}

private struct ShareSheetItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct WebDavMountEditorState: Identifiable {
    let id = UUID()
    let title: String
    let editingId: Int64?
    let draft: WebDavMountDraft
}

private struct WebDavFileRowCard: View {
    let item: WebDavFileDto
    let onOpen: () -> Void

    private var isDirectory: Bool {
        item.isDirectory == true
    }

    private var displayName: String {
        let text = item.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "-" : text
    }

    private var displayMeta: String {
        let sizeText: String = isDirectory ? "目录" : formatSize(item.size ?? 0)
        let modifiedText = formatTimestamp(item.modified)
        return "\(sizeText)   修改: \(modifiedText)"
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(isDirectory ? "目录" : "文件")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MetrologyPalette.navActive)
                .frame(width: 34, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: 0xF5F9FF))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: 0xD8E4F6), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(displayName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .lineLimit(1)

                Text(displayMeta)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(isDirectory ? "打开" : "下载", action: onOpen)
                .buttonStyle(MetrologySecondaryButtonStyle())
                .controlSize(.small)
        }
        .padding(10)
        .metrologyCard()
        .contentShape(Rectangle())
        .onTapGesture {
            onOpen()
        }
    }

    private func formatSize(_ size: Int64) -> String {
        if size <= 0 { return "0 B" }
        let kb = 1024.0
        let mb = kb * 1024.0
        let gb = mb * 1024.0
        let sizeDouble = Double(size)

        if sizeDouble < kb {
            return "\(size) B"
        }
        if sizeDouble < mb {
            return String(format: "%.1f KB", sizeDouble / kb)
        }
        if sizeDouble < gb {
            return String(format: "%.1f MB", sizeDouble / mb)
        }
        return String(format: "%.2f GB", sizeDouble / gb)
    }

    private func formatTimestamp(_ millis: Int64?) -> String {
        guard let millis, millis > 0 else { return "-" }
        let date = Date(timeIntervalSince1970: TimeInterval(millis) / 1000.0)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }
}

struct WebDavMountDraft {
    var name: String = ""
    var url: String = ""
    var username: String = ""
    var password: String = ""

    init() {}

    init(item: WebDavMountDto) {
        name = item.name ?? ""
        url = item.url ?? ""
        username = item.username ?? ""
        password = ""
    }
}

private struct WebDavMountEditorSheet: View {
    let title: String
    let draft: WebDavMountDraft
    let onCancel: () -> Void
    let onTest: (WebDavMountDraft) -> Void
    let onSave: (WebDavMountDraft) -> Void

    @State private var editing: WebDavMountDraft
    @State private var validationMessage: String?

    init(
        title: String,
        draft: WebDavMountDraft,
        onCancel: @escaping () -> Void,
        onTest: @escaping (WebDavMountDraft) -> Void,
        onSave: @escaping (WebDavMountDraft) -> Void
    ) {
        self.title = title
        self.draft = draft
        self.onCancel = onCancel
        self.onTest = onTest
        self.onSave = onSave
        _editing = State(initialValue: draft)
    }

    var body: some View {
        NavigationStack {
            MetrologyFormSheetScaffold(
                eyebrow: "WebDAV",
                title: title,
                subtitle: "统一维护网络挂载点地址、账号与密码，用于文件浏览、上传与预览。",
                accent: .neutral,
                bannerMessage: "保存前可以先执行连接测试，确认地址与认证信息可正常访问。",
                bannerTone: .neutral
            ) {
                MetrologySectionPanel(
                    title: "挂载点信息",
                    subtitle: "地址为必填项，用户名与密码可按实际服务配置填写。"
                ) {
                    VStack(spacing: 8) {
                        TextField("挂载点名称", text: $editing.name)
                            .metrologyInput()
                        TextField("WebDAV 地址", text: $editing.url)
                            .metrologyInput()
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        TextField("用户名（可空）", text: $editing.username)
                            .metrologyInput()
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("密码（可空）", text: $editing.password)
                            .metrologyInput()
                    }
                }

                if let validationMessage, !validationMessage.isEmpty {
                    MetrologyInlineValidationMessage(message: validationMessage)
                }

                Button("测试连接") {
                    metrologyDismissKeyboard()
                    guard validate() else { return }
                    onTest(editing)
                }
                .frame(maxWidth: .infinity, minHeight: 22)
                .buttonStyle(MetrologySecondaryButtonStyle())

                MetrologySaveCancelRow(
                    cancelTitle: "取消",
                    saveTitle: "保存挂载点",
                    onCancel: onCancel,
                    onSave: {
                        guard validate() else { return }
                        onSave(editing)
                    }
                )
            }
            .navigationTitle(title)
        }
    }

    private func validate() -> Bool {
        let name = editing.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = editing.url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            validationMessage = "请填写挂载点名称"
            return false
        }
        guard !url.isEmpty else {
            validationMessage = "请填写 WebDAV 地址"
            return false
        }
        validationMessage = nil
        editing.name = name
        editing.url = url
        editing.username = editing.username.trimmingCharacters(in: .whitespacesAndNewlines)
        return true
    }
}

@MainActor
final class WebDavViewModel: ObservableObject {
    @Published private(set) var mounts: [WebDavMountDto] = []
    @Published private(set) var files: [WebDavFileDto] = []
    @Published private(set) var selectedMountId: Int64?
    @Published private(set) var currentPath: String = ""
    @Published private(set) var isLoading: Bool = false
    @Published var hint: String = ""
    @Published var errorMessage: String?
    @Published var previewItem: PreviewItem?
    @Published var deleteConfirmOpen: Bool = false

    private var loaded = false
    private var currentPreviewURL: URL?
    private var previewTempURLs: Set<URL> = []
    private var sharedTempURLs: Set<URL> = []

    var selectedMount: WebDavMountDto? {
        guard let selectedMountId else { return nil }
        return mounts.first { $0.id == selectedMountId }
    }

    var selectedMountName: String {
        if let selectedMount {
            let text = selectedMount.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty {
                return text
            }
            return "未命名挂载点"
        }
        return mounts.isEmpty ? "无可用挂载点" : "选择挂载点"
    }

    func initialLoad() async {
        guard !loaded else { return }
        loaded = true
        await loadMounts()
    }

    func selectMount(id: Int64?) {
        guard selectedMountId != id else { return }
        selectedMountId = id
        currentPath = ""
        Task { await loadFiles() }
    }

    func loadMounts() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let list = try await APIClient.shared.webDavMounts()
            mounts = list

            guard !list.isEmpty else {
                selectedMountId = nil
                currentPath = ""
                files = []
                hint = "暂无挂载点，请先新增"
                return
            }

            if selectedMountId == nil || !list.contains(where: { $0.id == selectedMountId }) {
                selectedMountId = list.first?.id
                currentPath = ""
            }
            await loadFilesInternal()
        } catch {
            mounts = []
            files = []
            selectedMountId = nil
            currentPath = ""
            hint = ""
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func loadFiles() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        await loadFilesInternal()
    }

    func goRoot() async {
        currentPath = ""
        await loadFiles()
    }

    func goBack() async {
        guard !currentPath.isEmpty else { return }
        let parts = currentPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .split(separator: "/")
            .dropLast()
            .map(String.init)
        currentPath = parts.isEmpty ? "" : parts.joined(separator: "/") + "/"
        await loadFiles()
    }

    func openDirectory(item: WebDavFileDto) async {
        let rawPath = item.path?.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        currentPath = rawPath.isEmpty ? "" : "\(rawPath)/"
        await loadFiles()
    }

    func download(item: WebDavFileDto, openAfterDownload: Bool) async -> URL? {
        guard let mountId = selectedMountId else {
            errorMessage = "请先选择挂载点"
            return nil
        }
        let filePath = item.path?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !filePath.isEmpty else {
            errorMessage = "文件路径无效"
            return nil
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let url = try await APIClient.shared.webDavDownload(
                mountId: mountId,
                path: filePath,
                filename: item.name
            )
            let displayName = item.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? item.name ?? "" : url.lastPathComponent
            hint = "下载成功: \(displayName)"
            if openAfterDownload {
                if let previous = currentPreviewURL, previous != url {
                    cleanupPreviewFile(previous)
                }
                currentPreviewURL = url
                registerPreview(url: url)
                previewItem = PreviewItem(url: url, title: displayName)
                return nil
            }
            registerShare(url: url)
            return url
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return nil
        }
    }

    func uploadFiles(urls: [URL]) async {
        guard let mountId = selectedMountId else {
            errorMessage = "请先选择挂载点"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var success = 0
        var fail = 0
        let uploadPath = currentPath.isEmpty ? "/" : (currentPath.hasSuffix("/") ? currentPath : currentPath + "/")

        for url in urls {
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            guard let payload = readUploadMetadata(from: url) else {
                fail += 1
                continue
            }
            do {
                _ = try await APIClient.shared.webDavUpload(
                    mountId: mountId,
                    path: uploadPath,
                    fileName: payload.name,
                    mimeType: payload.mimeType,
                    fileURL: payload.fileURL
                )
                success += 1
            } catch {
                fail += 1
            }
        }

        hint = "上传完成，成功 \(success)，失败 \(fail)"
        await loadFilesInternal()
    }

    func saveMount(draft: WebDavMountDraft, editingId: Int64?) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            if let editingId {
                _ = try await APIClient.shared.updateWebDavMount(
                    id: editingId,
                    body: [
                        "name": draft.name,
                        "url": draft.url,
                        "username": draft.username,
                        "password": draft.password
                    ]
                )
                hint = "挂载点已更新"
            } else {
                _ = try await APIClient.shared.createWebDavMount(
                    name: draft.name,
                    url: draft.url,
                    username: draft.username,
                    password: draft.password
                )
                hint = "挂载点已新增"
            }
            await loadMounts()
            return true
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            return false
        }
    }

    func deleteSelectedMount() async {
        guard let id = selectedMount?.id else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await APIClient.shared.deleteWebDavMount(id: id)
            hint = "挂载点已删除"
            if selectedMountId == id {
                selectedMountId = nil
                currentPath = ""
            }
            await loadMounts()
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func testSelectedMount() async {
        guard let mount = selectedMount else {
            errorMessage = "请先选择挂载点"
            return
        }
        let draft = WebDavMountDraft(item: mount)
        await testConnection(draft: draft)
    }

    func testConnection(draft: WebDavMountDraft) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let success = try await APIClient.shared.testWebDavConnection(
                url: draft.url,
                username: draft.username,
                password: draft.password
            )
            hint = success ? "连接测试成功" : "连接测试失败"
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func handlePreviewDismiss() {
        guard let current = currentPreviewURL else { return }
        currentPreviewURL = nil
        previewItem = nil
        cleanupPreviewFile(current)
    }

    func cleanupSharedFiles() {
        let urls = Array(sharedTempURLs)
        sharedTempURLs.removeAll()
        urls.forEach { removeTempFileIfExists($0) }
    }

    private func loadFilesInternal() async {
        guard let mountId = selectedMountId else {
            files = []
            hint = "请先选择挂载点"
            return
        }

        do {
            let list = try await APIClient.shared.webDavBrowse(
                mountId: mountId,
                path: currentPath.isEmpty ? nil : currentPath
            )
            files = list
            hint = list.isEmpty ? "当前目录暂无文件" : "共 \(list.count) 项"
        } catch {
            files = []
            hint = ""
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    private func readUploadMetadata(from url: URL) -> UploadPayload? {
        do {
            let filename = url.lastPathComponent.isEmpty ? "upload_\(Int(Date().timeIntervalSince1970)).bin" : url.lastPathComponent
            let mimeType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.preferredMIMEType
            return UploadPayload(name: filename, mimeType: mimeType, fileURL: url)
        } catch {
            return nil
        }
    }

    private func registerPreview(url: URL) {
        previewTempURLs.insert(url)
    }

    private func cleanupPreviewFile(_ url: URL) {
        if previewTempURLs.contains(url) {
            previewTempURLs.remove(url)
            removeTempFileIfExists(url)
        }
    }

    private func registerShare(url: URL) {
        sharedTempURLs.insert(url)
    }

    private func removeTempFileIfExists(_ url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            // Ignore cleanup errors.
        }
    }
}

private struct UploadPayload {
    let name: String
    let mimeType: String?
    let fileURL: URL
}

private struct WebDavPreviewFullScreenView: View {
    let item: PreviewItem

    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            QuickLookPreview(url: item.url)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                        .lineLimit(1)

                    Text("WebDAV 文件预览")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                }

                Spacer(minLength: 10)

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.94))
                        )
                        .overlay(
                            Circle()
                                .stroke(MetrologyPalette.stroke, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.96), Color(hex: 0xF6FAFF, alpha: 0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(MetrologyPalette.stroke, lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x7A95B8, alpha: 0.12), radius: 8, x: 0, y: 3)
            .padding(.horizontal, 14)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(
                LinearGradient(
                    colors: [
                        MetrologyPalette.background.opacity(0.96),
                        MetrologyPalette.background.opacity(0.82),
                        MetrologyPalette.background.opacity(0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Label("关闭预览", systemImage: "xmark")
                        .frame(maxWidth: .infinity, minHeight: 22)
                }
                .buttonStyle(MetrologySecondaryButtonStyle())

                Button {
                    showShareSheet = true
                } label: {
                    Label("分享文件", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity, minHeight: 22)
                }
                .buttonStyle(MetrologyPrimaryButtonStyle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.97), Color(hex: 0xF5F9FF, alpha: 0.96)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(MetrologyPalette.stroke, lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x7A95B8, alpha: 0.12), radius: 8, x: 0, y: 3)
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [
                        MetrologyPalette.background.opacity(0),
                        MetrologyPalette.background.opacity(0.82),
                        MetrologyPalette.background.opacity(0.96)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ActivitySheet(items: [item.url])
        }
    }
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private extension Color {
    init(hex: Int, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
