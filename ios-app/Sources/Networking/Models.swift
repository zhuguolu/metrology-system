import Foundation

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct LoginResponse: Codable {
    let token: String?
    let username: String?
    let userId: Int64?
    let role: String?
    let permissions: [String]?
    let department: String?
    let departments: [String]?
}

struct DashboardStats: Codable {
    let total: Int64?
    let dueThisMonth: Int64?
    let expired: Int64?
    let warning: Int64?
    let valid: Int64?
}

struct DeviceDto: Codable, Identifiable {
    let id: Int64?
    let name: String?
    let metricNo: String?
    let assetNo: String?
    let abcClass: String?
    let dept: String?
    let location: String?
    let cycle: Int?
    let serialNo: String?
    let purchasePrice: Double?
    let purchaseDate: String?
    let calibrationResult: String?
    let responsiblePerson: String?
    let manufacturer: String?
    let model: String?
    let graduationValue: String?
    let testRange: String?
    let allowableError: String?
    let serviceLife: Int?
    let calDate: String?
    let nextDate: String?
    let validity: String?
    let daysPassed: Int?
    let status: String?
    let remark: String?
    let useStatus: String?

    var displayName: String {
        let value = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "未命名设备" : value
    }
}

struct DeviceCalibrationPayload: Codable {
    let calDate: String?
    let cycle: Int?
    let calibrationResult: String?
    let remark: String?
}

struct DeviceUpdatePayload: Codable {
    let name: String?
    let metricNo: String?
    let assetNo: String?
    let abcClass: String?
    let dept: String?
    let location: String?
    let cycle: Int?
    let calDate: String?
    let status: String?
    let remark: String?
    let useStatus: String?
    let serialNo: String?
    let purchasePrice: Double?
    let purchaseDate: String?
    let calibrationResult: String?
    let responsiblePerson: String?
    let manufacturer: String?
    let model: String?
    let graduationValue: String?
    let testRange: String?
    let allowableError: String?
}

struct PageResult<T: Codable>: Codable {
    let content: [T]?
    let totalElements: Int64?
    let totalPages: Int?
    let page: Int?
    let size: Int?
    let summaryCounts: [String: Int64]?
    let useStatusSummary: [String: Int64]?
}

struct AuditRecordDto: Codable, Identifiable {
    let id: Int64?
    let type: String?
    let entityType: String?
    let entityId: Int64?
    let submittedBy: String?
    let submittedAt: String?
    let status: String?
    let approvedBy: String?
    let approvedAt: String?
    let originalData: String?
    let newData: String?
    let remark: String?
    let rejectReason: String?

    var statusText: String {
        (status ?? "UNKNOWN").uppercased()
    }
}

struct RejectRequest: Codable {
    let reason: String?
}

struct SimpleMessageResponse: Codable {
    let message: String?
}

struct FileAccessDto: Codable {
    let readOnly: Bool?
    let canWrite: Bool?
}

struct UserFileItemDto: Codable, Identifiable {
    let id: Int64?
    let userId: String?
    let parentId: Int64?
    let name: String?
    let type: String?
    let filePath: String?
    let fileSize: Int64?
    let mimeType: String?
    let createdAt: String?
    let readOnly: Bool?
    let shared: Bool?
    let grantRootId: Int64?
    let sharedOwner: String?

    var isFolder: Bool {
        type?.uppercased() == "FOLDER"
    }

    var displayName: String {
        let text = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "未命名" : text
    }
}

struct FileListResponseDto: Codable {
    let items: [UserFileItemDto]?
    let access: FileAccessDto?
}

struct BreadcrumbItemDto: Codable {
    let id: Int64?
    let name: String?
    let readOnly: Bool?
}

struct SettingsDto: Codable {
    let warningDays: Int?
    let expiredDays: Int?
    let autoLedgerExportEnabled: Bool?
    let databaseBackupEnabled: Bool?
    let cmsRootPath: String?
    let ledgerExportPath: String?
    let databaseBackupPath: String?
}

struct MaintenanceRunResultDto: Codable {
    let ledgerExported: Bool?
    let databaseBackedUp: Bool?
    let ledgerExportPath: String?
    let databaseBackupPath: String?
    let message: String?
}

struct DeviceStatusDto: Codable, Identifiable {
    let id: Int64?
    let name: String?
    let sortOrder: Int?
}

struct DepartmentDto: Codable, Identifiable {
    let id: Int64?
    let name: String?
    let code: String?
    let description: String?
    let sortOrder: Int?
    let parentId: Int64?
    let createdAt: String?
}

struct UserFolderGrantDto: Codable {
    let folderId: Int64?
    let folderName: String?
    let folderPath: String?
}

struct UserDto: Codable, Identifiable {
    let id: Int64?
    let username: String?
    let role: String?
    let department: String?
    let departments: [String]?
    let permissions: [String]?
    let readonlyFolders: [UserFolderGrantDto]?
    let readonlyFolderIds: [Int64]?
    let createdAt: String?
}

struct UserCreatePayload: Codable {
    let username: String
    let password: String
    let role: String
    let departments: [String]
    let permissions: [String]
    let readonlyFolderIds: [Int64]
}

struct UserRolePermissionPayload: Codable {
    let role: String
    let departments: [String]
    let permissions: [String]
    let readonlyFolderIds: [Int64]
}

struct PasswordResetPayload: Codable {
    let password: String
}

struct ChangeRecordItemDto: Codable, Identifiable {
    let id: Int64?
    let type: String?
    let status: String?
    let entityType: String?
    let entityId: Int64?
    let submittedBy: String?
    let submittedAt: String?
    let approvedBy: String?
    let approvedAt: String?
    let remark: String?
    let rejectReason: String?
    let deviceName: String?
    let metricNo: String?
    let changedFieldCount: Int?
}

struct ChangeRecordStatsDto: Codable {
    let total: Int64?
    let pending: Int64?
    let approved: Int64?
    let rejected: Int64?
    let createCount: Int64?
    let updateCount: Int64?
    let deleteCount: Int64?
    let submitterCount: Int64?
}

struct ChangeRecordPageDto: Codable {
    let items: [ChangeRecordItemDto]?
    let total: Int64?
    let page: Int?
    let size: Int?
    let stats: ChangeRecordStatsDto?
}

struct WebDavMountDto: Codable, Identifiable {
    let id: Int64?
    let userId: String?
    let name: String?
    let url: String?
    let username: String?
    let password: String?
    let createdAt: String?
}

struct WebDavFileDto: Codable, Identifiable {
    let name: String?
    let path: String?
    let isDirectory: Bool?
    let size: Int64?
    let contentType: String?
    let modified: Int64?

    var id: String {
        let fallback = UUID().uuidString
        return path ?? name ?? fallback
    }
}

struct WebDavTestRequest: Codable {
    let url: String
    let username: String?
    let password: String?
}

struct WebDavTestResponse: Codable {
    let success: Bool?
}
