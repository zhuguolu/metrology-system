import SwiftUI

struct FilesView: View {
    @StateObject private var viewModel = FilesViewModel()

    var body: some View {
        List {
            Section {
                HStack {
                    Text("路径")
                    Spacer()
                    Text(viewModel.currentPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !viewModel.hint.isEmpty {
                    Text(viewModel.hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("文件列表") {
                ForEach(fileRows) { row in
                    Button {
                        Task { await viewModel.open(row.item) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: row.item.isFolder ? "folder.fill" : "doc.fill")
                                .foregroundStyle(row.item.isFolder ? .blue : .gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.item.displayName)
                                    .foregroundStyle(.primary)
                                Text(row.item.createdAt ?? "")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("我的文件")
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("根目录") {
                    Task { await viewModel.goRoot() }
                }
                Button("上级") {
                    Task { await viewModel.goBack() }
                }
                Button("刷新") {
                    Task { await viewModel.load() }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("处理中...")
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
