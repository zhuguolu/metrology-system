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
