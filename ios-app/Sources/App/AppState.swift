import Foundation
import Combine
import UniformTypeIdentifiers

struct Session: Codable {
    let token: String
    let username: String
    let role: String?
    let departments: [String]?
}

struct AppNotice: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

struct IncomingImportTarget: Identifiable, Hashable {
    let id: String
    let folderId: Int64?
    let title: String
}

struct IncomingImportPickerState: Identifiable {
    let id = UUID()
    let pendingCount: Int
    let targets: [IncomingImportTarget]
}

extension Notification.Name {
    static let metrologyExternalFilesImported = Notification.Name("metrologyExternalFilesImported")
}

private struct PendingImportedFile: Sendable {
    let localURL: URL
    let fileName: String
    let mimeType: String?
}

private struct ShareInboxRecord: Codable {
    let storedFileName: String
    let originalFileName: String
    let mimeType: String?
    let createdAt: TimeInterval?
}

private struct ShareInboxManifest: Codable {
    var items: [ShareInboxRecord] = []
}

private enum ShareBridgeConfig {
    static let appGroupIdentifier = "group.com.metrology.ios.share"
    static let inboxDirectoryName = "ShareInbox"
    static let manifestFileName = "manifest.json"
}

private enum IncomingFileImportError: LocalizedError {
    case invalidURL
    case folderUnsupported

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid external file URL"
        case .folderUnsupported:
            return "Folder import is not supported. Please select a file."
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published private(set) var session: Session?
    @Published var incomingImportNotice: AppNotice?
    @Published var incomingImportPicker: IncomingImportPickerState?

    private var pendingImportedFiles: [PendingImportedFile] = []
    private var isProcessingIncomingImports = false
    private var isPreparingIncomingImportTargets = false

    var isAuthenticated: Bool {
        session != nil
    }

    init() {
        session = SessionStore.load()
        APIClient.shared.tokenProvider = { SessionStore.load()?.token }
        drainShareExtensionInboxIntoPendingQueue()
        triggerIncomingImportTargetSelection()
    }

    func applyLogin(_ response: LoginResponse) {
        guard let token = response.token, !token.isEmpty else { return }
        let username = response.username?.isEmpty == false ? response.username! : "User"
        let departmentValues: [String]? = {
            let fromList = (response.departments ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !fromList.isEmpty { return fromList }
            if let single = response.department?.trimmingCharacters(in: .whitespacesAndNewlines), !single.isEmpty {
                return [single]
            }
            return nil
        }()

        let value = Session(
            token: token,
            username: username,
            role: response.role,
            departments: departmentValues
        )
        session = value
        SessionStore.save(value)
        APIClient.shared.tokenProvider = { SessionStore.load()?.token }

        drainShareExtensionInboxIntoPendingQueue()
        triggerIncomingImportTargetSelection()
    }

    func refreshIncomingSharedFiles() {
        drainShareExtensionInboxIntoPendingQueue()
        triggerIncomingImportTargetSelection()
    }

    func logout() {
        session = nil
        SessionStore.clear()
        APIClient.shared.tokenProvider = { nil }
        incomingImportPicker = nil
    }

    func clearIncomingImportNotice() {
        incomingImportNotice = nil
    }

    func handleIncomingFileURL(_ url: URL) {
        Task { [weak self] in
            await self?.stageIncomingFileAndImport(url)
        }
    }

    func selectIncomingImportTarget(_ target: IncomingImportTarget) {
        incomingImportPicker = nil
        triggerIncomingImportProcessing(targetFolderId: target.folderId, targetTitle: target.title)
    }

    func deferIncomingImportSelection() {
        incomingImportPicker = nil
        guard !pendingImportedFiles.isEmpty else { return }
        incomingImportNotice = AppNotice(
            title: "Files queued",
            message: "Queued \(pendingImportedFiles.count) item(s). Open-in again to pick target folder."
        )
    }

    private func drainShareExtensionInboxIntoPendingQueue() {
        let stagedFiles = loadPendingFilesFromShareExtensionInbox()
        guard !stagedFiles.isEmpty else { return }

        pendingImportedFiles.append(contentsOf: stagedFiles)

        if isAuthenticated {
            incomingImportNotice = AppNotice(
                title: "Shared files received",
                message: "Detected \(stagedFiles.count) shared item(s). Please choose target folder."
            )
        } else {
            incomingImportNotice = AppNotice(
                title: "Shared files queued",
                message: "Detected \(stagedFiles.count) shared item(s). Login first, then choose folder to import."
            )
        }
    }

    private func stageIncomingFileAndImport(_ sourceURL: URL) async {
        do {
            let staged = try await Task.detached(priority: .userInitiated) {
                try stageIncomingExternalFile(from: sourceURL)
            }.value
            pendingImportedFiles.append(staged)
        } catch {
            incomingImportNotice = AppNotice(
                title: "Import failed",
                message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
            return
        }

        guard isAuthenticated else {
            incomingImportNotice = AppNotice(
                title: "External file received",
                message: "File queued. Login first, then choose folder to import."
            )
            return
        }

        if let existing = incomingImportPicker {
            incomingImportPicker = IncomingImportPickerState(
                pendingCount: pendingImportedFiles.count,
                targets: existing.targets
            )
            return
        }

        triggerIncomingImportTargetSelection()
    }

    private func triggerIncomingImportTargetSelection() {
        guard isAuthenticated else { return }
        guard !pendingImportedFiles.isEmpty else { return }
        guard !isProcessingIncomingImports else { return }
        guard incomingImportPicker == nil else { return }
        guard !isPreparingIncomingImportTargets else { return }

        Task { [weak self] in
            await self?.prepareIncomingImportTargets()
        }
    }

    private func prepareIncomingImportTargets() async {
        guard isAuthenticated else { return }
        guard !pendingImportedFiles.isEmpty else { return }

        isPreparingIncomingImportTargets = true
        defer { isPreparingIncomingImportTargets = false }

        var targets: [IncomingImportTarget] = [
            IncomingImportTarget(id: "root", folderId: nil, title: "/")
        ]

        do {
            let folders = try await APIClient.shared.grantableFolders()
            var usedIds = Set<String>(["root"])
            for folder in folders {
                guard let id = folder.id else { continue }
                let key = "folder-\(id)"
                guard !usedIds.contains(key) else { continue }
                usedIds.insert(key)
                targets.append(
                    IncomingImportTarget(
                        id: key,
                        folderId: id,
                        title: folder.displayName
                    )
                )
            }
        } catch {
            incomingImportNotice = AppNotice(
                title: "Folder list failed",
                message: "Folder list load failed. You can still import to root folder."
            )
        }

        incomingImportPicker = IncomingImportPickerState(
            pendingCount: pendingImportedFiles.count,
            targets: targets
        )
    }

    private func triggerIncomingImportProcessing(targetFolderId: Int64?, targetTitle: String) {
        guard isAuthenticated else { return }
        guard !pendingImportedFiles.isEmpty else { return }
        guard !isProcessingIncomingImports else { return }

        Task { [weak self] in
            await self?.processIncomingImportQueue(targetFolderId: targetFolderId, targetTitle: targetTitle)
        }
    }

    private func processIncomingImportQueue(targetFolderId: Int64?, targetTitle: String) async {
        guard isAuthenticated else { return }
        guard !pendingImportedFiles.isEmpty else { return }
        guard !isProcessingIncomingImports else { return }

        isProcessingIncomingImports = true
        defer { isProcessingIncomingImports = false }

        let currentQueue = pendingImportedFiles
        pendingImportedFiles.removeAll()

        var successCount = 0
        var failedItems: [PendingImportedFile] = []

        for pending in currentQueue {
            do {
                let bytes = try await readIncomingFileBytes(from: pending.localURL)
                _ = try await APIClient.shared.uploadFile(
                    parentId: targetFolderId,
                    fileName: pending.fileName,
                    mimeType: pending.mimeType,
                    bytes: bytes
                )
                removeLocalIncomingFileIfExists(pending.localURL)
                successCount += 1
            } catch {
                failedItems.append(pending)
            }
        }

        if !failedItems.isEmpty {
            pendingImportedFiles.insert(contentsOf: failedItems, at: 0)
        }

        let failedCount = failedItems.count

        if successCount > 0 {
            NotificationCenter.default.post(name: .metrologyExternalFilesImported, object: nil)
        }

        if successCount > 0 && failedCount == 0 {
            incomingImportNotice = AppNotice(
                title: "Import success",
                message: "Imported \(successCount) item(s) to \(targetTitle)."
            )
        } else if successCount > 0 && failedCount > 0 {
            incomingImportNotice = AppNotice(
                title: "Partial import",
                message: "Success: \(successCount), failed: \(failedCount). Failed items stay queued."
            )
        } else if successCount == 0 && failedCount > 0 {
            incomingImportNotice = AppNotice(
                title: "Import failed",
                message: "No item imported. Files remain queued for retry."
            )
        }

        if !pendingImportedFiles.isEmpty {
            triggerIncomingImportTargetSelection()
        }
    }

    private func readIncomingFileBytes(from url: URL) async throws -> Data {
        try await Task.detached(priority: .utility) {
            try Data(contentsOf: url)
        }.value
    }

    private func removeLocalIncomingFileIfExists(_ url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            // Ignore cleanup errors to avoid interrupting user flow.
        }
    }
}

private func stageIncomingExternalFile(from sourceURL: URL) throws -> PendingImportedFile {
    guard sourceURL.isFileURL else {
        throw IncomingFileImportError.invalidURL
    }

    let isAccessingScopedResource = sourceURL.startAccessingSecurityScopedResource()
    defer {
        if isAccessingScopedResource {
            sourceURL.stopAccessingSecurityScopedResource()
        }
    }

    let resourceValues = try sourceURL.resourceValues(forKeys: [.isDirectoryKey, .contentTypeKey])
    if resourceValues.isDirectory == true {
        throw IncomingFileImportError.folderUnsupported
    }

    let stagingDirectory = try resolveIncomingImportStagingDirectory()
    let resolvedName = normalizedIncomingFileName(sourceURL.lastPathComponent)
    let targetURL = uniqueIncomingFileURL(in: stagingDirectory, preferredName: resolvedName)

    do {
        try FileManager.default.copyItem(at: sourceURL, to: targetURL)
    } catch {
        let bytes = try Data(contentsOf: sourceURL)
        try bytes.write(to: targetURL, options: .atomic)
    }

    return PendingImportedFile(
        localURL: targetURL,
        fileName: resolvedName,
        mimeType: resourceValues.contentType?.preferredMIMEType
    )
}

private func loadPendingFilesFromShareExtensionInbox() -> [PendingImportedFile] {
    guard let inboxDirectory = resolveShareInboxDirectory(createIfMissing: false) else {
        return []
    }

    let manifest = loadShareInboxManifest(in: inboxDirectory)
    let candidates = collectShareInboxCandidates(in: inboxDirectory, manifest: manifest)
    guard !candidates.isEmpty else {
        cleanupShareInbox(in: inboxDirectory)
        return []
    }

    var staged: [PendingImportedFile] = []
    for candidate in candidates {
        if let moved = moveShareInboxFileToLocalStaging(
            sourceURL: candidate.fileURL,
            originalFileName: candidate.originalFileName,
            mimeType: candidate.mimeType
        ) {
            staged.append(moved)
        }
    }

    cleanupShareInbox(in: inboxDirectory)
    return staged
}

private func resolveShareInboxDirectory(createIfMissing: Bool) -> URL? {
    guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ShareBridgeConfig.appGroupIdentifier) else {
        return nil
    }

    let inbox = container.appendingPathComponent(ShareBridgeConfig.inboxDirectoryName, isDirectory: true)
    if createIfMissing && !FileManager.default.fileExists(atPath: inbox.path) {
        try? FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
    }
    guard FileManager.default.fileExists(atPath: inbox.path) else {
        return nil
    }
    return inbox
}

private func loadShareInboxManifest(in inboxDirectory: URL) -> ShareInboxManifest? {
    let manifestURL = inboxDirectory.appendingPathComponent(ShareBridgeConfig.manifestFileName)
    guard let data = try? Data(contentsOf: manifestURL) else {
        return nil
    }
    return try? JSONDecoder().decode(ShareInboxManifest.self, from: data)
}

private func collectShareInboxCandidates(
    in inboxDirectory: URL,
    manifest: ShareInboxManifest?
) -> [(fileURL: URL, originalFileName: String, mimeType: String?)] {
    var result: [(URL, String, String?)] = []

    if let manifest {
        for item in manifest.items {
            let fileURL = inboxDirectory.appendingPathComponent(item.storedFileName)
            guard FileManager.default.fileExists(atPath: fileURL.path) else { continue }
            let name = normalizedIncomingFileName(item.originalFileName)
            result.append((fileURL, name, item.mimeType))
        }
    }

    if !result.isEmpty {
        return result
    }

    let allFiles = (try? FileManager.default.contentsOfDirectory(at: inboxDirectory, includingPropertiesForKeys: nil)) ?? []
    for fileURL in allFiles {
        guard fileURL.lastPathComponent != ShareBridgeConfig.manifestFileName else { continue }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            continue
        }

        let name = normalizedIncomingFileName(fileURL.lastPathComponent)
        let ext = (name as NSString).pathExtension
        let mime = ext.isEmpty ? nil : UTType(filenameExtension: ext)?.preferredMIMEType
        result.append((fileURL, name, mime))
    }

    return result
}

private func moveShareInboxFileToLocalStaging(
    sourceURL: URL,
    originalFileName: String,
    mimeType: String?
) -> PendingImportedFile? {
    let stagingDirectory: URL
    do {
        stagingDirectory = try resolveIncomingImportStagingDirectory()
    } catch {
        return nil
    }

    let targetURL = uniqueIncomingFileURL(in: stagingDirectory, preferredName: originalFileName)

    do {
        try FileManager.default.moveItem(at: sourceURL, to: targetURL)
    } catch {
        do {
            let data = try Data(contentsOf: sourceURL)
            try data.write(to: targetURL, options: .atomic)
            try? FileManager.default.removeItem(at: sourceURL)
        } catch {
            return nil
        }
    }

    return PendingImportedFile(
        localURL: targetURL,
        fileName: originalFileName,
        mimeType: mimeType
    )
}

private func cleanupShareInbox(in inboxDirectory: URL) {
    let manifestURL = inboxDirectory.appendingPathComponent(ShareBridgeConfig.manifestFileName)
    try? FileManager.default.removeItem(at: manifestURL)

    let leftovers = (try? FileManager.default.contentsOfDirectory(at: inboxDirectory, includingPropertiesForKeys: nil)) ?? []
    for url in leftovers {
        try? FileManager.default.removeItem(at: url)
    }
}

private func resolveIncomingImportStagingDirectory() throws -> URL {
    let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        ?? FileManager.default.temporaryDirectory
    let directory = base.appendingPathComponent("IncomingExternalImports", isDirectory: true)
    if !FileManager.default.fileExists(atPath: directory.path) {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    return directory
}

private func uniqueIncomingFileURL(in directory: URL, preferredName: String) -> URL {
    let sanitizedName = preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
    let fallbackName = sanitizedName.isEmpty ? "import_\(Int(Date().timeIntervalSince1970)).bin" : sanitizedName
    let name = fallbackName as NSString
    let ext = name.pathExtension
    let baseName = name.deletingPathExtension

    var index = 0
    while true {
        let candidateName: String
        if index == 0 {
            candidateName = fallbackName
        } else {
            let suffix = "\(baseName)_\(index)"
            candidateName = ext.isEmpty ? suffix : "\(suffix).\(ext)"
        }

        let candidateURL = directory.appendingPathComponent(candidateName)
        if !FileManager.default.fileExists(atPath: candidateURL.path) {
            return candidateURL
        }
        index += 1
    }
}

private func normalizedIncomingFileName(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if !trimmed.isEmpty {
        return trimmed
    }
    return "import_\(Int(Date().timeIntervalSince1970)).bin"
}
