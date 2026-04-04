import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @StateObject private var viewModel = FilesViewModel()
    @State private var fileImporterOpen = false
    @State private var createFolderDialogOpen = false
    @State private var createFolderName = ""

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
                .padding(14)
                .padding(.bottom, 14)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle("我的文件")
        .task {
            await viewModel.load()
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
                ProgressView(viewModel.isUploading ? "正在上传..." : "处理中...")
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
            HStack {
                Text("路径")
                    .foregroundStyle(MetrologyPalette.textSecondary)
                Spacer()
                Text(viewModel.currentPath)
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .lineLimit(1)
            }

            if !viewModel.hint.isEmpty {
                Text(viewModel.hint)
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

    private func fileRow(item: UserFileItemDto) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.isFolder ? "folder.fill" : "doc.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(item.isFolder ? MetrologyPalette.navActive : MetrologyPalette.textMuted)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(MetrologyPalette.surface)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .lineLimit(1)
                Text(item.createdAt ?? "")
                    .font(.caption2)
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: item.isFolder ? "chevron.right" : "arrow.down.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(MetrologyPalette.textMuted)
        }
        .padding(12)
        .metrologyCard()
    }

    private var fileRows: [FileListRow] {
        var duplicated: [String: Int] = [:]
        return viewModel.items.map { item in
            let base = baseFileRowID(item)
            let count = duplicated[base, default: 0]
            duplicated[base] = count + 1
            let id = count == 0 ? base : "\(base)#\(count)"
            return FileListRow(id: id, item: item)
        }
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
