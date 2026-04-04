import Foundation
import Combine
import UniformTypeIdentifiers

struct PreviewItem: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

@MainActor
final class FilesViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var isUploading: Bool = false
    @Published var errorMessage: String?
    @Published var hint: String = ""
    @Published var scanSyncMessage: String?
    @Published var items: [UserFileItemDto] = []
    @Published var currentFolderId: Int64?
    @Published var currentPath: String = "/"
    @Published var previewItem: PreviewItem?
    @Published var canWrite: Bool = true
    @Published var readOnlyFolder: Bool = false

    private var currentLoadToken: UInt64 = 0
    private var currentPreviewURL: URL?
    private var cachedPreviewURLs: Set<URL> = []

    func load() async {
        let token = beginLoad()
        defer {
            if shouldApplyResult(for: token) {
                isLoading = false
            }
        }

        do {
            let result = try await APIClient.shared.files(parentId: currentFolderId)
            guard shouldApplyResult(for: token) else { return }

            items = result.items ?? []
            applyAccess(result.access)
            hint = "共 \(items.count) 项" + (readOnlyFolder ? "（只读目录）" : "")
        } catch {
            guard shouldApplyResult(for: token) else { return }
            if error is CancellationError {
                return
            }
            errorMessage = localizedMessage(from: error)
        }
    }

    func goRoot() async {
        currentFolderId = nil
        currentPath = "/"
        await load()
    }

    func goBack() async {
        guard let folderId = currentFolderId else { return }
        do {
            let crumbs = try await APIClient.shared.fileBreadcrumb(folderId: folderId)
            if crumbs.count >= 2 {
                let parent = crumbs[crumbs.count - 2]
                currentFolderId = parent.id
                let names = crumbs.dropLast().compactMap { $0.name }.filter { !$0.isEmpty }
                currentPath = names.isEmpty ? "/" : "/" + names.joined(separator: "/")
            } else {
                currentFolderId = nil
                currentPath = "/"
            }
            await load()
        } catch {
            errorMessage = localizedMessage(from: error)
        }
    }

    func open(_ item: UserFileItemDto) async {
        if item.isFolder {
            currentFolderId = item.id
            let name = item.displayName
            if currentPath == "/" {
                currentPath = "/\(name)"
            } else {
                currentPath += "/\(name)"
            }
            await load()
            return
        }

        guard let id = item.id else {
            errorMessage = "文件ID无效"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let url = try await APIClient.shared.downloadFile(id: id, suggestedName: item.name)
            registerPreviewTempFile(url)
            if let previous = currentPreviewURL, previous != url {
                removePreviewTempFile(previous)
            }
            currentPreviewURL = url
            previewItem = PreviewItem(url: url, title: item.displayName)
        } catch {
            errorMessage = localizedMessage(from: error)
        }
    }

    func createFolder(name: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "文件夹名称不能为空"
            return false
        }
        guard canWrite else {
            errorMessage = "当前目录为只读，不能新建文件夹"
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await APIClient.shared.createFolder(name: trimmed, parentId: currentFolderId)
            scanSyncMessage = "文件夹创建成功"
            await load()
            return true
        } catch {
            if error is CancellationError {
                return false
            }
            errorMessage = localizedMessage(from: error)
            return false
        }
    }

    func uploadFiles(urls: [URL]) async {
        guard !urls.isEmpty else { return }
        guard canWrite else {
            errorMessage = "当前目录为只读，不能上传文件"
            return
        }

        isLoading = true
        isUploading = true
        errorMessage = nil
        defer {
            isUploading = false
            isLoading = false
        }

        var successCount = 0
        var failCount = 0

        for url in urls {
            guard let payload = resolveUploadPayload(from: url) else {
                failCount += 1
                continue
            }

            do {
                _ = try await APIClient.shared.uploadFile(
                    parentId: currentFolderId,
                    fileName: payload.name,
                    mimeType: payload.mimeType,
                    bytes: payload.bytes
                )
                successCount += 1
            } catch {
                if error is CancellationError {
                    return
                }
                failCount += 1
            }
        }

        scanSyncMessage = "上传完成：成功 \(successCount)，失败 \(failCount)"
        await load()
    }

    func scanSync() async {
        guard canWrite else {
            errorMessage = "当前目录为只读，不能扫描同步"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await APIClient.shared.scanSync(parentId: currentFolderId)
            scanSyncMessage = scanSyncSummary(from: result)
            await load()
        } catch {
            if error is CancellationError {
                return
            }
            errorMessage = localizedMessage(from: error)
            scanSyncMessage = "扫描同步失败，可继续浏览当前目录并稍后重试"
        }
    }

    func handlePreviewDismiss() {
        guard let url = currentPreviewURL else { return }
        currentPreviewURL = nil
        removePreviewTempFile(url)
    }

    private func beginLoad() -> UInt64 {
        currentLoadToken += 1
        let token = currentLoadToken
        isLoading = true
        errorMessage = nil
        return token
    }

    private func shouldApplyResult(for token: UInt64) -> Bool {
        token == currentLoadToken && !Task.isCancelled
    }

    private func applyAccess(_ access: FileAccessDto?) {
        guard let access else {
            readOnlyFolder = false
            canWrite = true
            return
        }
        readOnlyFolder = access.readOnly == true
        canWrite = (access.canWrite ?? false) && !readOnlyFolder
    }

    private func scanSyncSummary(from result: ScanSyncResultDto) -> String {
        let foldersCreated = result.foldersCreated ?? 0
        let filesCreated = result.filesCreated ?? 0
        let foldersDeleted = result.foldersDeleted ?? 0
        let filesDeleted = result.filesDeleted ?? 0
        return "扫描同步完成：新增目录 \(foldersCreated)，新增文件 \(filesCreated)，删除目录 \(foldersDeleted)，删除文件 \(filesDeleted)"
    }

    private func resolveUploadPayload(from url: URL) -> UploadPayload? {
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let name = url.lastPathComponent.isEmpty
                ? "upload_\(Int(Date().timeIntervalSince1970)).bin"
                : url.lastPathComponent
            let mimeType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.preferredMIMEType
            return UploadPayload(name: name, mimeType: mimeType, bytes: data)
        } catch {
            return nil
        }
    }

    private func localizedMessage(from error: Error) -> String {
        (error as? APIError)?.localizedDescription ?? error.localizedDescription
    }

    private func registerPreviewTempFile(_ url: URL) {
        cachedPreviewURLs.insert(url)
    }

    private func removePreviewTempFile(_ url: URL) {
        cachedPreviewURLs.remove(url)
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            // Ignore cleanup failures to avoid blocking user flow.
        }
    }
}

private struct UploadPayload {
    let name: String
    let mimeType: String?
    let bytes: Data
}
