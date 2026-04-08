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
    private var unauthorizedRecheckTask: Task<Void, Never>?

    var isAuthenticated: Bool {
        session != nil
    }

    init() {
        APIClient.shared.unauthorizedHandler = { [weak self] in
            self?.handleUnauthorizedSignal()
        }
        session = SessionStore.load()
        setAPIToken(session?.token)
        triggerSessionValidationIfNeeded()
        triggerIncomingImportTargetSelection()
    }

    func applyLogin(_ response: LoginResponse) {
        guard let token = response.token, !token.isEmpty else { return }
        let username = response.username?.isEmpty == false ? response.username! : "User"
        let departmentValues = normalizedDepartments(from: response)

        let value = Session(
            token: token,
            username: username,
            role: response.role,
            departments: departmentValues
        )
        session = value
        SessionStore.save(value)
        setAPIToken(value.token)
        triggerSessionValidationIfNeeded()
        triggerIncomingImportTargetSelection()
    }

    func logout() {
        unauthorizedRecheckTask?.cancel()
        unauthorizedRecheckTask = nil
        session = nil
        SessionStore.clear()
        setAPIToken(nil)
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
                _ = try await APIClient.shared.uploadFile(
                    parentId: targetFolderId,
                    fileName: pending.fileName,
                    mimeType: pending.mimeType,
                    fileURL: pending.localURL
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

    private func removeLocalIncomingFileIfExists(_ url: URL) {
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            // Ignore cleanup errors to avoid interrupting user flow.
        }
    }

    private func setAPIToken(_ token: String?) {
        APIClient.shared.tokenProvider = { token }
    }

    private func triggerSessionValidationIfNeeded() {
        guard session != nil else { return }
        Task { [weak self] in
            await self?.validateSessionFromServer()
        }
    }

    private func validateSessionFromServer() async {
        guard let currentSession = session else { return }

        do {
            let profile = try await APIClient.shared.me(notifyUnauthorized: false)
            let latestUsername = profile.username?.trimmingCharacters(in: .whitespacesAndNewlines)
            let nextUsername = (latestUsername?.isEmpty == false) ? latestUsername! : currentSession.username

            let refreshed = Session(
                token: currentSession.token,
                username: nextUsername,
                role: profile.role ?? currentSession.role,
                departments: normalizedDepartments(from: profile) ?? currentSession.departments
            )
            session = refreshed
            SessionStore.save(refreshed)
            setAPIToken(refreshed.token)
        } catch {
            if error is CancellationError {
                return
            }
            if let apiError = error as? APIError, case .unauthorized = apiError {
                handleUnauthorizedSessionExpiry()
            }
        }
    }

    private func normalizedDepartments(from response: LoginResponse) -> [String]? {
        let fromList = (response.departments ?? [])
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !fromList.isEmpty { return fromList }

        if let single = response.department?.trimmingCharacters(in: .whitespacesAndNewlines),
           !single.isEmpty {
            return [single]
        }
        return nil
    }

    private func handleUnauthorizedSessionExpiry() {
        guard session != nil else { return }
        logout()
        incomingImportNotice = AppNotice(
            title: "登录状态已失效",
            message: "登录状态已过期，请重新登录后继续操作。"
        )
    }

    private func handleUnauthorizedSignal() {
        guard session != nil else { return }
        guard unauthorizedRecheckTask == nil else { return }

        unauthorizedRecheckTask = Task { [weak self] in
            guard let self else { return }
            defer { self.unauthorizedRecheckTask = nil }

            do {
                _ = try await APIClient.shared.me(notifyUnauthorized: false)
            } catch {
                if error is CancellationError {
                    return
                }
                if let apiError = error as? APIError, case .unauthorized = apiError {
                    self.handleUnauthorizedSessionExpiry()
                }
            }
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
        try copyFileByStreaming(from: sourceURL, to: targetURL)
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

private func copyFileByStreaming(from sourceURL: URL, to targetURL: URL) throws {
    FileManager.default.createFile(atPath: targetURL.path, contents: nil)
    let input = try FileHandle(forReadingFrom: sourceURL)
    let output = try FileHandle(forWritingTo: targetURL)
    do {
        defer {
            try? input.close()
            try? output.close()
        }
        while true {
            let chunk = try input.read(upToCount: 64 * 1024) ?? Data()
            if chunk.isEmpty {
                break
            }
            try output.write(contentsOf: chunk)
        }
    } catch {
        try? FileManager.default.removeItem(at: targetURL)
        throw error
    }
}

