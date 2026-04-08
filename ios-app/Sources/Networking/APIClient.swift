import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case serverMessage(String)
    case httpStatus(Int, String?)
    case decodingFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "接口地址无效"
        case .unauthorized:
            return "登录状态已失效，请重新登录"
        case let .serverMessage(message):
            return message
        case let .httpStatus(code, message):
            if let message, !message.isEmpty {
                return message
            }
            return "请求失败，状态码 \(code)"
        case .decodingFailed:
            return "服务返回解析失败"
        case .unknown:
            return "请求失败，请稍后重试"
        }
    }
}

final class APIClient {
    static let shared = APIClient()

    var tokenProvider: () -> String? = { nil }
    var unauthorizedHandler: (() -> Void)?

    private struct GETCachePolicy {
        let freshTTL: TimeInterval
        let staleTTL: TimeInterval
        let allowsStaleWhileRevalidate: Bool

        static let `default` = GETCachePolicy(
            freshTTL: 2.5,
            staleTTL: 10,
            allowsStaleWhileRevalidate: true
        )
    }

    private actor GETResponseStore {
        enum CacheLookup {
            case fresh(Data)
            case stale(Data)
            case miss
        }

        struct CacheEntry {
            let data: Data
            let timestamp: Date
        }

        private var cache: [String: CacheEntry] = [:]
        private var inFlight: [String: Task<Data, Error>] = [:]

        func lookupCachedData(
            for key: String,
            policy: GETCachePolicy,
            now: Date = Date()
        ) -> CacheLookup {
            guard let entry = cache[key] else {
                return .miss
            }
            let age = now.timeIntervalSince(entry.timestamp)
            if age <= policy.freshTTL {
                return .fresh(entry.data)
            }
            if age <= policy.staleTTL, policy.allowsStaleWhileRevalidate {
                return .stale(entry.data)
            }
            if age > policy.staleTTL {
                cache.removeValue(forKey: key)
            }
            return .miss
        }

        func runningTask(for key: String) -> Task<Data, Error>? {
            inFlight[key]
        }

        func setTask(_ task: Task<Data, Error>, for key: String) {
            inFlight[key] = task
        }

        func clearTask(for key: String) {
            inFlight.removeValue(forKey: key)
        }

        func store(_ data: Data, for key: String, now: Date = Date()) {
            cache[key] = CacheEntry(data: data, timestamp: now)
        }

        func removeCache(for key: String) {
            cache.removeValue(forKey: key)
        }

        func invalidateAll() {
            cache.removeAll(keepingCapacity: true)
        }
    }

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let getResponseStore: GETResponseStore

    private init() {
        self.session = URLSession(configuration: .default)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.getResponseStore = GETResponseStore()

        let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        let fallback = "https://cms.zglweb.cn:6606/"
        let value = (raw?.isEmpty == false ? raw! : fallback)
        self.baseURL = URL(string: value) ?? URL(string: fallback)!
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        let request = LoginRequest(username: username, password: password)
        return try await send(path: "api/auth/login", method: "POST", body: request, authorized: false)
    }

    func me() async throws -> LoginResponse {
        let request = try makeRequest(
            path: "api/auth/me",
            method: "GET",
            queryItems: [],
            bodyData: nil,
            authorized: true
        )
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, notifyUnauthorized: true)
        return try decodeResponse(LoginResponse.self, from: data)
    }

    func dashboard() async throws -> DashboardStats {
        try await send(path: "api/devices/dashboard", method: "GET", authorized: true)
    }

    func devicesPaged(
        mode: DeviceListMode,
        search: String?,
        dept: String?,
        validity: String?,
        useStatus: String?,
        baselineUseStatus: String?,
        nextDateFrom: String?,
        nextDateTo: String?,
        page: Int,
        size: Int
    ) async throws -> PageResult<DeviceDto> {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "todoOnly", value: mode == .todo ? "true" : "false"),
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size))
        ]

        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "search", value: search))
        }
        if let dept, !dept.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "dept", value: dept))
        }
        if let validity, !validity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "validity", value: validity))
        }

        let resolvedUseStatus: String?
        if mode == .calibration {
            resolvedUseStatus = "正常"
        } else {
            resolvedUseStatus = useStatus
        }
        if let resolvedUseStatus, !resolvedUseStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "useStatus", value: resolvedUseStatus))
        }
        if let baselineUseStatus, !baselineUseStatus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "baselineUseStatus", value: baselineUseStatus))
        }

        if let nextDateFrom, !nextDateFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "nextDateFrom", value: nextDateFrom))
        }
        if let nextDateTo, !nextDateTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "nextDateTo", value: nextDateTo))
        }
        return try await send(path: "api/devices/paged", method: "GET", queryItems: query, authorized: true)
    }

    func updateDeviceCalibration(id: Int64, payload: DeviceCalibrationPayload) async throws -> DeviceDto {
        try await send(path: "api/devices/\(id)/calibration", method: "PUT", body: payload, authorized: true)
    }

    func updateDevice(id: Int64, payload: DeviceUpdatePayload) async throws -> DeviceDto {
        try await send(path: "api/devices/\(id)", method: "PUT", body: payload, authorized: true)
    }

    func deleteDevice(id: Int64) async throws {
        try await sendWithoutResponse(path: "api/devices/\(id)", method: "DELETE", authorized: true)
    }

    func createDevice(payload: DeviceUpdatePayload) async throws -> DeviceCreateResult {
        let bodyData = try encoder.encode(payload)
        let request = try makeRequest(
            path: "api/devices",
            method: "POST",
            queryItems: [],
            bodyData: bodyData,
            authorized: true
        )
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        await getResponseStore.invalidateAll()

        if let created = try? decoder.decode(DeviceDto.self, from: data) {
            return .created(created)
        }

        let fallbackMessage = "新增申请已提交，等待审核"
        let message = extractErrorMessage(from: data) ?? fallbackMessage
        return .submitted(message: message)
    }

    func pendingAudit() async throws -> [AuditRecordDto] {
        try await send(path: "api/audit/pending", method: "GET", authorized: true)
    }

    func myAudit() async throws -> [AuditRecordDto] {
        try await send(path: "api/audit/my", method: "GET", authorized: true)
    }

    func allAudit(
        page: Int,
        size: Int,
        keyword: String? = nil,
        type: String? = nil,
        status: String? = nil
    ) async throws -> PageResult<AuditRecordDto> {
        var query = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size))
        ]
        if let keyword, !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "keyword", value: keyword))
        }
        if let type, !type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "type", value: type))
        }
        if let status, !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "status", value: status))
        }
        return try await send(path: "api/audit", method: "GET", queryItems: query, authorized: true)
    }

    func auditDetail(id: Int64) async throws -> AuditRecordDto {
        try await send(path: "api/audit/\(id)", method: "GET", authorized: true)
    }

    func approveAudit(id: Int64) async throws -> AuditRecordDto {
        try await send(path: "api/audit/\(id)/approve", method: "POST", body: [String: String](), authorized: true)
    }

    func rejectAudit(id: Int64, reason: String?) async throws -> AuditRecordDto {
        try await send(path: "api/audit/\(id)/reject", method: "POST", body: RejectRequest(reason: reason), authorized: true)
    }

    func files(parentId: Int64?) async throws -> FileListResponseDto {
        var query: [URLQueryItem] = []
        if let parentId {
            query.append(URLQueryItem(name: "parentId", value: String(parentId)))
        }
        return try await send(path: "api/files", method: "GET", queryItems: query, authorized: true)
    }

    func createFolder(name: String, parentId: Int64?) async throws -> UserFileItemDto {
        let payload = CreateFolderRequest(name: name, parentId: parentId)
        return try await send(path: "api/files/folder", method: "POST", body: payload, authorized: true)
    }

    func uploadFile(parentId: Int64?, fileName: String, mimeType: String?, fileURL: URL) async throws -> UserFileItemDto {
        let boundary = "Boundary-\(UUID().uuidString)"
        let multipartFileURL = try makeMultipartBodyFile(
            boundary: boundary,
            fileField: "file",
            fileName: fileName,
            mimeType: mimeType ?? "application/octet-stream",
            sourceFileURL: fileURL
        )
        defer { try? FileManager.default.removeItem(at: multipartFileURL) }

        var query: [URLQueryItem] = []
        if let parentId {
            query.append(URLQueryItem(name: "parentId", value: String(parentId)))
        }

        var request = try makeRequest(path: "api/files/upload", method: "POST", queryItems: query, bodyData: nil, authorized: true)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBodyStream = InputStream(url: multipartFileURL)
        if let bodySize = fileByteLength(at: multipartFileURL) {
            request.setValue(String(bodySize), forHTTPHeaderField: "Content-Length")
        }

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        await getResponseStore.invalidateAll()
        return try decodeResponse(UserFileItemDto.self, from: data)
    }

    func scanSync(parentId: Int64?) async throws -> ScanSyncResultDto {
        let payload = ParentFolderRequest(parentId: parentId)
        return try await send(path: "api/files/scan-sync", method: "POST", body: payload, authorized: true)
    }

    func fileBreadcrumb(folderId: Int64) async throws -> [BreadcrumbItemDto] {
        let query = [URLQueryItem(name: "folderId", value: String(folderId))]
        return try await send(path: "api/files/breadcrumb", method: "GET", queryItems: query, authorized: true)
    }

    func grantableFolders() async throws -> [GrantableFolderDto] {
        try await send(path: "api/files/grantable-folders", method: "GET", authorized: true)
    }

    func renameFile(id: Int64, name: String) async throws -> UserFileItemDto {
        try await send(
            path: "api/files/\(id)/rename",
            method: "PUT",
            body: RenameFileRequest(name: name),
            authorized: true
        )
    }

    func moveFile(id: Int64, parentId: Int64?) async throws -> UserFileItemDto {
        try await send(
            path: "api/files/\(id)/move",
            method: "PUT",
            body: MoveFileRequest(parentId: parentId),
            authorized: true
        )
    }

    func deleteFile(id: Int64) async throws {
        try await sendWithoutResponse(path: "api/files/\(id)", method: "DELETE", authorized: true)
    }

    func downloadFile(id: Int64, suggestedName: String?) async throws -> URL {
        let safeName = sanitizeFilename(suggestedName ?? "preview.bin")
        let cache = try resolveDownloadCacheURLs(fileId: id, safeName: safeName)
        let fileExists = FileManager.default.fileExists(atPath: cache.fileURL.path)
        var cachedEtag = loadCachedEtag(from: cache.etagURL)

        if fileExists, let cachedEtag {
            var validateRequest = try makeRequest(
                path: "api/files/\(id)/download",
                method: "GET",
                queryItems: [],
                bodyData: nil,
                authorized: true
            )
            validateRequest.timeoutInterval = 35
            validateRequest.setValue(cachedEtag, forHTTPHeaderField: "If-None-Match")
            let (_, validateResponse) = try await session.data(for: validateRequest)
            if let http = validateResponse as? HTTPURLResponse {
                if http.statusCode == 304 {
                    return cache.fileURL
                }
                if http.statusCode == 401 {
                    notifyUnauthorizedIfNeeded()
                    throw APIError.unauthorized
                }
            }
        } else if fileExists, cachedEtag == nil {
            return cache.fileURL
        }

        var resumeOffset = fileByteLength(at: cache.partialURL) ?? 0
        if resumeOffset > 0, cachedEtag == nil {
            try? FileManager.default.removeItem(at: cache.partialURL)
            resumeOffset = 0
        }

        let downloadChunkSize = 1024 * 1024

        while true {
            try Task.checkCancellation()

            let chunkStart = max(resumeOffset, 0)
            let chunkEnd = chunkStart + Int64(downloadChunkSize) - 1

            var request = try makeRequest(
                path: "api/files/\(id)/download",
                method: "GET",
                queryItems: [],
                bodyData: nil,
                authorized: true
            )
            request.timeoutInterval = 120
            request.setValue("bytes=\(chunkStart)-\(chunkEnd)", forHTTPHeaderField: "Range")
            if let cachedEtag, !cachedEtag.isEmpty {
                request.setValue(cachedEtag, forHTTPHeaderField: "If-Range")
            }

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.unknown
            }

            if http.statusCode == 304, fileExists {
                return cache.fileURL
            }

            if http.statusCode == 401 {
                notifyUnauthorizedIfNeeded()
                throw APIError.unauthorized
            }

            guard http.statusCode == 200 || http.statusCode == 206 else {
                let message = extractErrorMessage(from: data)
                throw APIError.httpStatus(http.statusCode, message)
            }

            if let responseEtag = http.value(forHTTPHeaderField: "ETag"),
               !responseEtag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                cachedEtag = responseEtag
                saveCachedEtag(responseEtag, to: cache.etagURL)
            }

            if http.statusCode == 206 {
                try appendChunk(data, to: cache.partialURL, truncate: resumeOffset == 0)
                resumeOffset += Int64(data.count)

                if let total = parseTotalLength(fromContentRange: http.value(forHTTPHeaderField: "Content-Range")),
                   resumeOffset >= total {
                    return try finalizePartialDownload(from: cache.partialURL, to: cache.fileURL)
                }

                if data.count < downloadChunkSize {
                    return try finalizePartialDownload(from: cache.partialURL, to: cache.fileURL)
                }
                continue
            }

            // 200 usually means server returned full file (e.g. no range or etag changed).
            try writeFile(data, to: cache.partialURL)
            return try finalizePartialDownload(from: cache.partialURL, to: cache.fileURL)
        }
    }

    func settings() async throws -> SettingsDto {
        try await send(path: "api/settings", method: "GET", authorized: true)
    }

    func saveSettings(_ payload: SettingsDto) async throws -> SettingsDto {
        try await send(path: "api/settings", method: "PUT", body: payload, authorized: true)
    }

    func runMaintenanceNow() async throws -> MaintenanceRunResultDto {
        try await send(path: "api/settings/maintenance/run", method: "POST", body: [String: String](), authorized: true)
    }

    func deviceStatuses() async throws -> [DeviceStatusDto] {
        try await send(path: "api/device-statuses", method: "GET", authorized: true)
    }

    func createDeviceStatus(name: String) async throws -> DeviceStatusDto {
        try await send(path: "api/device-statuses", method: "POST", body: ["name": name], authorized: true)
    }

    func updateDeviceStatus(id: Int64, name: String) async throws -> DeviceStatusDto {
        try await send(path: "api/device-statuses/\(id)", method: "PUT", body: ["name": name], authorized: true)
    }

    func deleteDeviceStatus(id: Int64) async throws {
        try await sendWithoutResponse(path: "api/device-statuses/\(id)", method: "DELETE", authorized: true)
    }

    func departments(search: String?) async throws -> [DepartmentDto] {
        var query: [URLQueryItem] = []
        if let search, !search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "search", value: search))
        }
        return try await send(path: "api/departments", method: "GET", queryItems: query, authorized: true)
    }

    func createDepartment(
        name: String,
        code: String,
        sortOrder: Int,
        parentId: Int64?
    ) async throws -> DepartmentDto {
        try await send(
            path: "api/departments",
            method: "POST",
            body: [
                "name": name,
                "code": code,
                "sortOrder": String(sortOrder),
                "parentId": parentId.map(String.init) ?? ""
            ],
            authorized: true
        )
    }

    func updateDepartment(
        id: Int64,
        name: String,
        code: String,
        sortOrder: Int,
        parentId: Int64?
    ) async throws -> DepartmentDto {
        try await send(
            path: "api/departments/\(id)",
            method: "PUT",
            body: [
                "name": name,
                "code": code,
                "sortOrder": String(sortOrder),
                "parentId": parentId.map(String.init) ?? ""
            ],
            authorized: true
        )
    }

    func deleteDepartment(id: Int64) async throws {
        try await sendWithoutResponse(path: "api/departments/\(id)", method: "DELETE", authorized: true)
    }

    func users() async throws -> [UserDto] {
        try await send(path: "api/users", method: "GET", authorized: true)
    }

    func createUser(payload: UserCreatePayload) async throws -> SimpleMessageResponse {
        try await send(path: "api/users", method: "POST", body: payload, authorized: true)
    }

    func updateUserRolePermissions(id: Int64, payload: UserRolePermissionPayload) async throws -> SimpleMessageResponse {
        try await send(path: "api/users/\(id)/role-permissions", method: "PUT", body: payload, authorized: true)
    }

    func resetUserPassword(id: Int64, password: String) async throws -> SimpleMessageResponse {
        try await send(path: "api/users/\(id)/password", method: "PUT", body: PasswordResetPayload(password: password), authorized: true)
    }

    func deleteUser(id: Int64) async throws {
        try await sendWithoutResponse(path: "api/users/\(id)", method: "DELETE", authorized: true)
    }

    func changeRecords(
        page: Int,
        size: Int,
        keyword: String?,
        type: String?,
        status: String?,
        submittedBy: String?,
        dateFrom: String?,
        dateTo: String?
    ) async throws -> ChangeRecordPageDto {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "size", value: String(size))
        ]
        if let keyword, !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "keyword", value: keyword))
        }
        if let type, !type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "type", value: type))
        }
        if let status, !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "status", value: status))
        }
        if let submittedBy, !submittedBy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "submittedBy", value: submittedBy))
        }
        if let dateFrom, !dateFrom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "dateFrom", value: dateFrom))
        }
        if let dateTo, !dateTo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "dateTo", value: dateTo))
        }
        return try await send(path: "api/change-records", method: "GET", queryItems: query, authorized: true)
    }

    func changeRecordDetail(id: Int64) async throws -> AuditRecordDto {
        try await send(path: "api/change-records/\(id)", method: "GET", authorized: true)
    }

    func webDavMounts() async throws -> [WebDavMountDto] {
        try await send(path: "api/webdav/mounts", method: "GET", authorized: true)
    }

    func createWebDavMount(name: String, url: String, username: String, password: String) async throws -> WebDavMountDto {
        try await send(
            path: "api/webdav/mounts",
            method: "POST",
            body: [
                "name": name,
                "url": url,
                "username": username,
                "password": password
            ],
            authorized: true
        )
    }

    func updateWebDavMount(id: Int64, body: [String: String]) async throws -> WebDavMountDto {
        try await send(path: "api/webdav/mounts/\(id)", method: "PUT", body: body, authorized: true)
    }

    func deleteWebDavMount(id: Int64) async throws {
        try await sendWithoutResponse(path: "api/webdav/mounts/\(id)", method: "DELETE", authorized: true)
    }

    func testWebDavConnection(url: String, username: String, password: String) async throws -> Bool {
        let result: WebDavTestResponse = try await send(
            path: "api/webdav/mounts/test",
            method: "POST",
            body: WebDavTestRequest(url: url, username: username, password: password),
            authorized: true
        )
        return result.success == true
    }

    func webDavBrowse(mountId: Int64, path: String?) async throws -> [WebDavFileDto] {
        var query: [URLQueryItem] = [URLQueryItem(name: "mountId", value: String(mountId))]
        if let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "path", value: path))
        }
        return try await send(path: "api/webdav/browse", method: "GET", queryItems: query, authorized: true)
    }

    func webDavDownload(mountId: Int64, path: String, filename: String?) async throws -> URL {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "mountId", value: String(mountId)),
            URLQueryItem(name: "path", value: path)
        ]
        if let filename, !filename.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(URLQueryItem(name: "filename", value: filename))
        }

        var request = try makeRequest(path: "api/webdav/download", method: "GET", queryItems: query, bodyData: nil, authorized: true)
        request.timeoutInterval = 180
        let (tempURL, response) = try await session.download(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 401 {
                notifyUnauthorizedIfNeeded()
                throw APIError.unauthorized
            }
            let data = (try? Data(contentsOf: tempURL)) ?? Data()
            let message = extractErrorMessage(from: data)
            throw APIError.httpStatus(http.statusCode, message)
        }

        let safeName = sanitizeFilename(filename ?? URL(fileURLWithPath: path).lastPathComponent)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_" + safeName)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        do {
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        } catch {
            try FileManager.default.copyItem(at: tempURL, to: fileURL)
            try? FileManager.default.removeItem(at: tempURL)
        }
        return fileURL
    }

    func webDavUpload(mountId: Int64, path: String, fileName: String, mimeType: String?, fileURL: URL) async throws -> SimpleMessageResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        let multipartFileURL = try makeMultipartBodyFile(
            boundary: boundary,
            fileField: "file",
            fileName: fileName,
            mimeType: mimeType ?? "application/octet-stream",
            sourceFileURL: fileURL
        )
        defer { try? FileManager.default.removeItem(at: multipartFileURL) }

        let query = [
            URLQueryItem(name: "mountId", value: String(mountId)),
            URLQueryItem(name: "path", value: path)
        ]
        var request = try makeRequest(path: "api/webdav/upload", method: "POST", queryItems: query, bodyData: nil, authorized: true)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBodyStream = InputStream(url: multipartFileURL)
        if let bodySize = fileByteLength(at: multipartFileURL) {
            request.setValue(String(bodySize), forHTTPHeaderField: "Content-Length")
        }

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        await getResponseStore.invalidateAll()
        return try decodeResponse(SimpleMessageResponse.self, from: data)
    }

    private func sanitizeFilename(_ value: String) -> String {
        value.replacingOccurrences(of: "[\\/:*?\"<>|]", with: "_", options: .regularExpression)
    }

    private struct DownloadCacheURLs {
        let fileURL: URL
        let etagURL: URL
        let partialURL: URL
    }

    private func resolveDownloadCacheURLs(fileId: Int64, safeName: String) throws -> DownloadCacheURLs {
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = cachesDir.appendingPathComponent("MetrologyDownloads", isDirectory: true)
        if !FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        }

        let normalizedName = safeName.isEmpty ? "preview.bin" : safeName
        let baseName = "file_\(fileId)_\(normalizedName)"
        let fileURL = folder.appendingPathComponent(baseName)
        let etagURL = folder.appendingPathComponent(baseName + ".etag")
        let partialURL = folder.appendingPathComponent(baseName + ".part")
        return DownloadCacheURLs(fileURL: fileURL, etagURL: etagURL, partialURL: partialURL)
    }

    private func loadCachedEtag(from url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func saveCachedEtag(_ etag: String, to url: URL) {
        let value = etag.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        try? value.write(to: url, atomically: true, encoding: .utf8)
    }

    private func fileByteLength(at url: URL) -> Int64? {
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            return Int64(size)
        }
        if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let number = attrs[.size] as? NSNumber {
            return number.int64Value
        }
        return nil
    }

    private func makeMultipartBodyFile(
        boundary: String,
        fileField: String,
        fileName: String,
        mimeType: String,
        sourceFileURL: URL
    ) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("multipart_\(UUID().uuidString).tmp", isDirectory: false)
        FileManager.default.createFile(atPath: tempURL.path, contents: nil)

        let outputHandle = try FileHandle(forWritingTo: tempURL)
        do {
            try appendMultipartText("--\(boundary)\r\n", to: outputHandle)
            try appendMultipartText("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\r\n", to: outputHandle)
            try appendMultipartText("Content-Type: \(mimeType)\r\n\r\n", to: outputHandle)
            try appendFileContents(from: sourceFileURL, to: outputHandle)
            try appendMultipartText("\r\n--\(boundary)--\r\n", to: outputHandle)
            try outputHandle.close()
            return tempURL
        } catch {
            try? outputHandle.close()
            try? FileManager.default.removeItem(at: tempURL)
            throw error
        }
    }

    private func appendMultipartText(_ text: String, to handle: FileHandle) throws {
        guard let data = text.data(using: .utf8) else { return }
        try handle.write(contentsOf: data)
    }

    private func appendFileContents(from sourceURL: URL, to outputHandle: FileHandle) throws {
        let inputHandle = try FileHandle(forReadingFrom: sourceURL)
        defer { try? inputHandle.close() }

        while true {
            let chunk = try inputHandle.read(upToCount: 64 * 1024) ?? Data()
            if chunk.isEmpty {
                break
            }
            try outputHandle.write(contentsOf: chunk)
        }
    }

    private func appendChunk(_ chunk: Data, to url: URL, truncate: Bool) throws {
        if truncate || !FileManager.default.fileExists(atPath: url.path) {
            try writeFile(chunk, to: url)
            return
        }

        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: chunk)
    }

    private func writeFile(_ data: Data, to url: URL) throws {
        FileManager.default.createFile(atPath: url.path, contents: nil)
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        try handle.truncate(atOffset: 0)
        try handle.write(contentsOf: data)
    }

    private func finalizePartialDownload(from partialURL: URL, to finalURL: URL) throws -> URL {
        if FileManager.default.fileExists(atPath: finalURL.path) {
            try? FileManager.default.removeItem(at: finalURL)
        }
        do {
            try FileManager.default.moveItem(at: partialURL, to: finalURL)
        } catch {
            try? FileManager.default.removeItem(at: finalURL)
            try FileManager.default.copyItem(at: partialURL, to: finalURL)
            try? FileManager.default.removeItem(at: partialURL)
        }
        return finalURL
    }

    private func parseTotalLength(fromContentRange contentRange: String?) -> Int64? {
        guard let contentRange else { return nil }
        // bytes 0-1023/4096
        guard let slash = contentRange.lastIndex(of: "/") else { return nil }
        let value = String(contentRange[contentRange.index(after: slash)...]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard value != "*", let total = Int64(value) else { return nil }
        return total
    }

    private func requestCacheKey(for request: URLRequest) -> String {
        let method = request.httpMethod?.uppercased() ?? "GET"
        let url = request.url?.absoluteString ?? ""
        let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
        return "\(method)|\(url)|\(auth)"
    }

    private func cachePolicy(for request: URLRequest) -> GETCachePolicy {
        let path = request.url?.path.lowercased() ?? ""

        if path.contains("/api/devices/dashboard") {
            return GETCachePolicy(freshTTL: 10, staleTTL: 40, allowsStaleWhileRevalidate: true)
        }
        if path.contains("/api/devices/paged") || path.contains("/api/audit") || path.contains("/api/change-records") {
            return GETCachePolicy(freshTTL: 1.2, staleTTL: 5, allowsStaleWhileRevalidate: true)
        }
        if path.contains("/api/files") || path.contains("/api/webdav/browse") {
            return GETCachePolicy(freshTTL: 2, staleTTL: 8, allowsStaleWhileRevalidate: true)
        }
        if path.contains("/api/departments")
            || path.contains("/api/device-statuses")
            || path.contains("/api/users")
            || path.contains("/api/webdav/mounts")
            || path.contains("/api/settings") {
            return GETCachePolicy(freshTTL: 60, staleTTL: 300, allowsStaleWhileRevalidate: true)
        }
        return .default
    }

    private func decodeResponse<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func sendCachedGet<T: Decodable>(
        request: URLRequest,
        as type: T.Type,
        notifyUnauthorized: Bool
    ) async throws -> T {
        let key = requestCacheKey(for: request)
        let policy = cachePolicy(for: request)

        switch await getResponseStore.lookupCachedData(for: key, policy: policy) {
        case let .fresh(cached):
            return try decodeResponse(T.self, from: cached)
        case let .stale(stale):
            if let decoded = try? decodeResponse(T.self, from: stale) {
                await startBackgroundRefreshIfNeeded(
                    key: key,
                    request: request,
                    notifyUnauthorized: notifyUnauthorized
                )
                return decoded
            }
            await getResponseStore.removeCache(for: key)
        case .miss:
            break
        }

        if let running = await getResponseStore.runningTask(for: key) {
            let data = try await running.value
            return try decodeResponse(T.self, from: data)
        }

        let task = makeGETFetchTask(request: request, notifyUnauthorized: notifyUnauthorized)
        await getResponseStore.setTask(task, for: key)

        do {
            let data = try await task.value
            await getResponseStore.store(data, for: key)
            await getResponseStore.clearTask(for: key)
            return try decodeResponse(T.self, from: data)
        } catch {
            await getResponseStore.clearTask(for: key)
            throw error
        }
    }

    private func makeGETFetchTask(
        request: URLRequest,
        notifyUnauthorized: Bool
    ) -> Task<Data, Error> {
        Task<Data, Error> {
            let (data, response) = try await self.session.data(for: request)
            try self.validate(response: response, data: data, notifyUnauthorized: notifyUnauthorized)
            return data
        }
    }

    private func startBackgroundRefreshIfNeeded(
        key: String,
        request: URLRequest,
        notifyUnauthorized: Bool
    ) async {
        if await getResponseStore.runningTask(for: key) != nil {
            return
        }

        let refreshTask = makeGETFetchTask(
            request: request,
            notifyUnauthorized: notifyUnauthorized
        )
        await getResponseStore.setTask(refreshTask, for: key)

        Task.detached { [weak self] in
            guard let self else { return }
            defer {
                Task {
                    await self.getResponseStore.clearTask(for: key)
                }
            }
            if let data = try? await refreshTask.value {
                await self.getResponseStore.store(data, for: key)
            }
        }
    }

    private func invalidateGetCaches() async {
        await getResponseStore.invalidateAll()
    }

    private func send<T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        authorized: Bool
    ) async throws -> T {
        let request = try makeRequest(path: path, method: method, queryItems: queryItems, bodyData: nil, authorized: authorized)
        if method.uppercased() == "GET" {
            return try await sendCachedGet(
                request: request,
                as: T.self,
                notifyUnauthorized: authorized
            )
        }
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, notifyUnauthorized: authorized)
        await invalidateGetCaches()
        return try decodeResponse(T.self, from: data)
    }

    private func send<T: Decodable, U: Encodable>(
        path: String,
        method: String,
        body: U,
        authorized: Bool
    ) async throws -> T {
        let bodyData = try encoder.encode(body)
        let request = try makeRequest(path: path, method: method, queryItems: [], bodyData: bodyData, authorized: authorized)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, notifyUnauthorized: authorized)
        await invalidateGetCaches()
        return try decodeResponse(T.self, from: data)
    }

    private func sendWithoutResponse(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        authorized: Bool
    ) async throws {
        let request = try makeRequest(path: path, method: method, queryItems: queryItems, bodyData: nil, authorized: authorized)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data, notifyUnauthorized: authorized)
        await invalidateGetCaches()
    }

    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem],
        bodyData: Data?,
        authorized: Bool
    ) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if authorized, let token = tokenProvider(), !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = bodyData
        return request
    }

    private func validate(response: URLResponse, data: Data, notifyUnauthorized: Bool = true) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        if (200...299).contains(http.statusCode) {
            return
        }

        if http.statusCode == 401 {
            if notifyUnauthorized {
                notifyUnauthorizedIfNeeded()
            }
            throw APIError.unauthorized
        }

        let message = extractErrorMessage(from: data)
        throw APIError.httpStatus(http.statusCode, message)
    }

    private func extractErrorMessage(from data: Data) -> String? {
        if let dto = try? decoder.decode(SimpleMessageResponse.self, from: data),
           let message = dto.message,
           !message.isEmpty {
            return message
        }

        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let message = object["message"] as? String,
           !message.isEmpty {
            return message
        }

        return nil
    }

    private func notifyUnauthorizedIfNeeded() {
        Task { @MainActor [weak self] in
            self?.unauthorizedHandler?()
        }
    }
}

enum DeviceListMode {
    case ledger
    case calibration
    case todo
}
