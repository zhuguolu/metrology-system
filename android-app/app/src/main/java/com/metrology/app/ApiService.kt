package com.metrology.app

import retrofit2.http.Body
import retrofit2.http.DELETE
import retrofit2.http.GET
import retrofit2.http.Multipart
import retrofit2.http.POST
import retrofit2.http.Part
import retrofit2.http.PUT
import retrofit2.http.Path
import retrofit2.http.Query
import retrofit2.http.Streaming
import retrofit2.Call
import okhttp3.MultipartBody
import okhttp3.ResponseBody

interface ApiService {
    @POST("api/auth/login")
    suspend fun login(@Body body: LoginRequest): LoginResponse

    @GET("api/auth/me")
    suspend fun me(): LoginResponse

    @GET("api/devices/dashboard")
    suspend fun dashboard(): DashboardStats

    @GET("api/devices/paged")
    suspend fun devicesPaged(
        @Query("search") search: String? = null,
        @Query("assetNo") assetNo: String? = null,
        @Query("serialNo") serialNo: String? = null,
        @Query("dept") dept: String? = null,
        @Query("validity") validity: String? = null,
        @Query("responsiblePerson") responsiblePerson: String? = null,
        @Query("useStatus") useStatus: String? = null,
        @Query("nextDateFrom") nextDateFrom: String? = null,
        @Query("nextDateTo") nextDateTo: String? = null,
        @Query("todoOnly") todoOnly: Boolean = false,
        @Query("page") page: Int = 1,
        @Query("size") size: Int = 20
    ): PageResult<DeviceDto>

    @PUT("api/devices/{id}")
    suspend fun updateDevice(
        @Path("id") id: Long,
        @Body body: DeviceUpdatePayload
    ): DeviceDto

    @PUT("api/devices/{id}/calibration")
    suspend fun updateDeviceCalibration(
        @Path("id") id: Long,
        @Body body: DeviceCalibrationPayload
    ): DeviceDto

    @DELETE("api/devices/{id}")
    suspend fun deleteDevice(@Path("id") id: Long)

    @GET("api/audit/pending")
    suspend fun pendingAudit(): List<AuditRecordDto>

    @GET("api/audit/my")
    suspend fun myAudit(): List<AuditRecordDto>

    @GET("api/audit")
    suspend fun allAudit(
        @Query("page") page: Int = 1,
        @Query("size") size: Int = 20
    ): PageResult<AuditRecordDto>

    @GET("api/audit/{id}")
    suspend fun auditDetail(@Path("id") id: Long): AuditRecordDto

    @POST("api/audit/{id}/approve")
    suspend fun approveAudit(@Path("id") id: Long, @Body body: Map<String, String> = emptyMap()): AuditRecordDto

    @POST("api/audit/{id}/reject")
    suspend fun rejectAudit(@Path("id") id: Long, @Body body: RejectRequest): AuditRecordDto

    @GET("api/settings")
    suspend fun settings(): SettingsDto

    @PUT("api/settings")
    suspend fun saveSettings(@Body body: SettingsDto): SettingsDto

    @POST("api/settings/maintenance/run")
    suspend fun runMaintenanceNow(): MaintenanceRunResultDto

    @GET("api/device-statuses")
    suspend fun deviceStatuses(): List<DeviceStatusDto>

    @POST("api/device-statuses")
    suspend fun createDeviceStatus(@Body body: Map<String, String>): DeviceStatusDto

    @PUT("api/device-statuses/{id}")
    suspend fun updateDeviceStatus(@Path("id") id: Long, @Body body: Map<String, String>): DeviceStatusDto

    @DELETE("api/device-statuses/{id}")
    suspend fun deleteDeviceStatus(@Path("id") id: Long)

    @GET("api/departments")
    suspend fun departments(@Query("search") search: String? = null): List<DepartmentDto>

    @POST("api/departments")
    suspend fun createDepartment(@Body body: Map<String, String>): DepartmentDto

    @PUT("api/departments/{id}")
    suspend fun updateDepartment(@Path("id") id: Long, @Body body: Map<String, String>): DepartmentDto

    @DELETE("api/departments/{id}")
    suspend fun deleteDepartment(@Path("id") id: Long)

    @GET("api/users")
    suspend fun users(): List<UserDto>

    @POST("api/users")
    suspend fun createUser(@Body body: UserCreatePayload): SimpleMessageResponse

    @PUT("api/users/{id}/role-permissions")
    suspend fun updateUserRolePermissions(
        @Path("id") id: Long,
        @Body body: UserRolePermissionPayload
    ): SimpleMessageResponse

    @PUT("api/users/{id}/password")
    suspend fun resetUserPassword(@Path("id") id: Long, @Body body: PasswordResetPayload): SimpleMessageResponse

    @DELETE("api/users/{id}")
    suspend fun deleteUser(@Path("id") id: Long)

    @GET("api/change-records")
    suspend fun changeRecords(
        @Query("page") page: Int = 1,
        @Query("size") size: Int = 20,
        @Query("keyword") keyword: String? = null,
        @Query("type") type: String? = null,
        @Query("status") status: String? = null,
        @Query("submittedBy") submittedBy: String? = null,
        @Query("dateFrom") dateFrom: String? = null,
        @Query("dateTo") dateTo: String? = null
    ): ChangeRecordPageDto

    @GET("api/change-records/{id}")
    suspend fun changeRecordDetail(@Path("id") id: Long): AuditRecordDto

    @GET("api/files")
    suspend fun files(@Query("parentId") parentId: Long? = null): FileListResponseDto

    @GET("api/files/search")
    suspend fun searchFiles(@Query("q") query: String): List<UserFileItemDto>

    @GET("api/files/breadcrumb")
    suspend fun fileBreadcrumb(@Query("folderId") folderId: Long): List<BreadcrumbItemDto>

    @POST("api/files/folder")
    suspend fun createFolder(@Body body: CreateFolderRequest): UserFileItemDto

    @POST("api/files/scan-sync")
    suspend fun scanSync(@Body body: ParentFolderRequest = ParentFolderRequest()): ScanSyncResultDto

    @Multipart
    @POST("api/files/upload")
    suspend fun uploadFile(
        @Part file: MultipartBody.Part,
        @Query("parentId") parentId: Long? = null
    ): UserFileItemDto

    @Streaming
    @GET("api/files/{id}/download")
    fun downloadFile(@Path("id") id: Long): Call<ResponseBody>

    @DELETE("api/files/{id}")
    suspend fun deleteFile(@Path("id") id: Long)

    @PUT("api/files/{id}/rename")
    suspend fun renameFile(@Path("id") id: Long, @Body body: RenameRequest): UserFileItemDto

    @PUT("api/files/{id}/move")
    suspend fun moveFile(@Path("id") id: Long, @Body body: ParentFolderRequest): UserFileItemDto

    @GET("api/webdav/mounts")
    suspend fun webDavMounts(): List<WebDavMountDto>

    @POST("api/webdav/mounts")
    suspend fun createWebDavMount(@Body body: Map<String, String>): WebDavMountDto

    @PUT("api/webdav/mounts/{id}")
    suspend fun updateWebDavMount(@Path("id") id: Long, @Body body: Map<String, String>): WebDavMountDto

    @DELETE("api/webdav/mounts/{id}")
    suspend fun deleteWebDavMount(@Path("id") id: Long)

    @POST("api/webdav/mounts/test")
    suspend fun testWebDavConnection(@Body body: WebDavTestRequest): WebDavTestResponse

    @GET("api/webdav/browse")
    suspend fun webDavBrowse(
        @Query("mountId") mountId: Long,
        @Query("path") path: String? = null
    ): List<WebDavFileDto>

    @Streaming
    @GET("api/webdav/download")
    suspend fun webDavDownload(
        @Query("mountId") mountId: Long,
        @Query("path") path: String,
        @Query("filename") filename: String? = null
    ): ResponseBody

    @Multipart
    @POST("api/webdav/upload")
    suspend fun webDavUpload(
        @Query("mountId") mountId: Long,
        @Query("path") path: String,
        @Part file: MultipartBody.Part
    ): SimpleMessageResponse
}
