import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @StateObject private var viewModel = FilesViewModel()
    @State private var fileImporterOpen = false
    @State private var createFolderDialogOpen = false
    @State private var createFolderName = ""
    @State private var searchText = ""
    @State private var selectedItemIDs: Set<Int64> = []
    @State private var showMoveTargetSheet = false
    @State private var moveTargets: [FilesViewModel.MoveTarget] = []
    @State private var moveTargetLoading = false
    @State private var showMoreActions = false
    @State private var showRenameDialog = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var activityItems: [Any] = []
    @State private var showActivitySheet = false

    var body: some View {
        contentWithDialogs
    }

    private var mainListContent: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    headerPanel

                    if fileRows.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.system(size: 30))
                                .foregroundStyle(MetrologyPalette.textMuted)
                            Text("当前目录暂无文件")
                                .foregroundStyle(MetrologyPalette.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 26)
                        .metrologyCard()
                    } else {
                        ForEach(fileRows) { row in
                            fileRow(item: row.item)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, hasSelection ? 86 : 14)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(backToParentGesture, including: .subviews)
        }
    }

    private var contentWithLifecycle: some View {
        mainListContent
            .navigationTitle("我的文件")
            .task {
                await viewModel.load()
            }
            .onDisappear {
                viewModel.cancelPreviewLoading()
            }
            .onChange(of: viewModel.currentFolderId) { _, _ in
                searchText = ""
                selectedItemIDs.removeAll()
            }
            .onChange(of: viewModel.items.map(\.id)) { _, ids in
                let validIDs = Set(ids.compactMap { $0 })
                selectedItemIDs = selectedItemIDs.intersection(validIDs)
            }
            .onReceive(NotificationCenter.default.publisher(for: .metrologyExternalFilesImported)) { _ in
                Task {
                    await viewModel.goRoot()
                }
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
            .alert("新建文件夹", isPresented: $createFolderDialogOpen) {
                TextField("请输入文件夹名称", text: $createFolderName)
                Button("取消", role: .cancel) {
                    createFolderName = ""
                }
                Button("创建") {
                    let pendingName = createFolderName
                    createFolderName = ""
                    Task {
                        _ = await viewModel.createFolder(name: pendingName)
                    }
                }
            } message: {
                Text("将在当前目录创建子文件夹")
            }
            .overlay {
                if viewModel.isLoading {
                    loadingOverlay
                }
            }
            .fullScreenCover(item: $viewModel.previewItem, onDismiss: {
                viewModel.handlePreviewDismiss()
            }) { item in
                FilePreviewFullScreenView(item: item)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if hasSelection {
                    selectionActionBar
                }
            }
    }

    private var contentWithDialogs: some View {
        contentWithLifecycle
            .sheet(isPresented: $showMoveTargetSheet) {
                moveTargetSheet
            }
            .sheet(isPresented: $showActivitySheet) {
                FilesActivitySheet(items: activityItems)
            }
            .confirmationDialog("更多操作", isPresented: $showMoreActions, titleVisibility: .visible) {
                if canRenameSelected {
                    Button("重命名") {
                        prepareRename()
                    }
                }
                Button("删除", role: .destructive) {
                    showDeleteConfirm = true
                }
                Button("取消", role: .cancel) {}
            }
            .alert("重命名", isPresented: $showRenameDialog) {
                TextField("请输入新名称", text: $renameText)
                Button("取消", role: .cancel) {
                    renameText = ""
                }
                Button("保存") {
                    Task { await renameSelectedItem() }
                }
            } message: {
                Text("仅支持单个文件或文件夹重命名")
            }
            .alert("确认删除", isPresented: $showDeleteConfirm) {
                Button("取消", role: .cancel) {}
                Button("删除", role: .destructive) {
                    Task { await deleteSelectedItems() }
                }
            } message: {
                Text("已选择 \(selectedItems.count) 项，删除后无法恢复")
            }
    }

    private var loadingOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(loadingOverlayTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                Spacer()
                if canCancelPreviewLoading {
                    Button("取消") {
                        viewModel.cancelPreviewLoading()
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(MetrologyPalette.navActive)
                    .buttonStyle(.plain)
                }
            }

            ProgressView()
                .controlSize(.small)
                .tint(MetrologyPalette.navActive)
        }
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

    private var selectionActionBar: some View {
        HStack(spacing: 8) {
            selectionActionButton(title: "复制", systemImage: "doc.on.doc") {
                Task { await copySelectedItems() }
            }

            selectionActionButton(title: "移动", systemImage: "folder") {
                Task { await openMoveTargetPicker() }
            }

            selectionActionButton(title: "下载", systemImage: "arrow.down.circle") {
                Task { await downloadSelectedItems() }
            }

            selectionActionButton(title: "更多", systemImage: "ellipsis.circle") {
                showMoreActions = true
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(MetrologyPalette.surface)
        .overlay(
            Rectangle()
                .fill(MetrologyPalette.stroke)
                .frame(height: 1),
            alignment: .top
        )
    }

    private func selectionActionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(MetrologyPalette.navActive)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private var moveTargetSheet: some View {
        NavigationStack {
            Group {
                if moveTargetLoading {
                    ProgressView("加载目标目录...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(moveTargets) { target in
                        Button {
                            showMoveTargetSheet = false
                            Task { await moveSelectedItems(to: target.folderId) }
                        } label: {
                            HStack {
                                Text(target.title)
                                    .foregroundStyle(MetrologyPalette.textPrimary)
                                Spacer()
                                if target.folderId == viewModel.currentFolderId {
                                    Text("当前")
                                        .font(.caption2)
                                        .foregroundStyle(MetrologyPalette.textMuted)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("选择目标目录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") {
                        showMoveTargetSheet = false
                    }
                }
            }
        }
    }

    private var headerPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            searchField

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("路径")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                    Text(viewModel.currentPath)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                HStack(spacing: 6) {
                    headerIconActionButton(
                        title: "根目录",
                        systemImage: "house.fill",
                        style: .primary
                    ) {
                        Task { await viewModel.goRoot() }
                    }

                    headerIconActionButton(
                        title: "上级",
                        systemImage: "arrow.up.left",
                        style: .secondary
                    ) {
                        Task { await viewModel.goBack() }
                    }
                    .disabled(viewModel.currentFolderId == nil)
                    .opacity(viewModel.currentFolderId == nil ? 0.45 : 1)

                    headerIconActionButton(
                        title: "刷新",
                        systemImage: "arrow.clockwise",
                        style: .secondary
                    ) {
                        Task { await viewModel.load() }
                    }
                }
            }

            if isSearching || !viewModel.hint.isEmpty {
                Text(searchHint)
                    .font(.footnote)
                    .foregroundStyle(MetrologyPalette.textSecondary)
            }

            if let scanSyncMessage = viewModel.scanSyncMessage, !scanSyncMessage.isEmpty {
                Text(scanSyncMessage)
                    .font(.footnote)
                    .foregroundStyle(MetrologyPalette.navActive)
            }

            if viewModel.readOnlyFolder {
                Text("当前目录为只读，已禁用上传/新建/扫描同步")
                    .font(.footnote)
                    .foregroundStyle(MetrologyPalette.statusWarning)
            }

            if let message = viewModel.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(MetrologyPalette.statusExpired)
            }

            HStack(spacing: 8) {
                headerPrimaryActionButton(
                    title: "上传",
                    systemImage: "arrow.up.circle.fill",
                    style: .primary
                ) {
                    fileImporterOpen = true
                }
                .disabled(!viewModel.canWrite)
                .opacity(viewModel.canWrite ? 1 : 0.45)

                headerPrimaryActionButton(
                    title: "新建文件夹",
                    systemImage: "folder.badge.plus",
                    style: .secondary
                ) {
                    createFolderName = ""
                    createFolderDialogOpen = true
                }
                .disabled(!viewModel.canWrite)
                .opacity(viewModel.canWrite ? 1 : 0.45)

                headerPrimaryActionButton(
                    title: "同步",
                    systemImage: "arrow.triangle.2.circlepath",
                    style: .secondary
                ) {
                    Task { await viewModel.scanSync() }
                }
                .disabled(!viewModel.canWrite)
                .opacity(viewModel.canWrite ? 1 : 0.45)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .metrologyCard()
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(MetrologyPalette.textMuted)

            TextField("搜索文件/文件夹", text: $searchText)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MetrologyPalette.textPrimary)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if isSearching {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(MetrologyPalette.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 38)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(MetrologyPalette.stroke, lineWidth: 1)
        )
    }

    private enum HeaderActionStyle {
        case primary
        case secondary
    }

    private func headerIconActionButton(
        title: String,
        systemImage: String,
        style: HeaderActionStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 28, height: 28)
        }
        .foregroundStyle(style == .primary ? Color.white : MetrologyPalette.textPrimary)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(style == .primary ? MetrologyPalette.navActive : Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(
                    style == .primary ? MetrologyPalette.navActive : MetrologyPalette.stroke,
                    lineWidth: 1
                )
        )
        .accessibilityLabel(title)
        .buttonStyle(.plain)
    }

    private func headerPrimaryActionButton(
        title: String,
        systemImage: String,
        style: HeaderActionStyle,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 34)
        }
        .foregroundStyle(style == .primary ? Color.white : MetrologyPalette.textPrimary)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    style == .primary
                        ? AnyShapeStyle(
                            LinearGradient(
                                colors: [MetrologyPalette.brandBlue, MetrologyPalette.navActive],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        : AnyShapeStyle(Color.white)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(
                    style == .primary ? MetrologyPalette.navActive : MetrologyPalette.stroke,
                    lineWidth: 1
                )
        )
        .buttonStyle(.plain)
    }

    private var backToParentGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                guard viewModel.currentFolderId != nil else { return }
                let fromLeftEdge = value.startLocation.x <= 28
                let horizontalEnough = value.translation.width >= 80
                let mostlyHorizontal = abs(value.translation.width) > abs(value.translation.height) * 1.2
                guard fromLeftEdge, horizontalEnough, mostlyHorizontal else { return }
                Task { await viewModel.goBack() }
            }
    }

    private func fileRow(item: UserFileItemDto) -> some View {
        let iconStyle = fileIconStyle(for: item)
        return HStack(spacing: 12) {
            Button {
                handleRowTap(item)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: iconStyle.symbolName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconStyle.tint)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(MetrologyPalette.surface)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.displayName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(MetrologyPalette.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(fileMetaText(for: item))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(MetrologyPalette.textSecondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            selectionCircle(item: item)
        }
        .padding(12)
        .metrologyCard()
    }

    private var fileRows: [FileListRow] {
        var duplicated: [String: Int] = [:]
        return filteredItems.map { item in
            let base = baseFileRowID(item)
            let count = duplicated[base, default: 0]
            duplicated[base] = count + 1
            let id = count == 0 ? base : "\(base)#\(count)"
            return FileListRow(id: id, item: item)
        }
    }

    private var filteredItems: [UserFileItemDto] {
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return viewModel.items }
        return viewModel.items.filter { item in
            let rawName = (item.name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return item.displayName.localizedCaseInsensitiveContains(keyword)
                || rawName.localizedCaseInsensitiveContains(keyword)
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var searchHint: String {
        if isSearching {
            return "筛选结果：\(fileRows.count)/\(viewModel.items.count)"
        }
        return viewModel.hint
    }

    private var hasSelection: Bool {
        !selectedItemIDs.isEmpty
    }

    private var selectedItems: [UserFileItemDto] {
        viewModel.items.filter { item in
            guard let id = item.id else { return false }
            return selectedItemIDs.contains(id)
        }
    }

    private var canRenameSelected: Bool {
        selectedItems.count == 1
    }

    private func handleRowTap(_ item: UserFileItemDto) {
        if hasSelection, item.id != nil {
            toggleSelection(for: item)
            return
        }
        Task { await viewModel.open(item) }
    }

    @ViewBuilder
    private func selectionCircle(item: UserFileItemDto) -> some View {
        if let id = item.id {
            Button {
                toggleSelection(for: item)
            } label: {
                Image(systemName: selectedItemIDs.contains(id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(selectedItemIDs.contains(id) ? MetrologyPalette.navActive : MetrologyPalette.textMuted)
            }
            .buttonStyle(.plain)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(MetrologyPalette.textMuted.opacity(0.35))
        }
    }

    private func toggleSelection(for item: UserFileItemDto) {
        guard let id = item.id else { return }
        if selectedItemIDs.contains(id) {
            selectedItemIDs.remove(id)
        } else {
            selectedItemIDs.insert(id)
        }
    }

    private var loadingOverlayTitle: String {
        if viewModel.isUploading {
            return "正在上传..."
        }
        if viewModel.previewLoadingFileId != nil {
            return "正在加载预览..."
        }
        return "处理中..."
    }

    private var canCancelPreviewLoading: Bool {
        viewModel.previewLoadingFileId != nil
    }

    private func copySelectedItems() async {
        let items = selectedItems
        guard !items.isEmpty else { return }
        await viewModel.copyItemsToCurrentFolder(items)
        selectedItemIDs.removeAll()
    }

    private func openMoveTargetPicker() async {
        moveTargetLoading = true
        showMoveTargetSheet = true
        moveTargets = await viewModel.fetchMoveTargets()
        moveTargetLoading = false
    }

    private func moveSelectedItems(to parentId: Int64?) async {
        let ids = selectedItems.compactMap { $0.id }
        guard !ids.isEmpty else { return }
        await viewModel.moveItems(ids, to: parentId)
        selectedItemIDs.removeAll()
    }

    private func downloadSelectedItems() async {
        let items = selectedItems
        guard !items.isEmpty else { return }
        let urls = await viewModel.prepareDownloads(for: items)
        guard !urls.isEmpty else { return }
        activityItems = urls
        showActivitySheet = true
        selectedItemIDs.removeAll()
    }

    private func prepareRename() {
        guard let item = selectedItems.first else { return }
        renameText = item.displayName
        showRenameDialog = true
    }

    private func renameSelectedItem() async {
        guard let item = selectedItems.first, let id = item.id else { return }
        let success = await viewModel.renameItem(id: id, newName: renameText)
        if success {
            selectedItemIDs.removeAll()
        }
    }

    private func deleteSelectedItems() async {
        let ids = selectedItems.compactMap { $0.id }
        guard !ids.isEmpty else { return }
        await viewModel.deleteItems(ids)
        selectedItemIDs.removeAll()
    }

    private func fileMetaText(for item: UserFileItemDto) -> String {
        let dateText = displayDateOnly(item.createdAt)
        let sizeText = item.isFolder ? "文件夹" : displayFileSize(item.fileSize)
        if dateText == "--" {
            return sizeText
        }
        return "\(dateText) · \(sizeText)"
    }

    private func displayDateOnly(_ raw: String?) -> String {
        let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return "--" }

        if text.count >= 10 {
            let prefix = String(text.prefix(10))
            if prefix.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil {
                return prefix
            }
        }

        if let date = Self.isoDateFormatterWithFractionalSeconds.date(from: text)
            ?? Self.isoDateFormatter.date(from: text) {
            return Self.dayFormatter.string(from: date)
        }

        return text
    }

    private func displayFileSize(_ bytes: Int64?) -> String {
        guard let bytes, bytes >= 0 else { return "--" }
        return Self.fileSizeFormatter.string(fromByteCount: bytes)
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let isoDateFormatterWithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let fileSizeFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        formatter.includesActualByteCount = false
        return formatter
    }()

    private func fileIconStyle(for item: UserFileItemDto) -> FileIconStyle {
        if item.isFolder {
            return FileIconStyle(symbolName: "folder.fill", tint: MetrologyPalette.navActive)
        }

        let ext = fileExtension(of: item)
        let mime = (item.mimeType ?? "").lowercased()

        if ["pdf"].contains(ext) {
            return FileIconStyle(symbolName: "doc.richtext.fill", tint: MetrologyPalette.statusExpired)
        }
        if ["doc", "docx", "rtf", "pages"].contains(ext) {
            return FileIconStyle(symbolName: "doc.text.fill", tint: MetrologyPalette.navActive)
        }
        if ["xls", "xlsx", "csv", "numbers"].contains(ext) {
            return FileIconStyle(symbolName: "tablecells.fill", tint: MetrologyPalette.statusValid)
        }
        if ["ppt", "pptx", "key"].contains(ext) {
            return FileIconStyle(symbolName: "rectangle.on.rectangle.angled.fill", tint: MetrologyPalette.statusWarning)
        }
        if ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "heif", "tif", "tiff", "svg"].contains(ext)
            || mime.hasPrefix("image/") {
            return FileIconStyle(symbolName: "photo.fill", tint: MetrologyPalette.statusValid)
        }
        if ["mp4", "mov", "m4v", "avi", "wmv", "mkv", "flv", "webm"].contains(ext)
            || mime.hasPrefix("video/") {
            return FileIconStyle(symbolName: "film.fill", tint: MetrologyPalette.statusWarning)
        }
        if ["mp3", "wav", "m4a", "aac", "flac", "ogg", "wma"].contains(ext)
            || mime.hasPrefix("audio/") {
            return FileIconStyle(symbolName: "music.note", tint: MetrologyPalette.navInactive)
        }
        if ["zip", "rar", "7z", "tar", "gz", "bz2", "xz"].contains(ext) {
            return FileIconStyle(symbolName: "archivebox.fill", tint: MetrologyPalette.textSecondary)
        }
        if ["json", "xml", "yaml", "yml", "html", "htm", "css", "js", "ts", "tsx", "jsx", "java", "kt", "swift", "py", "go", "c", "cc", "cpp", "h", "hpp", "sql", "sh", "md"].contains(ext)
            || mime.contains("json")
            || mime.contains("xml")
            || mime.contains("javascript")
            || mime.contains("text/") {
            return FileIconStyle(symbolName: "chevron.left.forwardslash.chevron.right", tint: MetrologyPalette.navInactive)
        }
        if ["apk", "ipa", "exe", "msi", "dmg", "pkg", "deb", "rpm"].contains(ext) {
            return FileIconStyle(symbolName: "shippingbox.fill", tint: MetrologyPalette.navActive)
        }

        return FileIconStyle(symbolName: "doc.fill", tint: MetrologyPalette.textMuted)
    }

    private func fileExtension(of item: UserFileItemDto) -> String {
        let rawName = (item.name ?? item.displayName).trimmingCharacters(in: .whitespacesAndNewlines)
        guard let dotIndex = rawName.lastIndex(of: "."), dotIndex < rawName.index(before: rawName.endIndex) else {
            return ""
        }
        let suffix = rawName[rawName.index(after: dotIndex)...]
        return suffix.lowercased()
    }

    private func baseFileRowID(_ item: UserFileItemDto) -> String {
        if let id = item.id {
            return "id:\(id)"
        }
        return "tmp:\(item.parentId.map(String.init) ?? "")|\(item.name ?? "")|\(item.type ?? "")|\(item.filePath ?? "")"
    }
}

private struct FileListRow: Identifiable {
    let id: String
    let item: UserFileItemDto
}

private struct FileIconStyle {
    let symbolName: String
    let tint: Color
}

private struct FilePreviewFullScreenView: View {
    let item: PreviewItem

    @Environment(\.dismiss) private var dismiss
    @State private var showExternalSheet = false

    var body: some View {
        NavigationStack {
            QuickLookPreview(url: item.url)
                .navigationTitle(item.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("关闭") {
                            dismiss()
                        }
                    }
                }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(MetrologyPalette.stroke)
                    .frame(height: 1)
                Button {
                    showExternalSheet = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.up.forward.app")
                        Text("外部打开")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(MetrologyPalette.navActive)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 14)
                }
                .buttonStyle(.plain)
            }
            .background(MetrologyPalette.surface)
        }
        .sheet(isPresented: $showExternalSheet) {
            FilesActivitySheet(items: [item.url])
        }
    }
}

private struct FilesActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
