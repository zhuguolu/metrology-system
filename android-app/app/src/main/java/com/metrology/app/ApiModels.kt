package com.metrology.app

import com.google.gson.annotations.SerializedName

data class LoginRequest(
    val username: String,
    val password: String
)

data class LoginResponse(
    val token: String?,
    val username: String?,
    val userId: Long?,
    val role: String?,
    val permissions: List<String>?,
    val department: String?,
    val departments: List<String>?,
    val fileReadonlyFolders: List<Map<String, Any?>>?
)

data class DashboardStats(
    val total: Long?,
    val dueThisMonth: Long?,
    val expired: Long?,
    val warning: Long?,
    val valid: Long?,
    val monthlyTrend: List<Map<String, Any?>>?,
    val deptStats: List<Map<String, Any?>>?
)

data class DeviceDto(
    val id: Long?,
    val name: String?,
    val metricNo: String?,
    val assetNo: String?,
    val abcClass: String?,
    val dept: String?,
    val location: String?,
    val cycle: Int?,
    val serialNo: String?,
    val purchasePrice: Double?,
    val purchaseDate: String?,
    val calibrationResult: String?,
    val responsiblePerson: String?,
    val manufacturer: String?,
    val model: String?,
    val graduationValue: String?,
    val testRange: String?,
    val allowableError: String?,
    val serviceLife: Int?,
    val calDate: String?,
    val nextDate: String?,
    val validity: String?,
    val daysPassed: Int?,
    val status: String?,
    val remark: String?,
    val imagePath: String?,
    val imageName: String?,
    val imagePath2: String?,
    val imageName2: String?,
    val certPath: String?,
    val certName: String?,
    val useStatus: String?
)

data class DeviceUpdatePayload(
    val name: String?,
    val metricNo: String?,
    val assetNo: String?,
    val abcClass: String?,
    val dept: String?,
    val location: String?,
    val cycle: Int?,
    val calDate: String?,
    val status: String?,
    val remark: String?,
    val useStatus: String?,
    val serialNo: String?,
    val purchasePrice: Double?,
    val purchaseDate: String?,
    val calibrationResult: String?,
    val responsiblePerson: String?,
    val manufacturer: String?,
    val model: String?,
    val graduationValue: String?,
    val testRange: String?,
    val allowableError: String?
)

data class DeviceCalibrationPayload(
    val calDate: String?,
    val cycle: Int?,
    val calibrationResult: String?,
    val remark: String?
)

data class PageResult<T>(
    val content: List<T>?,
    val totalElements: Long?,
    val totalPages: Int?,
    val page: Int?,
    val size: Int?,
    val summaryCounts: Map<String, Long>?,
    val useStatusSummary: Map<String, Long>?
)

data class AuditRecordDto(
    val id: Long?,
    val type: String?,
    val entityType: String?,
    val entityId: Long?,
    val submittedBy: String?,
    val submittedAt: String?,
    val status: String?,
    val approvedBy: String?,
    val approvedAt: String?,
    val originalData: String?,
    val newData: String?,
    val remark: String?,
    val rejectReason: String?
)

data class SettingsDto(
    val warningDays: Int?,
    val expiredDays: Int?,
    val autoLedgerExportEnabled: Boolean?,
    val databaseBackupEnabled: Boolean?,
    val cmsRootPath: String?,
    val ledgerExportPath: String?,
    val databaseBackupPath: String?
)

data class MaintenanceRunResultDto(
    val ledgerExported: Boolean?,
    val databaseBackedUp: Boolean?,
    val ledgerExportPath: String?,
    val databaseBackupPath: String?,
    val message: String?
)

data class SimpleMessageResponse(
    val message: String?
)

data class RejectRequest(
    @SerializedName("reason")
    val reason: String?
)

data class DeviceStatusDto(
    val id: Long?,
    val name: String?,
    val sortOrder: Int?
)

data class DepartmentDto(
    val id: Long?,
    val name: String?,
    val code: String?,
    val description: String?,
    val sortOrder: Int?,
    val parentId: Long?,
    val createdAt: String?
)

data class UserFolderGrantDto(
    val folderId: Long?,
    val folderName: String?,
    val folderPath: String?
)

data class UserDto(
    val id: Long?,
    val username: String?,
    val role: String?,
    val department: String?,
    val departments: List<String>?,
    val permissions: List<String>?,
    val readonlyFolders: List<UserFolderGrantDto>?,
    val readonlyFolderIds: List<Long>?,
    val createdAt: String?
)

data class ChangeRecordItemDto(
    val id: Long?,
    val type: String?,
    val status: String?,
    val entityType: String?,
    val entityId: Long?,
    val submittedBy: String?,
    val submittedAt: String?,
    val approvedBy: String?,
    val approvedAt: String?,
    val remark: String?,
    val rejectReason: String?,
    val deviceName: String?,
    val metricNo: String?,
    val changedFieldCount: Int?
)

data class ChangeRecordStatsDto(
    val total: Long?,
    val pending: Long?,
    val approved: Long?,
    val rejected: Long?,
    val createCount: Long?,
    val updateCount: Long?,
    val deleteCount: Long?,
    val submitterCount: Long?
)

data class ChangeRecordPageDto(
    val items: List<ChangeRecordItemDto>?,
    val total: Long?,
    val page: Int?,
    val size: Int?,
    val stats: ChangeRecordStatsDto?
)

data class FileAccessDto(
    val readOnly: Boolean?,
    val canWrite: Boolean?
)

data class UserFileItemDto(
    val id: Long?,
    val userId: String?,
    val parentId: Long?,
    val name: String?,
    val type: String?,
    val filePath: String?,
    val fileSize: Long?,
    val mimeType: String?,
    val createdAt: String?,
    val readOnly: Boolean?,
    val shared: Boolean?,
    val grantRootId: Long?,
    val sharedOwner: String?
)

data class FileListResponseDto(
    val items: List<UserFileItemDto>?,
    val access: FileAccessDto?
)

data class BreadcrumbItemDto(
    val id: Long?,
    val name: String?,
    val readOnly: Boolean?
)

data class CreateFolderRequest(
    val name: String,
    val parentId: Long?
)

data class ParentFolderRequest(
    val parentId: Long? = null
)

data class RenameRequest(
    val name: String
)

data class ScanSyncResultDto(
    val path: String?,
    val foldersCreated: Int?,
    val foldersUpdated: Int?,
    val filesCreated: Int?,
    val filesUpdated: Int?,
    val foldersDeleted: Int?,
    val filesDeleted: Int?,
    val unchanged: Int?,
    val conflicts: Int?
)

data class WebDavMountDto(
    val id: Long?,
    val userId: String?,
    val name: String?,
    val url: String?,
    val username: String?,
    val password: String?,
    val createdAt: String?
)

data class WebDavFileDto(
    val name: String?,
    val path: String?,
    val isDirectory: Boolean?,
    val size: Long?,
    val contentType: String?,
    val modified: Long?
)

data class WebDavTestRequest(
    val url: String,
    val username: String? = "",
    val password: String? = ""
)

data class WebDavTestResponse(
    val success: Boolean?
)

data class UserCreatePayload(
    val username: String,
    val password: String,
    val role: String,
    val departments: List<String>,
    val permissions: List<String>,
    val readonlyFolderIds: List<Long>
)

data class UserRolePermissionPayload(
    val role: String,
    val departments: List<String>,
    val permissions: List<String>,
    val readonlyFolderIds: List<Long>
)

data class PasswordResetPayload(
    val password: String
)
