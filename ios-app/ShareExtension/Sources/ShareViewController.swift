import Foundation
import Social
import UniformTypeIdentifiers
import UIKit

private enum ShareBridgeConfig {
    static let appGroupIdentifier = "group.com.metrology.ios.share"
    static let inboxDirectoryName = "ShareInbox"
    static let manifestFileName = "manifest.json"
    static let maxAttachmentCount = 30
}

private struct ShareInboxItemRecord: Codable {
    let storedFileName: String
    let originalFileName: String
    let mimeType: String?
    let createdAt: TimeInterval
}

private struct ShareInboxManifest: Codable {
    var items: [ShareInboxItemRecord] = []
}

private struct SharedPayload {
    let data: Data
    let fileName: String
    let mimeType: String?
}

final class ShareViewController: SLComposeServiceViewController {
    override func isContentValid() -> Bool {
        true
    }

    override func didSelectPost() {
        Task {
            do {
                _ = try await stageIncomingPayloads()
                extensionContext?.completeRequest(returningItems: nil)
            } catch {
                extensionContext?.cancelRequest(withError: error)
            }
        }
    }

    override func configurationItems() -> [Any]! {
        []
    }

    private func stageIncomingPayloads() async throws -> Int {
        let inboxDirectory = try resolveInboxDirectory()
        var manifest = loadManifest(from: inboxDirectory)
        var stagedCount = 0

        let inputItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
        let providers = inputItems.flatMap { $0.attachments ?? [] }
        let limitedProviders = providers.prefix(ShareBridgeConfig.maxAttachmentCount)

        for provider in limitedProviders {
            if let payload = try await resolvePayload(from: provider) {
                let record = try stagePayload(payload, in: inboxDirectory)
                manifest.items.append(record)
                stagedCount += 1
            }
        }

        let composedText = contentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !composedText.isEmpty {
            let textData = Data(composedText.utf8)
            let timestamp = Int(Date().timeIntervalSince1970)
            let payload = SharedPayload(
                data: textData,
                fileName: "shared_text_\(timestamp).txt",
                mimeType: UTType.plainText.preferredMIMEType
            )
            let record = try stagePayload(payload, in: inboxDirectory)
            manifest.items.append(record)
            stagedCount += 1
        }

        if stagedCount > 0 {
            try saveManifest(manifest, in: inboxDirectory)
        }

        return stagedCount
    }

    private func resolvePayload(from provider: NSItemProvider) async throws -> SharedPayload? {
        if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
           let sourceURL = try await loadURLItem(from: provider, typeIdentifier: UTType.fileURL.identifier) {
            let sourceName = sourceURL.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            let preferredName = provider.suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fileName = !sourceName.isEmpty ? sourceName : fallbackName(from: preferredName, defaultExt: nil)
            let mimeType = (try? sourceURL.resourceValues(forKeys: [.contentTypeKey]).contentType?.preferredMIMEType)
                ?? mimeTypeForFileName(fileName)
            let bytes = try Data(contentsOf: sourceURL)
            return SharedPayload(data: bytes, fileName: fileName, mimeType: mimeType)
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
           let data = try await loadDataRepresentation(from: provider, typeIdentifier: UTType.image.identifier) {
            let fileName = fallbackName(from: provider.suggestedName, defaultExt: "jpg")
            let mime = mimeTypeForFileName(fileName) ?? UTType.jpeg.preferredMIMEType
            return SharedPayload(data: data, fileName: fileName, mimeType: mime)
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.movie.identifier),
           let data = try await loadDataRepresentation(from: provider, typeIdentifier: UTType.movie.identifier) {
            let fileName = fallbackName(from: provider.suggestedName, defaultExt: "mp4")
            let mime = mimeTypeForFileName(fileName) ?? UTType.mpeg4Movie.preferredMIMEType
            return SharedPayload(data: data, fileName: fileName, mimeType: mime)
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier),
           let data = try await loadDataRepresentation(from: provider, typeIdentifier: UTType.audio.identifier) {
            let fileName = fallbackName(from: provider.suggestedName, defaultExt: "m4a")
            let mime = mimeTypeForFileName(fileName) ?? UTType.audio.preferredMIMEType
            return SharedPayload(data: data, fileName: fileName, mimeType: mime)
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier),
           let data = try await loadDataRepresentation(from: provider, typeIdentifier: UTType.data.identifier) {
            let fileName = fallbackName(from: provider.suggestedName, defaultExt: "bin")
            let mime = mimeTypeForFileName(fileName) ?? UTType.data.preferredMIMEType
            return SharedPayload(data: data, fileName: fileName, mimeType: mime)
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
           let text = try await loadStringItem(from: provider, typeIdentifier: UTType.plainText.identifier) {
            let fileName = fallbackName(from: provider.suggestedName, defaultExt: "txt")
            return SharedPayload(data: Data(text.utf8), fileName: fileName, mimeType: UTType.plainText.preferredMIMEType)
        }

        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
           let url = try await loadURLItem(from: provider, typeIdentifier: UTType.url.identifier) {
            let fileName = fallbackName(from: provider.suggestedName, defaultExt: "txt")
            let text = url.absoluteString
            return SharedPayload(data: Data(text.utf8), fileName: fileName, mimeType: UTType.plainText.preferredMIMEType)
        }

        return nil
    }

    private func loadURLItem(from provider: NSItemProvider, typeIdentifier: String) async throws -> URL? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }
                if let nsURL = item as? NSURL, let url = nsURL as URL? {
                    continuation.resume(returning: url)
                    return
                }
                if let text = item as? String, let url = URL(string: text) {
                    continuation.resume(returning: url)
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }

    private func loadStringItem(from provider: NSItemProvider, typeIdentifier: String) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                if let text = item as? String {
                    continuation.resume(returning: text)
                    return
                }
                if let nsString = item as? NSString {
                    continuation.resume(returning: nsString as String)
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }

    private func loadDataRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> Data? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: data)
            }
        }
    }

    private func stagePayload(_ payload: SharedPayload, in inboxDirectory: URL) throws -> ShareInboxItemRecord {
        let originalName = normalizedFileName(payload.fileName)
        let targetURL = uniqueInboxFileURL(in: inboxDirectory, preferredName: originalName)
        try payload.data.write(to: targetURL, options: .atomic)
        return ShareInboxItemRecord(
            storedFileName: targetURL.lastPathComponent,
            originalFileName: originalName,
            mimeType: payload.mimeType,
            createdAt: Date().timeIntervalSince1970
        )
    }

    private func resolveInboxDirectory() throws -> URL {
        guard let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: ShareBridgeConfig.appGroupIdentifier) else {
            throw NSError(domain: "ShareExtension", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "Unable to access shared App Group container"
            ])
        }

        let inbox = container.appendingPathComponent(ShareBridgeConfig.inboxDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: inbox.path) {
            try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
        }
        return inbox
    }

    private func loadManifest(from inboxDirectory: URL) -> ShareInboxManifest {
        let manifestURL = inboxDirectory.appendingPathComponent(ShareBridgeConfig.manifestFileName)
        guard let data = try? Data(contentsOf: manifestURL) else {
            return ShareInboxManifest()
        }
        return (try? JSONDecoder().decode(ShareInboxManifest.self, from: data)) ?? ShareInboxManifest()
    }

    private func saveManifest(_ manifest: ShareInboxManifest, in inboxDirectory: URL) throws {
        let manifestURL = inboxDirectory.appendingPathComponent(ShareBridgeConfig.manifestFileName)
        let encoded = try JSONEncoder().encode(manifest)
        try encoded.write(to: manifestURL, options: .atomic)
    }

    private func uniqueInboxFileURL(in directory: URL, preferredName: String) -> URL {
        let sanitizedName = normalizedFileName(preferredName)
        let nsName = sanitizedName as NSString
        let ext = nsName.pathExtension
        let base = nsName.deletingPathExtension

        var index = 0
        while true {
            let candidateName: String
            if index == 0 {
                candidateName = sanitizedName
            } else {
                let suffix = "\(base)_\(index)"
                candidateName = ext.isEmpty ? suffix : "\(suffix).\(ext)"
            }

            let candidateURL = directory.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
            index += 1
        }
    }

    private func normalizedFileName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let safe = trimmed.isEmpty ? "share_\(Int(Date().timeIntervalSince1970)).bin" : trimmed
        let invalidPattern = "[\\\\/:*?\"<>|]"
        return safe.replacingOccurrences(of: invalidPattern, with: "_", options: .regularExpression)
    }

    private func fallbackName(from suggested: String?, defaultExt: String?) -> String {
        let cleaned = suggested?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !cleaned.isEmpty {
            if cleaned.contains(".") || defaultExt == nil {
                return cleaned
            }
            return "\(cleaned).\(defaultExt!)"
        }
        let ext = defaultExt ?? "bin"
        return "share_\(Int(Date().timeIntervalSince1970)).\(ext)"
    }

    private func mimeTypeForFileName(_ fileName: String) -> String? {
        let ext = (fileName as NSString).pathExtension
        guard !ext.isEmpty else { return nil }
        return UTType(filenameExtension: ext)?.preferredMIMEType
    }
}
