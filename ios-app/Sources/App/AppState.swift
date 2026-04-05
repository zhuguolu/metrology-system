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

private enum IncomingFileImportError: LocalizedError {
    case invalidURL
    case folderUnsupported

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无法识别外部文件地址"
        case .folderUnsupported:
            return "暂不支持导入文件夹，请选择具体文件"
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
        triggerIncomingImportTargetSelection()
    }

    func applyLogin(_ response: LoginResponse) {
        guard let token = response.token, !token.isEmpty else { return }
        let username = response.username?.isEmpty == false ? response.username! : "未命名用户"
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
            title: "文件待导入",
            message: "已暂存 \(pendingImportedFiles.count) 个文件，再次从微信/文件App打开到本应用时会重新弹出目录选择。"
        )
    }

    private func stageIncomingFileAndImport(_ sourceURL: URL) async {
        do {
            let staged = try await Task.detached(priority: .userInitiated) {
                try stageIncomingExternalFile(from: sourceURL)
            }.value
            pendingImportedFiles.append(staged)
        } catch {
            incomingImportNotice = AppNotice(
                title: "文件导入失败",
                message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            )
            return
        }

        guard isAuthenticated else {
            incomingImportNotice = AppNotice(
                title: "已接收外部文件",
                message: "文件已加入待导入队列，登录后会先让你选择目录，再自动导入。"
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
                title: "目录加载失败",
                message: "目录列表获取失败，你仍可先导入到根目录。"
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
                title: "文件导入成功",
                message: "已导入 \(successCount) 个文件到 \(targetTitle)。"
            )
        } else if successCount > 0 && failedCount > 0 {
            incomingImportNotice = AppNotice(
                title: "文件部分导入成功",
                message: "成功 \(successCount) 个，失败 \(failedCount) 个。失败项会保留并在下次导入时继续处理。"
            )
        } else if successCount == 0 && failedCount > 0 {
            incomingImportNotice = AppNotice(
                title: "文件导入失败",
                message: "导入未成功，文件已保留，后续可再次选择目录导入。"
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
