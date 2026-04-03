import Foundation
import Combine

struct PreviewItem: Identifiable {
    let id = UUID()
    let url: URL
    let title: String
}

@MainActor
final class FilesViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hint: String = ""
    @Published var items: [UserFileItemDto] = []
    @Published var currentFolderId: Int64?
    @Published var currentPath: String = "/"
    @Published var previewItem: PreviewItem?

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
            hint = "共 \(items.count) 项"
        } catch {
            guard shouldApplyResult(for: token) else { return }
            if error is CancellationError {
                return
            }
            if let apiError = error as? APIError {
                errorMessage = apiError.localizedDescription
            } else {
                errorMessage = error.localizedDescription
            }
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
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
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
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
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
