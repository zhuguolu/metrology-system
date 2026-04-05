import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @StateObject private var viewModel = FilesViewModel()
    @State private var fileImporterOpen = false
    @State private var createFolderDialogOpen = false
    @State private var createFolderName = ""
    @State private var searchText = ""

    var body: some View {
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
                            Button {
                                Task { await viewModel.open(row.item) }
                            } label: {
                                fileRow(item: row.item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(backToParentGesture, including: .subviews)
        }
        .navigationTitle("我的文件")
        .task {
            await viewModel.load()
        }
        .onDisappear {
            viewModel.cancelPreviewLoading()
        }
        .onChange(of: viewModel.currentFolderId) { _, _ in
            searchText = ""
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
                ProgressView(loadingOverlayTitle)
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
        }
        .sheet(item: $viewModel.previewItem, onDismiss: {
            viewModel.handlePreviewDismiss()
        }) { item in
            NavigationStack {
                QuickLookPreview(url: item.url)
                    .navigationTitle(item.title)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    private var headerPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            searchField
            HStack {
                Text("路径")
                    .foregroundStyle(MetrologyPalette.textSecondary)
                Spacer()
                Text(viewModel.currentPath)
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .lineLimit(1)
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
                Button("根目录") {
                    Task { await viewModel.goRoot() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())

                Button("上级") {
                    Task { await viewModel.goBack() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())
                .disabled(viewModel.currentFolderId == nil)
                .opacity(viewModel.currentFolderId == nil ? 0.45 : 1)

                Button("刷新") {
                    Task { await viewModel.load() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())
            }

            HStack(spacing: 8) {
                Button("上传文件") {
                    fileImporterOpen = true
                }
                .buttonStyle(MetrologyPrimaryButtonStyle())
                .disabled(!viewModel.canWrite)
                .opacity(viewModel.canWrite ? 1 : 0.45)

                Button("新建文件夹") {
                    createFolderName = ""
                    createFolderDialogOpen = true
                }
                .buttonStyle(MetrologySecondaryButtonStyle())
                .disabled(!viewModel.canWrite)
                .opacity(viewModel.canWrite ? 1 : 0.45)

                Button("扫描同步") {
                    Task { await viewModel.scanSync() }
                }
                .buttonStyle(MetrologySecondaryButtonStyle())
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
            if !item.isFolder, viewModel.previewLoadingFileId == item.id {
                ProgressView()
                    .controlSize(.small)
                    .tint(MetrologyPalette.navActive)
            } else {
                Image(systemName: item.isFolder ? "chevron.right" : "arrow.down.circle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(MetrologyPalette.textMuted)
            }
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

    private var loadingOverlayTitle: String {
        if viewModel.isUploading {
            return "正在上传..."
        }
        if viewModel.previewLoadingFileId != nil {
            return "正在加载预览..."
        }
        return "处理中..."
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
