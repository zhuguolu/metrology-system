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
    @Published var previewLoadingFileId: Int64?
    @Published var canWrite: Bool = true
    @Published var readOnlyFolder: Bool = false

    private struct FolderStackEntry {
        let id: Int64?
        let name: String
    }

    private struct FolderSnapshot {
        let items: [UserFileItemDto]
        let access: FileAccessDto?
        let cachedAt: Date
    }

    private let rootFolder = FolderStackEntry(id: nil, name: "")
    private var folderStack: [FolderStackEntry] = [FolderStackEntry(id: nil, name: "")]
    private var currentLoadToken: UInt64 = 0
    private var activeLoadTask: Task<Void, Never>?
    private var currentPreviewToken: UInt64 = 0
    private var activePreviewTask: Task<Void, Never>?
    private var folderCache: [String: FolderSnapshot] = [:]
    private let folderCacheTTL: TimeInterval = 20
    private var currentPreviewURL: URL?
    private var previewCache: [String: URL] = [:]
    private var previewCacheOrder: [String] = []
    private let previewCacheLimit: Int = 40

    struct MoveTarget: Identifiable, Equatable {
        let id: String
        let folderId: Int64?
        let title: String
    }

    func load() async {
        activeLoadTask?.cancel()
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performLoad()
        }
        activeLoadTask = task
        await task.value
    }

    private func performLoad() async {
        let token = beginLoad()
        defer {
            if shouldApplyResult(for: token) {
                isLoading = false
            }
        }

        let folderKey = folderCacheKey(folderId: currentFolderId)
        if let cached = folderCache[folderKey],
           Date().timeIntervalSince(cached.cachedAt) <= folderCacheTTL {
            items = cached.items
            applyAccess(cached.access)
            hint = "共 \(items.count) 项" + (readOnlyFolder ? "（只读目录）" : "")
        }

        do {
            let result = try await APIClient.shared.files(parentId: currentFolderId)
            guard shouldApplyResult(for: token) else { return }

            items = result.items ?? []
            applyAccess(result.access)
            hint = "共 \(items.count) 项" + (readOnlyFolder ? "（只读目录）" : "")
            folderCache[folderKey] = FolderSnapshot(
                items: items,
                access: result.access,
                cachedAt: Date()
            )
        } catch {
            guard shouldApplyResult(for: token) else { return }
            if error is CancellationError {
                return
            }
            errorMessage = localizedMessage(from: error)
        }
    }

    func goRoot() async {
        resetToRoot()
        await load()
    }

    func goBack() async {
        guard folderStack.count > 1 else { return }
        _ = folderStack.popLast()
        applyFolderStackState()
        await load()
    }

    func open(_ item: UserFileItemDto) async {
        if item.isFolder {
            cancelActivePreviewDownload(resetLoading: false)
            guard let folderId = item.id else {
                errorMessage = "目录ID无效"
                return
            }
            pushFolder(id: folderId, name: item.displayName)
            await load()
            return
        }

        guard let id = item.id else {
            previewLoadingFileId = nil
            errorMessage = "文件ID无效"
            return
        }

        let cacheKey = previewCacheKey(fileId: id, item: item)
        if let cachedURL = cachedPreviewURL(for: cacheKey) {
            cancelActivePreviewDownload(resetLoading: false)
            currentPreviewURL = cachedURL
            previewLoadingFileId = nil
            previewItem = PreviewItem(url: cachedURL, title: item.displayName)
            return
        }

        cancelActivePreviewDownload(resetLoading: false)
        previewLoadingFileId = id
        let token = beginPreviewLoad()
        let fileName = item.name
        let title = item.displayName
        let task = Task { [weak self] in
            guard let self else { return }
            defer {
                if self.shouldApplyPreviewResult(for: token) {
                    self.isLoading = false
                    self.activePreviewTask = nil
                    self.previewLoadingFileId = nil
                }
            }

            do {
                let url = try await APIClient.shared.downloadFile(id: id, suggestedName: fileName)
                guard self.shouldApplyPreviewResult(for: token) else { return }
                self.storePreviewURL(url, for: cacheKey)
                self.currentPreviewURL = url
                self.previewItem = PreviewItem(url: url, title: title)
            } catch {
                guard self.shouldApplyPreviewResult(for: token) else { return }
                if error is CancellationError {
                    return
                }
                self.errorMessage = self.localizedMessage(from: error)
            }
        }
        activePreviewTask = task
        await task.value
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
            invalidateFolderCache()
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
        invalidateFolderCache()
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
            invalidateFolderCache()
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
        cancelActivePreviewDownload(resetLoading: true)
        currentPreviewURL = nil
    }

    func cancelPreviewLoading() {
        cancelActivePreviewDownload(resetLoading: true)
    }

    func fetchMoveTargets() async -> [MoveTarget] {
        do {
            let folders = try await APIClient.shared.grantableFolders()
            var targets: [MoveTarget] = [
                MoveTarget(id: "root", folderId: nil, title: "/")
            ]
            targets.append(
                contentsOf: folders.compactMap { folder in
                    guard let id = folder.id else { return nil }
                    return MoveTarget(
                        id: "folder-\(id)",
                        folderId: id,
                        title: folder.displayName
                    )
                }
            )
            return targets
        } catch {
            if !(error is CancellationError) {
                errorMessage = localizedMessage(from: error)
            }
            return []
        }
    }

    func moveItems(_ ids: [Int64], to parentId: Int64?) async {
        guard !ids.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var successCount = 0
        var failCount = 0

        for id in ids {
            do {
                _ = try await APIClient.shared.moveFile(id: id, parentId: parentId)
                successCount += 1
            } catch {
                if error is CancellationError {
                    return
                }
                failCount += 1
            }
        }

        scanSyncMessage = "移动完成：成功 \(successCount)，失败 \(failCount)"
        invalidateFolderCache()
        await load()
    }

    func deleteItems(_ ids: [Int64]) async {
        guard !ids.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var successCount = 0
        var failCount = 0

        for id in ids {
            do {
                try await APIClient.shared.deleteFile(id: id)
                successCount += 1
            } catch {
                if error is CancellationError {
                    return
                }
                failCount += 1
            }
        }

        scanSyncMessage = "删除完成：成功 \(successCount)，失败 \(failCount)"
        invalidateFolderCache()
        await load()
    }

    func renameItem(id: Int64, newName: String) async -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "名称不能为空"
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await APIClient.shared.renameFile(id: id, name: trimmed)
            scanSyncMessage = "重命名成功"
            invalidateFolderCache()
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

    func prepareDownloads(for items: [UserFileItemDto]) async -> [URL] {
        guard !items.isEmpty else { return [] }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var urls: [URL] = []
        var skippedFolders = 0
        var failed = 0

        for item in items {
            if item.isFolder {
                skippedFolders += 1
                continue
            }
            guard let id = item.id else {
                failed += 1
                continue
            }
            do {
                let url = try await APIClient.shared.downloadFile(id: id, suggestedName: item.name)
                urls.append(url)
            } catch {
                if error is CancellationError {
                    return urls
                }
                failed += 1
            }
        }

        if skippedFolders > 0 || failed > 0 {
            scanSyncMessage = "下载准备完成：成功 \(urls.count)，文件夹跳过 \(skippedFolders)，失败 \(failed)"
        }
        return urls
    }

    func copyItemsToCurrentFolder(_ items: [UserFileItemDto]) async {
        guard !items.isEmpty else { return }
        guard canWrite else {
            errorMessage = "当前目录为只读，不能复制"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var successCount = 0
        var failedCount = 0
        var skippedFolders = 0
        var usedNames = Set(self.items.map { $0.displayName.lowercased() })

        for item in items {
            if item.isFolder {
                skippedFolders += 1
                continue
            }
            guard let id = item.id else {
                failedCount += 1
                continue
            }
            do {
                let sourceURL = try await APIClient.shared.downloadFile(id: id, suggestedName: item.name)
                let data = try Data(contentsOf: sourceURL)
                let copiedName = makeCopyName(from: item.displayName, usedNames: &usedNames)
                _ = try await APIClient.shared.uploadFile(
                    parentId: currentFolderId,
                    fileName: copiedName,
                    mimeType: item.mimeType,
                    bytes: data
                )
                successCount += 1
            } catch {
                if error is CancellationError {
                    return
                }
                failedCount += 1
            }
        }

        scanSyncMessage = "复制完成：成功 \(successCount)，文件夹跳过 \(skippedFolders)，失败 \(failedCount)"
        invalidateFolderCache()
        await load()
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

    private func beginPreviewLoad() -> UInt64 {
        currentPreviewToken += 1
        let token = currentPreviewToken
        isLoading = true
        errorMessage = nil
        return token
    }

    private func shouldApplyPreviewResult(for token: UInt64) -> Bool {
        token == currentPreviewToken && !Task.isCancelled
    }

    private func cancelActivePreviewDownload(resetLoading: Bool) {
        currentPreviewToken += 1
        activePreviewTask?.cancel()
        activePreviewTask = nil
        previewLoadingFileId = nil
        if resetLoading {
            isLoading = false
        }
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

    private func makeCopyName(from originalName: String, usedNames: inout Set<String>) -> String {
        let trimmed = originalName.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeOriginal = trimmed.isEmpty ? "未命名" : trimmed
        let nsName = safeOriginal as NSString
        let ext = nsName.pathExtension
        let base = nsName.deletingPathExtension
        let baseWithCopy = base.isEmpty ? "未命名-副本" : "\(base)-副本"

        var candidate = ext.isEmpty ? baseWithCopy : "\(baseWithCopy).\(ext)"
        var idx = 2
        while usedNames.contains(candidate.lowercased()) {
            let indexed = "\(baseWithCopy)\(idx)"
            candidate = ext.isEmpty ? indexed : "\(indexed).\(ext)"
            idx += 1
        }
        usedNames.insert(candidate.lowercased())
        return candidate
    }

    private func localizedMessage(from error: Error) -> String {
        (error as? APIError)?.localizedDescription ?? error.localizedDescription
    }

    private func resetToRoot() {
        folderStack = [rootFolder]
        applyFolderStackState()
    }

    private func pushFolder(id: Int64, name: String) {
        folderStack.append(FolderStackEntry(id: id, name: normalizeFolderName(name)))
        applyFolderStackState()
    }

    private func applyFolderStackState() {
        currentFolderId = folderStack.last?.id
        if folderStack.count <= 1 {
            currentPath = "/"
            return
        }
        let names = folderStack
            .dropFirst()
            .map { normalizeFolderName($0.name) }
            .filter { !$0.isEmpty }
        currentPath = names.isEmpty ? "/" : "/" + names.joined(separator: "/")
    }

    private func normalizeFolderName(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "-" : trimmed
    }

    private func folderCacheKey(folderId: Int64?) -> String {
        folderId.map(String.init) ?? "root"
    }

    private func invalidateFolderCache() {
        folderCache.removeAll(keepingCapacity: true)
    }

    private func previewCacheKey(fileId: Int64, item: UserFileItemDto) -> String {
        "\(fileId)|\(item.createdAt ?? "")|\(item.fileSize ?? -1)"
    }

    private func cachedPreviewURL(for key: String) -> URL? {
        guard let url = previewCache[key] else { return nil }
        if FileManager.default.fileExists(atPath: url.path) {
            touchPreviewCacheKey(key)
            return url
        }
        removePreviewCacheEntry(for: key, removeFile: false)
        return nil
    }

    private func storePreviewURL(_ url: URL, for key: String) {
        if let existing = previewCache[key], existing != url {
            removeFileIfExists(existing)
        }
        previewCache[key] = url
        touchPreviewCacheKey(key)
        trimPreviewCacheIfNeeded()
    }

    private func touchPreviewCacheKey(_ key: String) {
        previewCacheOrder.removeAll { $0 == key }
        previewCacheOrder.append(key)
    }

    private func trimPreviewCacheIfNeeded() {
        while previewCacheOrder.count > previewCacheLimit {
            let evictKey = previewCacheOrder.removeFirst()
            guard let url = previewCache[evictKey] else { continue }
            if url == currentPreviewURL {
                previewCacheOrder.append(evictKey)
                continue
            }
            removePreviewCacheEntry(for: evictKey, removeFile: true)
        }
    }

    private func removePreviewCacheEntry(for key: String, removeFile: Bool) {
        previewCacheOrder.removeAll { $0 == key }
        guard let url = previewCache.removeValue(forKey: key) else { return }
        if removeFile {
            removeFileIfExists(url)
        }
    }

    private func removeFileIfExists(_ url: URL) {
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
