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
                VStack(spacing: 14) {
                    heroSection
                    headerPanel
                    contentPanel
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
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
            .overlay {
                ZStack {
                    if viewModel.isLoading {
                        loadingOverlay
                    }

                    dialogsOverlay
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
    }

    @ViewBuilder
    private var dialogsOverlay: some View {
        if createFolderDialogOpen {
            FilesTextEntryDialog(
                eyebrow: "Create",
                title: "新建文件夹",
                subtitle: "将在当前目录创建新的子文件夹。",
                placeholder: "请输入文件夹名称",
                text: $createFolderName,
                tone: .valid,
                confirmTitle: "创建",
                onCancel: {
                    createFolderName = ""
                    createFolderDialogOpen = false
                },
                onConfirm: {
                    let pendingName = createFolderName
                    createFolderName = ""
                    createFolderDialogOpen = false
                    Task {
                        _ = await viewModel.createFolder(name: pendingName)
                    }
                }
            )
        }

        if showMoreActions {
            FilesActionMenuDialog(
                canRename: canRenameSelected,
                onRename: {
                    showMoreActions = false
                    prepareRename()
                },
                onDelete: {
                    showMoreActions = false
                    showDeleteConfirm = true
                },
                onCancel: {
                    showMoreActions = false
                }
            )
        }

        if showRenameDialog {
            FilesTextEntryDialog(
                eyebrow: "Rename",
                title: "重命名",
                subtitle: "仅支持单个文件或文件夹重命名。",
                placeholder: "请输入新名称",
                text: $renameText,
                tone: .neutral,
                confirmTitle: "保存",
                onCancel: {
                    renameText = ""
                    showRenameDialog = false
                },
                onConfirm: {
                    showRenameDialog = false
                    Task { await renameSelectedItem() }
                }
            )
        }

        if showDeleteConfirm {
            MetrologyConfirmDialog(
                title: "确认删除",
                message: "已选择 \(selectedItems.count) 项，删除后无法恢复。",
                eyebrow: "Delete",
                tone: .expired,
                confirmTitle: "删除",
                destructive: true,
                onCancel: {
                    showDeleteConfirm = false
                },
                onConfirm: {
                    showDeleteConfirm = false
                    Task { await deleteSelectedItems() }
                }
            )
        }
    }

    private var heroSection: some View {
        MetrologyPageHeroCard(
            eyebrow: "Files",
            title: "我的文件",
            subtitle: "统一管理文件夹、资料与预览动作，支持根目录、返回上级、同步与批量处理。",
            accent: .neutral
        ) {
            VStack(alignment: .trailing, spacing: 8) {
                Text("当前")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)

                Text("\(fileRows.count)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(MetrologyPalette.navActive)

                Text(isSearching ? "筛选结果" : "可见项目")
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
                    .stroke(Color(hex: 0xC5D8F7), lineWidth: 1)
            )
        }
    }

    private var headerPanel: some View {
        MetrologySectionPanel(
            title: "目录工具",
            subtitle: "支持搜索、返回上级、刷新、上传、新建文件夹与同步。"
        ) {
            VStack(alignment: .leading, spacing: 10) {
                searchField

                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("路径")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(MetrologyPalette.textSecondary)

                        Text(viewModel.currentPath)
                            .font(.system(size: 13, weight: .bold))
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
                    noticeLine(searchHint, tone: .neutral)
                }

                if let scanSyncMessage = viewModel.scanSyncMessage, !scanSyncMessage.isEmpty {
                    noticeLine(scanSyncMessage, tone: .neutral)
                }

                if viewModel.readOnlyFolder {
                    noticeLine("当前目录为只读，已禁用上传、新建与同步。", tone: .warning)
                }

                if let message = viewModel.errorMessage {
                    noticeLine(message, tone: .expired)
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
        }
    }
    private var contentPanel: some View {
        MetrologySectionPanel(
            title: "文件列表",
            subtitle: isSearching ? "正在显示筛选结果。" : "点击文件可预览，点击文件夹可进入目录。"
        ) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    fileCountPill(title: "总数", value: "\(fileRows.count)", tone: .neutral)
                    fileCountPill(title: "文件夹", value: "\(visibleFolderCount)", tone: .valid)
                    fileCountPill(title: "文件", value: "\(visibleFileCount)", tone: .warning)
                }

                if let errorMessage = viewModel.errorMessage, fileRows.isEmpty {
                    MetrologyErrorStateView(
                        title: "文件加载失败",
                        message: errorMessage,
                        actionTitle: "重新加载",
                        action: {
                            Task { await viewModel.load() }
                        }
                    )
                } else if fileRows.isEmpty {
                    emptyStateView
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(fileRows) { row in
                            fileRow(item: row.item)
                        }
                    }
                }
            }
        }
    }

    private func noticeLine(_ message: String, tone: MetrologyPillTone) -> some View {
        MetrologyStatusBanner(message: message, tone: tone)
    }

    private var loadingOverlay: some View {
        MetrologyLoadingCard(
            title: loadingOverlayTitle,
            fraction: viewModel.batchProgressFraction,
            actionTitle: canCancelPreviewLoading ? "取消" : nil,
            action: canCancelPreviewLoading ? { viewModel.cancelPreviewLoading() } : nil
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
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.97), Color(hex: 0xF5F9FF, alpha: 0.95)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(MetrologyPalette.stroke, lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x7A95B8, alpha: 0.10), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
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
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.88))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(MetrologyPalette.stroke, lineWidth: 1)
        )
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
                        .frame(width: 34, height: 34)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(MetrologyPalette.stroke, lineWidth: 1)
                        )

                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.isFolder ? "文件夹" : "文件")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(item.isFolder ? MetrologyPalette.statusValid : MetrologyPalette.navActive)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(
                                        (item.isFolder ? MetrologyPalette.statusValid : MetrologyPalette.navActive)
                                            .opacity(0.12)
                                    )
                            )

                        Text(item.displayName)
                            .font(.system(size: 14, weight: .bold))
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

    private var visibleFolderCount: Int {
        filteredItems.filter(\.isFolder).count
    }

    private var visibleFileCount: Int {
        filteredItems.filter { !$0.isFolder }.count
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
        if let batchText = viewModel.batchProgressText {
            return batchText
        }
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
        renameText = ""
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

    private func fileCountPill(title: String, value: String, tone: MetrologyPillTone) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(tone.tint)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(MetrologyPalette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tone.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tone.stroke, lineWidth: 1)
        )
    }

    private var emptyStateView: some View {
        MetrologyEmptyStateView(
            icon: isSearching ? "magnifyingglass.circle" : "tray",
            title: isSearching ? "没有匹配到相关文件" : "当前目录暂无文件",
            message: isSearching ? "可以尝试更换关键词，或先清空搜索条件。" : "你可以上传文件、新建文件夹，或点击同步拉取最新内容。"
        )
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

private struct FilesTextEntryDialog: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let placeholder: String
    @Binding var text: String
    var tone: MetrologyPillTone = .neutral
    var confirmTitle: String = "保存"
    let onCancel: () -> Void
    let onConfirm: () -> Void

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.24).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(tone.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(tone.strongBackground)
                    )

                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)

                MetrologyStatusBanner(message: subtitle, tone: tone)

                TextField(placeholder, text: $text)
                    .metrologyInput()

                if trimmedText.isEmpty {
                    MetrologyInlineValidationMessage(message: "名称不能为空，请先填写后再继续。")
                }

                MetrologySaveCancelRow(
                    cancelTitle: "取消",
                    saveTitle: confirmTitle,
                    saveDisabled: trimmedText.isEmpty,
                    onCancel: onCancel,
                    onSave: onConfirm
                )
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
        .preferredColorScheme(.light)
    }
}

private struct FilesActionMenuDialog: View {
    let canRename: Bool
    let onRename: () -> Void
    let onDelete: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text("ACTIONS")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(MetrologyPalette.navActive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color(hex: 0xE7F0FF))
                    )

                Text("更多操作")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)

                MetrologyStatusBanner(
                    message: canRename ? "可继续执行重命名或删除操作。" : "当前已选择多项，仅保留删除操作。",
                    tone: canRename ? .neutral : .warning
                )

                VStack(spacing: 8) {
                    if canRename {
                        Button(action: onRename) {
                            Label("重命名", systemImage: "pencil")
                                .frame(maxWidth: .infinity, minHeight: 22)
                        }
                        .buttonStyle(MetrologySecondaryButtonStyle())
                    }

                    Button(action: onDelete) {
                        Label("删除", systemImage: "trash")
                            .frame(maxWidth: .infinity, minHeight: 22)
                    }
                    .buttonStyle(MetrologyDangerButtonStyle())

                    Button(action: onCancel) {
                        Text("取消")
                            .frame(maxWidth: .infinity, minHeight: 22)
                    }
                    .buttonStyle(MetrologySecondaryButtonStyle())
                }
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
        .preferredColorScheme(.light)
    }
}

private struct FilePreviewFullScreenView: View {
    let item: PreviewItem

    @Environment(\.dismiss) private var dismiss
    @State private var showExternalSheet = false

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            QuickLookPreview(url: item.url)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            previewHeader
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
            previewBottomBar
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
        .sheet(isPresented: $showExternalSheet) {
            FilesActivitySheet(items: [item.url])
        }
    }

    private var previewHeader: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.94))
                        .frame(width: 42, height: 42)
                    Image(systemName: previewIconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(previewAccent)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(compactTitle)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                        .lineLimit(1)

                    Text(previewSubtitle)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                        .lineLimit(1)
                }
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
    }

    private var previewBottomBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Label("关闭预览", systemImage: "xmark")
                    .frame(maxWidth: .infinity, minHeight: 22)
            }
            .buttonStyle(MetrologySecondaryButtonStyle())

            Button {
                showExternalSheet = true
            } label: {
                Label("外部打开或分享", systemImage: "arrow.up.forward.app")
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
    }

    private var compactTitle: String {
        if item.title.count > 28 {
            return String(item.title.prefix(26)) + "..."
        }
        return item.title
    }

    private var previewSubtitle: String {
        let ext = item.url.pathExtension.uppercased()
        if ext.isEmpty {
            return "文件预览"
        }
        return "\(ext) 文件预览"
    }

    private var previewIconName: String {
        let ext = item.url.pathExtension.lowercased()
        if ["pdf"].contains(ext) { return "doc.richtext.fill" }
        if ["xls", "xlsx", "csv", "numbers"].contains(ext) { return "tablecells.fill" }
        if ["doc", "docx", "pages", "rtf"].contains(ext) { return "doc.text.fill" }
        if ["ppt", "pptx", "key"].contains(ext) { return "rectangle.on.rectangle.angled.fill" }
        if ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "tif", "tiff"].contains(ext) { return "photo.fill" }
        if ["mp4", "mov", "m4v", "avi", "mkv"].contains(ext) { return "film.fill" }
        return "doc.fill"
    }

    private var previewAccent: Color {
        let ext = item.url.pathExtension.lowercased()
        if ["pdf"].contains(ext) { return MetrologyPalette.statusExpired }
        if ["xls", "xlsx", "csv", "numbers"].contains(ext) { return MetrologyPalette.statusValid }
        if ["ppt", "pptx", "key"].contains(ext) { return MetrologyPalette.statusWarning }
        if ["jpg", "jpeg", "png", "gif", "webp", "bmp", "heic", "tif", "tiff"].contains(ext) { return MetrologyPalette.statusValid }
        return MetrologyPalette.navActive
    }
}

private struct FilesActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
