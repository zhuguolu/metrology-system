package com.metrology.app

import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.ResponseBody
import kotlinx.coroutines.suspendCancellableCoroutine
import retrofit2.Call
import retrofit2.Callback
import retrofit2.HttpException
import retrofit2.Response
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

class MetrologyRepository(
    private val apiServiceFactory: () -> ApiService,
    private val fileApiServiceFactory: (() -> ApiService)?,
    private val sessionManager: SessionManager
) {
    private val apiService: ApiService by lazy(LazyThreadSafetyMode.SYNCHRONIZED) {
        apiServiceFactory()
    }
    private val fileApiService: ApiService by lazy(LazyThreadSafetyMode.SYNCHRONIZED) {
        fileApiServiceFactory?.invoke() ?: apiService
    }

    private val defaultUserPermissions = listOf(
        "DEVICE_VIEW",
        "DEVICE_CREATE",
        "DEVICE_UPDATE",
        "DEVICE_DELETE",
        "CALIBRATION_RECORD",
        "STATUS_MANAGE",
        "FILE_ACCESS",
        "WEBDAV_ACCESS"
    )

    suspend fun login(username: String, password: String): LoginResponse {
        val response = apiService.login(LoginRequest(username = username, password = password))
        sessionManager.saveLogin(response)
        return response
    }

    suspend fun refreshMe(): LoginResponse {
        val response = apiService.me()
        sessionManager.saveLogin(response)
        return response
    }

    suspend fun dashboard(): DashboardStats = apiService.dashboard()

    suspend fun devicesPaged(
        mode: DeviceMode,
        search: String?,
        dept: String? = null,
        validity: String? = null,
        useStatus: String? = null,
        nextDateFrom: String? = null,
        nextDateTo: String? = null,
        page: Int,
        size: Int
    ): PageResult<DeviceDto> {
        val resolvedUseStatus = if (mode == DeviceMode.CALIBRATION) "正常" else useStatus
        return apiService.devicesPaged(
            search = search?.takeIf { it.isNotBlank() },
            dept = dept?.takeIf { it.isNotBlank() },
            validity = validity?.takeIf { it.isNotBlank() },
            useStatus = resolvedUseStatus?.takeIf { it.isNotBlank() },
            nextDateFrom = nextDateFrom?.takeIf { it.isNotBlank() },
            nextDateTo = nextDateTo?.takeIf { it.isNotBlank() },
            todoOnly = mode == DeviceMode.TODO,
            page = page,
            size = size
        )
    }

    suspend fun updateDevice(id: Long, payload: DeviceUpdatePayload): DeviceDto {
        return apiService.updateDevice(id = id, body = payload)
    }

    suspend fun updateDeviceCalibration(id: Long, payload: DeviceCalibrationPayload): DeviceDto {
        return apiService.updateDeviceCalibration(id = id, body = payload)
    }

    suspend fun deleteDevice(id: Long) = apiService.deleteDevice(id)

    suspend fun pendingAudit(): List<AuditRecordDto> = apiService.pendingAudit()

    suspend fun myAudit(): List<AuditRecordDto> = apiService.myAudit()

    suspend fun allAudit(page: Int, size: Int): PageResult<AuditRecordDto> = apiService.allAudit(page, size)

    suspend fun auditDetail(id: Long): AuditRecordDto = apiService.auditDetail(id)

    suspend fun approveAudit(id: Long) = apiService.approveAudit(id = id)

    suspend fun rejectAudit(id: Long, reason: String?) = apiService.rejectAudit(id = id, body = RejectRequest(reason))

    suspend fun settings(): SettingsDto = apiService.settings()

    suspend fun saveSettings(settings: SettingsDto): SettingsDto = apiService.saveSettings(settings)

    suspend fun runMaintenanceNow(): MaintenanceRunResultDto = apiService.runMaintenanceNow()

    suspend fun deviceStatuses(): List<DeviceStatusDto> = apiService.deviceStatuses()

    suspend fun createDeviceStatus(name: String): DeviceStatusDto {
        return apiService.createDeviceStatus(mapOf("name" to name))
    }

    suspend fun updateDeviceStatus(id: Long, name: String): DeviceStatusDto {
        return apiService.updateDeviceStatus(id, mapOf("name" to name))
    }

    suspend fun deleteDeviceStatus(id: Long) = apiService.deleteDeviceStatus(id)

    suspend fun departments(search: String? = null): List<DepartmentDto> = apiService.departments(search)

    suspend fun createDepartment(
        name: String,
        code: String,
        sortOrder: Int,
        parentId: Long?
    ): DepartmentDto {
        return apiService.createDepartment(
            mapOf(
                "name" to name,
                "code" to code,
                "sortOrder" to sortOrder.toString(),
                "parentId" to (parentId?.toString() ?: "")
            )
        )
    }

    suspend fun updateDepartment(
        id: Long,
        name: String,
        code: String,
        sortOrder: Int,
        parentId: Long?
    ): DepartmentDto {
        return apiService.updateDepartment(
            id = id,
            body = mapOf(
                "name" to name,
                "code" to code,
                "sortOrder" to sortOrder.toString(),
                "parentId" to (parentId?.toString() ?: "")
            )
        )
    }

    suspend fun deleteDepartment(id: Long) = apiService.deleteDepartment(id)

    suspend fun users(): List<UserDto> = apiService.users()

    suspend fun createUser(
        username: String,
        password: String,
        admin: Boolean,
        permissions: List<String> = defaultUserPermissions
    ): SimpleMessageResponse {
        return apiService.createUser(
            UserCreatePayload(
                username = username,
                password = password,
                role = if (admin) "ADMIN" else "USER",
                departments = emptyList(),
                permissions = if (admin) emptyList() else permissions.distinct(),
                readonlyFolderIds = emptyList()
            )
        )
    }

    suspend fun updateUserRolePermissions(
        id: Long,
        role: String,
        departments: List<String>,
        permissions: List<String>,
        readonlyFolderIds: List<Long>
    ): SimpleMessageResponse {
        return apiService.updateUserRolePermissions(
            id = id,
            body = UserRolePermissionPayload(
                role = role,
                departments = departments,
                permissions = permissions.distinct(),
                readonlyFolderIds = readonlyFolderIds.distinct()
            )
        )
    }

    suspend fun resetUserPassword(id: Long, password: String): SimpleMessageResponse {
        return apiService.resetUserPassword(id, PasswordResetPayload(password))
    }

    suspend fun deleteUser(id: Long) = apiService.deleteUser(id)

    suspend fun changeRecords(
        page: Int,
        size: Int,
        keyword: String?,
        type: String? = null,
        status: String? = null,
        submittedBy: String? = null,
        dateFrom: String? = null,
        dateTo: String? = null
    ): ChangeRecordPageDto {
        return apiService.changeRecords(
            page = page,
            size = size,
            keyword = keyword?.takeIf { it.isNotBlank() },
            type = type?.takeIf { it.isNotBlank() },
            status = status?.takeIf { it.isNotBlank() },
            submittedBy = submittedBy?.takeIf { it.isNotBlank() },
            dateFrom = dateFrom?.takeIf { it.isNotBlank() },
            dateTo = dateTo?.takeIf { it.isNotBlank() }
        )
    }

    suspend fun changeRecordDetail(id: Long): AuditRecordDto = apiService.changeRecordDetail(id)

    suspend fun files(parentId: Long?): FileListResponseDto = apiService.files(parentId)

    suspend fun searchFiles(query: String): List<UserFileItemDto> = apiService.searchFiles(query)

    suspend fun fileBreadcrumb(folderId: Long): List<BreadcrumbItemDto> = apiService.fileBreadcrumb(folderId)

    suspend fun createFolder(name: String, parentId: Long?): UserFileItemDto {
        return apiService.createFolder(CreateFolderRequest(name = name, parentId = parentId))
    }

    suspend fun scanSync(parentId: Long?): ScanSyncResultDto {
        return apiService.scanSync(ParentFolderRequest(parentId = parentId))
    }

    suspend fun uploadFile(parentId: Long?, fileName: String, mimeType: String?, bytes: ByteArray): UserFileItemDto {
        val requestBody = bytes.toRequestBody((mimeType ?: "application/octet-stream").toMediaTypeOrNull())
        val part = MultipartBody.Part.createFormData("file", fileName, requestBody)
        return apiService.uploadFile(file = part, parentId = parentId)
    }

    suspend fun downloadFile(
        id: Long,
        onCallCreated: ((Call<ResponseBody>) -> Unit)? = null
    ): ResponseBody {
        val call = fileApiService.downloadFile(id)
        onCallCreated?.invoke(call)
        val response = call.awaitResponse()
        if (!response.isSuccessful) {
            throw HttpException(response)
        }
        return response.body() ?: throw IllegalStateException("文件下载响应为空")
    }

    private suspend fun Call<ResponseBody>.awaitResponse(): Response<ResponseBody> =
        suspendCancellableCoroutine { continuation ->
            continuation.invokeOnCancellation { cancel() }
            enqueue(object : Callback<ResponseBody> {
                override fun onResponse(
                    call: Call<ResponseBody>,
                    response: Response<ResponseBody>
                ) {
                    if (continuation.isActive) {
                        continuation.resume(response)
                    }
                }

                override fun onFailure(call: Call<ResponseBody>, t: Throwable) {
                    if (continuation.isActive) {
                        continuation.resumeWithException(t)
                    }
                }
            })
        }

    suspend fun deleteFile(id: Long) = apiService.deleteFile(id)

    suspend fun renameFile(id: Long, name: String): UserFileItemDto {
        return apiService.renameFile(id = id, body = RenameRequest(name = name))
    }

    suspend fun moveFile(id: Long, parentId: Long?): UserFileItemDto {
        return apiService.moveFile(id = id, body = ParentFolderRequest(parentId = parentId))
    }

    suspend fun webDavMounts(): List<WebDavMountDto> = apiService.webDavMounts()

    suspend fun createWebDavMount(name: String, url: String, username: String, password: String): WebDavMountDto {
        return apiService.createWebDavMount(
            mapOf(
                "name" to name,
                "url" to url,
                "username" to username,
                "password" to password
            )
        )
    }

    suspend fun updateWebDavMount(id: Long, body: Map<String, String>): WebDavMountDto {
        return apiService.updateWebDavMount(id = id, body = body)
    }

    suspend fun deleteWebDavMount(id: Long) = apiService.deleteWebDavMount(id)

    suspend fun testWebDavConnection(url: String, username: String, password: String): Boolean {
        val result = apiService.testWebDavConnection(
            WebDavTestRequest(url = url, username = username, password = password)
        )
        return result.success == true
    }

    suspend fun webDavBrowse(mountId: Long, path: String?): List<WebDavFileDto> {
        return apiService.webDavBrowse(mountId = mountId, path = path)
    }

    suspend fun webDavDownload(mountId: Long, path: String, filename: String?): ResponseBody {
        return apiService.webDavDownload(mountId = mountId, path = path, filename = filename)
    }

    suspend fun webDavUpload(
        mountId: Long,
        path: String,
        fileName: String,
        mimeType: String?,
        bytes: ByteArray
    ): SimpleMessageResponse {
        val requestBody = bytes.toRequestBody((mimeType ?: "application/octet-stream").toMediaTypeOrNull())
        val part = MultipartBody.Part.createFormData("file", fileName, requestBody)
        return apiService.webDavUpload(mountId = mountId, path = path, file = part)
    }

    fun isLoggedIn(): Boolean = sessionManager.isLoggedIn()

    fun username(): String = sessionManager.username.orEmpty()

    fun isAdmin(): Boolean = sessionManager.role?.equals("ADMIN", ignoreCase = true) == true

    fun logout() = sessionManager.clear()
}

