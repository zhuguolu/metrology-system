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
    @Published private(set) var batchProgressTitle: String?
    @Published private(set) var batchProgressCurrent: Int = 0
    @Published private(set) var batchProgressTotal: Int = 0

    private struct FolderStackEntry {
        let id: Int64?
        let name: String
    }

    private struct FolderSnapshot {
        let items: [UserFileItemDto]
        let access: FileAccessDto?
        let cachedAt: Date
    }

    private struct FileMetadataSnapshot {
        let metadata: FileMetadataDto
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
    private var fileMetadataCache: [Int64: FileMetadataSnapshot] = [:]
    private let fileMetadataCacheTTL: TimeInterval = 15
    private var currentPreviewURL: URL?
    private var previewCache: [String: URL] = [:]
    private var previewCacheOrder: [String] = []
    private let previewCacheLimit: Int = 40

    struct MoveTarget: Identifiable, Equatable {
        let id: String
        let folderId: Int64?
        let title: String
    }

    var batchProgressText: String? {
        guard let batchProgressTitle, batchProgressTotal > 0 else { return nil }
        return "\(batchProgressTitle) \(batchProgressCurrent)/\(batchProgressTotal)"
    }

    var batchProgressFraction: Double? {
        guard batchProgressTotal > 0 else { return nil }
        return min(1.0, max(0, Double(batchProgressCurrent) / Double(batchProgressTotal)))
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
            hint = folderHint(for: items.count)
        }

        do {
            let result = try await APIClient.shared.files(parentId: currentFolderId)
            guard shouldApplyResult(for: token) else { return }

            items = result.items ?? []
            applyAccess(result.access)
            hint = folderHint(for: items.count)
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
                errorMessage = "目录标识无效，请刷新后重试。"
                return
            }
            pushFolder(id: folderId, name: item.displayName)
            await load()
            return
        }

        guard let id = item.id else {
            previewLoadingFileId = nil
            errorMessage = "文件标识无效，请刷新后重试。"
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
                let metadata = try await self.fileMetadata(id: id)
                if let previewMessage = metadata.previewMessage?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !previewMessage.isEmpty {
                    self.hint = previewMessage
                }
                let cacheKey = self.previewCacheKey(fileId: id, item: item, metadata: metadata)
                if let cachedURL = self.cachedPreviewURL(for: cacheKey) {
                    guard self.shouldApplyPreviewResult(for: token) else { return }
                    self.currentPreviewURL = cachedURL
                    self.previewItem = PreviewItem(url: cachedURL, title: title)
                    return
                }

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
            errorMessage = "文件夹名称不能为空。"
            return false
        }
        guard canWrite else {
            errorMessage = "当前目录为只读，无法新建文件夹。"
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await APIClient.shared.createFolder(name: trimmed, parentId: currentFolderId)
            scanSyncMessage = "文件夹创建成功。"
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
            errorMessage = "当前目录为只读，无法上传文件。"
            return
        }

        isLoading = true
        isUploading = true
        errorMessage = nil
        beginBatchProgress(title: "上传中", total: urls.count)
        defer {
            clearBatchProgress()
            isUploading = false
            isLoading = false
        }

        var successCount = 0
        var failCount = 0
        let folderId = currentFolderId

        var uploadRequests: [UploadPayload] = []
        uploadRequests.reserveCapacity(urls.count)
        for url in urls {
            guard let payload = resolveUploadMetadata(from: url) else {
                failCount += 1
                self.advanceBatchProgress()
                continue
            }
            uploadRequests.append(payload)
        }

        await runBoundedTasks(
            inputs: uploadRequests,
            maxConcurrent: 2,
            taskFactory: { payload in
                Task.detached(priority: .userInitiated) {
                    let accessing = payload.fileURL.startAccessingSecurityScopedResource()
                    defer {
                        if accessing {
                            payload.fileURL.stopAccessingSecurityScopedResource()
                        }
                    }
                    do {
                        _ = try await APIClient.shared.uploadFile(
                            parentId: folderId,
                            fileName: payload.name,
                            mimeType: payload.mimeType,
                            fileURL: payload.fileURL
                        )
                        return true
                    } catch {
                        return false
                    }
                }
            },
            onResult: { succeeded in
                if succeeded {
                    successCount += 1
                } else {
                    failCount += 1
                }
                self.advanceBatchProgress()
            }
        )

        scanSyncMessage = "上传完成：成功 \(successCount) 项，失败 \(failCount) 项。"
        invalidateFolderCache()
        await load()
    }

    func scanSync() async {
        guard canWrite else {
            errorMessage = "当前目录为只读，无法执行同步。"
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
            scanSyncMessage = "同步失败了，你可以继续浏览当前目录，稍后再试。"
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
        beginBatchProgress(title: "移动中", total: ids.count)
        defer {
            clearBatchProgress()
            isLoading = false
        }

        var successCount = 0
        var failCount = 0

        await runBoundedTasks(
            inputs: ids,
            maxConcurrent: 3,
            taskFactory: { id in
                Task.detached(priority: .userInitiated) {
                    do {
                        _ = try await APIClient.shared.moveFile(id: id, parentId: parentId)
                        return true
                    } catch {
                        return false
                    }
                }
            },
            onResult: { succeeded in
                if succeeded {
                    successCount += 1
                } else {
                    failCount += 1
                }
                self.advanceBatchProgress()
            }
        )

        scanSyncMessage = "移动完成：成功 \(successCount) 项，失败 \(failCount) 项。"
        invalidateFolderCache()
        await load()
    }

    func deleteItems(_ ids: [Int64]) async {
        guard !ids.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        beginBatchProgress(title: "删除中", total: ids.count)
        defer {
            clearBatchProgress()
            isLoading = false
        }

        var successCount = 0
        var failCount = 0

        await runBoundedTasks(
            inputs: ids,
            maxConcurrent: 3,
            taskFactory: { id in
                Task.detached(priority: .userInitiated) {
                    do {
                        try await APIClient.shared.deleteFile(id: id)
                        return true
                    } catch {
                        return false
                    }
                }
            },
            onResult: { succeeded in
                if succeeded {
                    successCount += 1
                } else {
                    failCount += 1
                }
                self.advanceBatchProgress()
            }
        )

        scanSyncMessage = "删除完成：成功 \(successCount) 项，失败 \(failCount) 项。"
        invalidateFolderCache()
        await load()
    }

    func renameItem(id: Int64, newName: String) async -> Bool {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "名称不能为空。"
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            _ = try await APIClient.shared.renameFile(id: id, name: trimmed)
            scanSyncMessage = "重命名成功。"
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
        beginBatchProgress(title: "准备下载", total: items.count)
        defer {
            clearBatchProgress()
            isLoading = false
        }

        struct DownloadRequest: Sendable {
            let id: Int64
            let suggestedName: String?
        }

        var urls: [URL] = []
        var skippedFolders = 0
        var failed = 0
        var requests: [DownloadRequest] = []

        for item in items {
            if item.isFolder {
                skippedFolders += 1
                self.advanceBatchProgress()
                continue
            }
            guard let id = item.id else {
                failed += 1
                self.advanceBatchProgress()
                continue
            }
            requests.append(DownloadRequest(id: id, suggestedName: item.name))
        }

        await runBoundedTasks(
            inputs: requests,
            maxConcurrent: 3,
            taskFactory: { request in
                Task.detached(priority: .userInitiated) {
                    try? await APIClient.shared.downloadFile(id: request.id, suggestedName: request.suggestedName)
                }
            },
            onResult: { url in
                if let url {
                    urls.append(url)
                } else {
                    failed += 1
                }
                self.advanceBatchProgress()
            }
        )

        scanSyncMessage = "下载准备完成：成功 \(urls.count) 项，跳过文件夹 \(skippedFolders) 项，失败 \(failed) 项。"
        return urls
    }

    func copyItemsToCurrentFolder(_ items: [UserFileItemDto]) async {
        guard !items.isEmpty else { return }
        guard canWrite else {
            errorMessage = "当前目录为只读，无法复制文件。"
            return
        }

        isLoading = true
        errorMessage = nil
        beginBatchProgress(title: "复制中", total: items.count)
        defer {
            clearBatchProgress()
            isLoading = false
        }

        struct CopyRequest: Sendable {
            let id: Int64
            let sourceName: String?
            let targetName: String
            let mimeType: String?
        }

        var successCount = 0
        var failedCount = 0
        var skippedFolders = 0
        var usedNames = Set(self.items.map { $0.displayName.lowercased() })
        var requests: [CopyRequest] = []

        for item in items {
            if item.isFolder {
                skippedFolders += 1
                self.advanceBatchProgress()
                continue
            }
            guard let id = item.id else {
                failedCount += 1
                advanceBatchProgress()
                continue
            }
            let copiedName = makeCopyName(from: item.displayName, usedNames: &usedNames)
            requests.append(CopyRequest(id: id, sourceName: item.name, targetName: copiedName, mimeType: item.mimeType))
        }

        let folderId = currentFolderId
        await runBoundedTasks(
            inputs: requests,
            maxConcurrent: 2,
            taskFactory: { request in
                Task.detached(priority: .userInitiated) {
                    do {
                        let sourceURL = try await APIClient.shared.downloadFile(
                            id: request.id,
                            suggestedName: request.sourceName
                        )
                        _ = try await APIClient.shared.uploadFile(
                            parentId: folderId,
                            fileName: request.targetName,
                            mimeType: request.mimeType,
                            fileURL: sourceURL
                        )
                        return true
                    } catch {
                        return false
                    }
                }
            },
            onResult: { succeeded in
                if succeeded {
                    successCount += 1
                } else {
                    failedCount += 1
                }
                self.advanceBatchProgress()
            }
        )

        scanSyncMessage = "复制完成：成功 \(successCount) 项，跳过文件夹 \(skippedFolders) 项，失败 \(failedCount) 项。"
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
        return "同步完成：新增文件夹 \(foldersCreated) 个，新增文件 \(filesCreated) 个，删除文件夹 \(foldersDeleted) 个，删除文件 \(filesDeleted) 个。"
    }

    private func folderHint(for count: Int) -> String {
        "共 \(count) 项" + (readOnlyFolder ? "（只读目录）" : "")
    }

    private func resolveUploadMetadata(from url: URL) -> UploadPayload? {
        do {
            let name = url.lastPathComponent.isEmpty
                ? "upload_\(Int(Date().timeIntervalSince1970)).bin"
                : url.lastPathComponent
            let mimeType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.preferredMIMEType
            return UploadPayload(name: name, mimeType: mimeType, fileURL: url)
        } catch {
            return nil
        }
    }

    private func beginBatchProgress(title: String, total: Int) {
        let clampedTotal = max(total, 0)
        batchProgressTitle = clampedTotal > 0 ? title : nil
        batchProgressTotal = clampedTotal
        batchProgressCurrent = 0
    }

    private func advanceBatchProgress() {
        guard batchProgressTotal > 0 else { return }
        batchProgressCurrent = min(batchProgressCurrent + 1, batchProgressTotal)
    }

    private func clearBatchProgress() {
        batchProgressTitle = nil
        batchProgressCurrent = 0
        batchProgressTotal = 0
    }

    private func runBoundedTasks<Input: Sendable, Output: Sendable>(
        inputs: [Input],
        maxConcurrent: Int,
        taskFactory: @escaping @Sendable (Input) -> Task<Output, Never>,
        onResult: @MainActor @escaping (Output) -> Void
    ) async {
        guard !inputs.isEmpty else { return }
        let workerLimit = max(1, maxConcurrent)

        await withTaskGroup(of: Output.self) { group in
            var nextIndex = 0
            let initialCount = min(workerLimit, inputs.count)

            for _ in 0..<initialCount {
                let input = inputs[nextIndex]
                nextIndex += 1
                group.addTask {
                    await taskFactory(input).value
                }
            }

            while let output = await group.next() {
                await onResult(output)
                if nextIndex < inputs.count {
                    let input = inputs[nextIndex]
                    nextIndex += 1
                    group.addTask {
                        await taskFactory(input).value
                    }
                }
            }
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
        if let apiError = error as? APIError {
            switch apiError {
            case .invalidURL:
                return "文件服务地址无效，请检查当前接口配置。"
            case .unauthorized:
                return "登录状态已失效，请重新登录后再访问文件。"
            case .forbidden(_):
                return "当前账号没有文件模块访问权限。"
            case let .serverMessage(message):
                let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? "文件服务暂时不可用，请稍后重试。" : trimmed
            case let .httpStatus(code, message, errorCode):
                if let message, !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return message
                }
                if let errorCode, !errorCode.isEmpty {
                    return "文件服务返回异常：\(errorCode)。"
                }
                return "文件服务请求失败（\(code)），请稍后重试。"
            case .decodingFailed:
                return "文件模块数据解析失败，请检查后端接口返回格式。"
            default:
                return apiError.localizedDescription ?? "文件服务暂时不可用，请稍后重试。"
            }
        }
        let fallback = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallback.isEmpty ? "文件服务暂时不可用，请稍后重试。" : fallback
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
        fileMetadataCache.removeAll(keepingCapacity: true)
    }

    private func fileMetadata(id: Int64) async throws -> FileMetadataDto {
        if let cached = fileMetadataCache[id],
           Date().timeIntervalSince(cached.cachedAt) <= fileMetadataCacheTTL {
            return cached.metadata
        }

        let metadata = try await APIClient.shared.fileMetadata(id: id)
        fileMetadataCache[id] = FileMetadataSnapshot(metadata: metadata, cachedAt: Date())
        return metadata
    }

    private func previewCacheKey(fileId: Int64, item: UserFileItemDto, metadata: FileMetadataDto?) -> String {
        "\(fileId)|\(metadata?.etag ?? "")|\(metadata?.lastModified ?? item.createdAt ?? "")|\(metadata?.fileSize ?? item.fileSize ?? -1)"
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

private struct UploadPayload: Sendable {
    let name: String
    let mimeType: String?
    let fileURL: URL
}

