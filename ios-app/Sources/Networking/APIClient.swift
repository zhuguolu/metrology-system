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

    private let session: URLSession
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private init() {
        self.session = URLSession(configuration: .default)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()

        let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String
        let fallback = "https://cms.zglweb.cn:6606/"
        let value = (raw?.isEmpty == false ? raw! : fallback)
        self.baseURL = URL(string: value) ?? URL(string: fallback)!
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        let request = LoginRequest(username: username, password: password)
        return try await send(path: "api/auth/login", method: "POST", body: request, authorized: false)
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

    func uploadFile(parentId: Int64?, fileName: String, mimeType: String?, bytes: Data) async throws -> UserFileItemDto {
        let boundary = "Boundary-\(UUID().uuidString)"
        let body = makeMultipartBody(
            boundary: boundary,
            fileField: "file",
            fileName: fileName,
            mimeType: mimeType ?? "application/octet-stream",
            fileBytes: bytes
        )
        var query: [URLQueryItem] = []
        if let parentId {
            query.append(URLQueryItem(name: "parentId", value: String(parentId)))
        }

        var request = try makeRequest(path: "api/files/upload", method: "POST", queryItems: query, bodyData: body, authorized: true)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(UserFileItemDto.self, from: data)
    }

    func scanSync(parentId: Int64?) async throws -> ScanSyncResultDto {
        let payload = ParentFolderRequest(parentId: parentId)
        return try await send(path: "api/files/scan-sync", method: "POST", body: payload, authorized: true)
    }

    func fileBreadcrumb(folderId: Int64) async throws -> [BreadcrumbItemDto] {
        let query = [URLQueryItem(name: "folderId", value: String(folderId))]
        return try await send(path: "api/files/breadcrumb", method: "GET", queryItems: query, authorized: true)
    }

    func downloadFile(id: Int64, suggestedName: String?) async throws -> URL {
        var request = try makeRequest(path: "api/files/\(id)/download", method: "GET", queryItems: [], bodyData: nil, authorized: true)
        request.timeoutInterval = 120

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let safeName = sanitizeFilename(suggestedName ?? "preview.bin")
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_" + safeName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
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
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)

        let safeName = sanitizeFilename(filename ?? URL(fileURLWithPath: path).lastPathComponent)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "_" + safeName)
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    func webDavUpload(mountId: Int64, path: String, fileName: String, mimeType: String?, bytes: Data) async throws -> SimpleMessageResponse {
        let boundary = "Boundary-\(UUID().uuidString)"
        let body = makeMultipartBody(
            boundary: boundary,
            fileField: "file",
            fileName: fileName,
            mimeType: mimeType ?? "application/octet-stream",
            fileBytes: bytes
        )
        let query = [
            URLQueryItem(name: "mountId", value: String(mountId)),
            URLQueryItem(name: "path", value: path)
        ]
        var request = try makeRequest(path: "api/webdav/upload", method: "POST", queryItems: query, bodyData: body, authorized: true)
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        return try decoder.decode(SimpleMessageResponse.self, from: data)
    }

    private func sanitizeFilename(_ value: String) -> String {
        value.replacingOccurrences(of: "[\\/:*?\"<>|]", with: "_", options: .regularExpression)
    }

    private func makeMultipartBody(
        boundary: String,
        fileField: String,
        fileName: String,
        mimeType: String,
        fileBytes: Data
    ) -> Data {
        var data = Data()
        let lineBreak = "\r\n"
        data.append("--\(boundary)\(lineBreak)".data(using: .utf8)!)
        data.append("Content-Disposition: form-data; name=\"\(fileField)\"; filename=\"\(fileName)\"\(lineBreak)".data(using: .utf8)!)
        data.append("Content-Type: \(mimeType)\(lineBreak)\(lineBreak)".data(using: .utf8)!)
        data.append(fileBytes)
        data.append(lineBreak.data(using: .utf8)!)
        data.append("--\(boundary)--\(lineBreak)".data(using: .utf8)!)
        return data
    }

    private func send<T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        authorized: Bool
    ) async throws -> T {
        let request = try makeRequest(path: path, method: method, queryItems: queryItems, bodyData: nil, authorized: authorized)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
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
        try validate(response: response, data: data)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func sendWithoutResponse(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        authorized: Bool
    ) async throws {
        let request = try makeRequest(path: path, method: method, queryItems: queryItems, bodyData: nil, authorized: authorized)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
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

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown
        }

        if (200...299).contains(http.statusCode) {
            return
        }

        if http.statusCode == 401 {
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
}

enum DeviceListMode {
    case ledger
    case calibration
    case todo
}
