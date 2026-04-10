package com.metrology.controller;

import com.metrology.dto.ApiErrorResponse;
import com.metrology.dto.FileMetadataDto;
import com.metrology.entity.UserFile;
import com.metrology.service.PermissionService;
import com.metrology.service.UserFileService;
import lombok.extern.slf4j.Slf4j;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.InvalidMediaTypeException;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.util.StringUtils;

import java.io.File;
import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.LocalDateTime;
import java.util.Locale;
import java.util.Map;

@RestController
@RequestMapping("/api/files")
@RequiredArgsConstructor
@Slf4j
public class UserFileController {

    private final UserFileService service;
    private final PermissionService permissionService;

    private ResponseEntity<ApiErrorResponse> checkFileAccess(String username) {
        if (!permissionService.hasFileModuleAccess(username)) {
            return error(HttpStatus.FORBIDDEN, "FILE_MODULE_FORBIDDEN", "当前账号没有文件模块访问权限", "/api/files");
        }
        return null;
    }

    private ResponseEntity<ApiErrorResponse> checkFileWriteAccess(String username) {
        if (!permissionService.hasPermission(username, PermissionService.FILE_ACCESS)) {
            return error(HttpStatus.FORBIDDEN, "FILE_WRITE_FORBIDDEN", "当前账号只有文件只读权限", "/api/files");
        }
        return null;
    }

    private ResponseEntity<ApiErrorResponse> error(HttpStatus status, String code, String message, String path) {
        return ResponseEntity.status(status)
                .body(ApiErrorResponse.of(status.value(), code, message, path));
    }

    private ResponseEntity<ApiErrorResponse> badRequest(String code, Exception ex, String path) {
        String message = ex.getMessage() == null || ex.getMessage().isBlank()
                ? "请求参数无效"
                : ex.getMessage();
        return error(HttpStatus.BAD_REQUEST, code, message, path);
    }

    @GetMapping
    public ResponseEntity<?> list(
            @AuthenticationPrincipal UserDetails u,
            @RequestParam(required = false) Long parentId) {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        try {
            return ResponseEntity.ok(service.list(u.getUsername(), parentId));
        } catch (IllegalArgumentException e) {
            return badRequest("FILE_REQUEST_INVALID", e, "/api/files");
        }
    }

    @GetMapping("/search")
    public ResponseEntity<?> search(
            @AuthenticationPrincipal UserDetails u,
            @RequestParam String q) {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        return ResponseEntity.ok(service.search(u.getUsername(), q));
    }

    @GetMapping("/breadcrumb")
    public ResponseEntity<?> breadcrumb(
            @AuthenticationPrincipal UserDetails u,
            @RequestParam Long folderId) {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        try {
            return ResponseEntity.ok(service.getBreadcrumb(u.getUsername(), folderId));
        } catch (IllegalArgumentException e) {
            return badRequest("FILE_REQUEST_INVALID", e, "/api/files");
        }
    }

    @PostMapping("/folder")
    public ResponseEntity<?> createFolder(
            @AuthenticationPrincipal UserDetails u,
            @RequestBody Map<String, Object> body) {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        check = checkFileWriteAccess(u.getUsername());
        if (check != null) return check;
        try {
            String name = (String) body.get("name");
            Long parentId = body.get("parentId") != null
                    ? ((Number) body.get("parentId")).longValue() : null;
            return ResponseEntity.ok(service.createFolder(u.getUsername(), parentId, name));
        } catch (IllegalArgumentException e) {
            return badRequest("FILE_REQUEST_INVALID", e, "/api/files");
        }
    }

    @PostMapping("/upload")
    public ResponseEntity<?> upload(
            @AuthenticationPrincipal UserDetails u,
            @RequestParam("file") MultipartFile file,
            @RequestParam(required = false) Long parentId) throws IOException {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        check = checkFileWriteAccess(u.getUsername());
        if (check != null) return check;
        return ResponseEntity.ok(service.uploadFile(u.getUsername(), parentId, file));
    }

    @PostMapping("/scan-sync")
    public ResponseEntity<?> scanSync(
            @AuthenticationPrincipal UserDetails u,
            @RequestBody(required = false) Map<String, Object> body) {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        check = checkFileWriteAccess(u.getUsername());
        if (check != null) return check;
        try {
            Long parentId = body != null && body.get("parentId") != null
                    ? ((Number) body.get("parentId")).longValue()
                    : null;
            return ResponseEntity.ok(service.scanSync(u.getUsername(), parentId));
        } catch (IllegalArgumentException e) {
            return badRequest("FILE_REQUEST_INVALID", e, "/api/files");
        }
    }

    @GetMapping("/grantable-folders")
    public ResponseEntity<?> grantableFolders(@AuthenticationPrincipal UserDetails u) {
        ResponseEntity<?> check = checkFileWriteAccess(u.getUsername());
        if (check != null) return check;
        try {
            return ResponseEntity.ok(service.listGrantableFolders(u.getUsername()));
        } catch (IllegalArgumentException e) {
            return badRequest("FILE_REQUEST_INVALID", e, "/api/files");
        }
    }

    @GetMapping("/{id}/meta")
    public ResponseEntity<?> metadata(
            @AuthenticationPrincipal UserDetails u,
            @PathVariable Long id
    ) {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        try {
            UserFile file = service.getFile(u.getUsername(), id);
            File target = service.resolveDownloadTarget(file);
            return ResponseEntity.ok()
                    .header(HttpHeaders.CACHE_CONTROL, "private, max-age=15, stale-while-revalidate=45")
                    .lastModified(target.lastModified())
                    .body(buildMetadata(file, target));
        } catch (IllegalArgumentException e) {
            return badRequest("FILE_REQUEST_INVALID", e, "/api/files");
        }
    }

    @GetMapping("/{id}/download")
    public ResponseEntity<?> download(
            @AuthenticationPrincipal UserDetails u,
            @PathVariable Long id,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch,
            @RequestHeader(value = HttpHeaders.RANGE, required = false) String rangeHeader) throws IOException {
        if (!permissionService.hasFileModuleAccess(u.getUsername())) {
            return error(HttpStatus.FORBIDDEN, "FILE_MODULE_FORBIDDEN", "当前账号没有文件模块访问权限", "/api/files/" + id + "/download");
        }
        UserFile f = service.getFile(u.getUsername(), id);
        File target = service.resolveDownloadTarget(f);
        String encoded = URLEncoder.encode(f.getName(), StandardCharsets.UTF_8).replace("+", "%20");
        MediaType mediaType = resolveResponseMediaType(f);
        String etag = buildWeakEtag(target);

        if (matchesIfNoneMatch(ifNoneMatch, etag)) {
            return ResponseEntity.status(HttpStatus.NOT_MODIFIED)
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + encoded)
                    .header(HttpHeaders.ETAG, etag)
                    .lastModified(target.lastModified())
                    .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                    .header(HttpHeaders.CACHE_CONTROL, "private, max-age=0, must-revalidate")
                    .build();
        }
        if (StringUtils.hasText(rangeHeader)) {
            log.info("Ignoring range request for file id={}, name={}, range={} and falling back to full download for stability",
                    f.getId(), f.getName(), rangeHeader);
        }

        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + encoded)
                .header(HttpHeaders.ETAG, etag)
                .lastModified(target.lastModified())
                .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                .header(HttpHeaders.CACHE_CONTROL, "private, max-age=0, must-revalidate")
                .contentType(mediaType)
                .contentLength(target.length())
                .body(new FileSystemResource(target));
    }

    private MediaType resolveResponseMediaType(UserFile file) {
        String rawMimeType = file.getMimeType();
        if (!StringUtils.hasText(rawMimeType)) {
            return MediaType.APPLICATION_OCTET_STREAM;
        }
        try {
            return MediaType.parseMediaType(rawMimeType);
        } catch (InvalidMediaTypeException ex) {
            log.warn("Invalid mimeType '{}' for file id={}, name={}; using application/octet-stream",
                    rawMimeType, file.getId(), file.getName(), ex);
            return MediaType.APPLICATION_OCTET_STREAM;
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(
            @AuthenticationPrincipal UserDetails u,
            @PathVariable Long id) {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        check = checkFileWriteAccess(u.getUsername());
        if (check != null) return check;
        try {
            service.delete(u.getUsername(), id);
            return ResponseEntity.ok().build();
        } catch (IllegalArgumentException e) {
            return badRequest("FILE_REQUEST_INVALID", e, "/api/files");
        }
    }

    @PutMapping("/{id}/rename")
    public ResponseEntity<?> rename(
            @AuthenticationPrincipal UserDetails u,
            @PathVariable Long id,
            @RequestBody Map<String, String> body) {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        check = checkFileWriteAccess(u.getUsername());
        if (check != null) return check;
        try {
            return ResponseEntity.ok(service.rename(u.getUsername(), id, body.get("name")));
        } catch (IllegalArgumentException e) {
            return badRequest("FILE_REQUEST_INVALID", e, "/api/files");
        }
    }

    @PutMapping("/{id}/move")
    public ResponseEntity<?> move(
            @AuthenticationPrincipal UserDetails u,
            @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        check = checkFileWriteAccess(u.getUsername());
        if (check != null) return check;
        try {
            Long parentId = body.get("parentId") != null
                    ? ((Number) body.get("parentId")).longValue() : null;
            return ResponseEntity.ok(service.move(u.getUsername(), id, parentId));
        } catch (IllegalArgumentException e) {
            return badRequest("FILE_REQUEST_INVALID", e, "/api/files");
        }
    }

    @GetMapping("/{id}/share")
    public ResponseEntity<?> getShare(
            @AuthenticationPrincipal UserDetails u,
            @PathVariable Long id) {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        check = checkFileWriteAccess(u.getUsername());
        if (check != null) return check;
        try {
            return ResponseEntity.ok(service.getShareConfig(u.getUsername(), id));
        } catch (IllegalArgumentException e) {
            return badRequest("FILE_REQUEST_INVALID", e, "/api/files");
        }
    }

    @PostMapping("/{id}/share")
    public ResponseEntity<?> saveShare(
            @AuthenticationPrincipal UserDetails u,
            @PathVariable Long id,
            @RequestBody Map<String, Object> body) {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        check = checkFileWriteAccess(u.getUsername());
        if (check != null) return check;
        try {
            Boolean allowDownload = body.get("allowDownload") == null
                    ? Boolean.TRUE
                    : Boolean.parseBoolean(String.valueOf(body.get("allowDownload")));
            Boolean passwordProtected = body.get("passwordProtected") != null
                    && Boolean.parseBoolean(String.valueOf(body.get("passwordProtected")));
            String password = body.get("password") != null ? String.valueOf(body.get("password")) : null;
            String shareToken = body.get("shareToken") != null ? String.valueOf(body.get("shareToken")) : null;
            LocalDateTime expiresAt = null;
            if (body.get("expiresAt") != null && !String.valueOf(body.get("expiresAt")).isBlank()) {
                expiresAt = LocalDateTime.parse(String.valueOf(body.get("expiresAt")));
            }
            return ResponseEntity.ok(service.saveShare(
                    u.getUsername(),
                    id,
                    allowDownload,
                    expiresAt,
                    passwordProtected,
                    password,
                    shareToken
            ));
        } catch (IllegalArgumentException e) {
            return badRequest("FILE_REQUEST_INVALID", e, "/api/files");
        }
    }

    @DeleteMapping("/{id}/share")
    public ResponseEntity<?> disableShare(
            @AuthenticationPrincipal UserDetails u,
            @PathVariable Long id) {
        ResponseEntity<?> check = checkFileAccess(u.getUsername());
        if (check != null) return check;
        check = checkFileWriteAccess(u.getUsername());
        if (check != null) return check;
        try {
            service.disableShare(u.getUsername(), id);
            return ResponseEntity.ok().build();
        } catch (IllegalArgumentException e) {
            return badRequest("FILE_REQUEST_INVALID", e, "/api/files");
        }
    }

    private String buildWeakEtag(File file) {
        return "W/\"" + Long.toHexString(file.lastModified()) + "-" + Long.toHexString(file.length()) + "\"";
    }

    private FileMetadataDto buildMetadata(UserFile file, File target) {
        FilePreviewProfile previewProfile = buildPreviewProfile(file.getName(), file.getMimeType(), target.length());
        return new FileMetadataDto(
                file.getId(),
                file.getName(),
                target.length(),
                file.getMimeType(),
                buildWeakEtag(target),
                Instant.ofEpochMilli(target.lastModified()).toString(),
                Boolean.TRUE,
                previewProfile.previewType(),
                previewProfile.previewMode(),
                previewProfile.previewSupported(),
                previewProfile.autoPreview(),
                previewProfile.previewMessage(),
                previewProfile.largeFile()
        );
    }

    private FilePreviewProfile buildPreviewProfile(String fileName, String mimeType, long fileSize) {
        String ext = extensionOf(fileName);
        String mime = mimeType == null ? "" : mimeType.toLowerCase(Locale.ROOT);

        if (isImage(ext, mime)) {
            return new FilePreviewProfile(
                    "image",
                    "inline",
                    true,
                    true,
                    fileSize > 40L * 1024 * 1024 ? "图片较大，首次预览可能稍慢。" : null,
                    fileSize > 40L * 1024 * 1024
            );
        }
        if (isPdf(ext, mime)) {
            return new FilePreviewProfile(
                    "pdf",
                    "inline",
                    true,
                    true,
                    fileSize > 60L * 1024 * 1024 ? "PDF 较大，建议优先外部打开或下载查看。" : null,
                    fileSize > 60L * 1024 * 1024
            );
        }
        if (isVideo(ext, mime)) {
            return new FilePreviewProfile(
                    "video",
                    "inline",
                    true,
                    true,
                    fileSize > 120L * 1024 * 1024 ? "视频文件较大，在线播放可能较慢。" : null,
                    fileSize > 120L * 1024 * 1024
            );
        }
        if (isAudio(ext, mime)) {
            return new FilePreviewProfile(
                    "audio",
                    "inline",
                    true,
                    true,
                    fileSize > 80L * 1024 * 1024 ? "音频文件较大，首次加载可能稍慢。" : null,
                    fileSize > 80L * 1024 * 1024
            );
        }
        if (isText(ext, mime)) {
            boolean tooLarge = fileSize > 2L * 1024 * 1024;
            return new FilePreviewProfile(
                    "text",
                    tooLarge ? "download-only" : "inline",
                    !tooLarge,
                    !tooLarge,
                    tooLarge ? "文本文件较大，建议直接下载后查看。" : null,
                    tooLarge
            );
        }
        if (isOffice(ext)) {
            return new FilePreviewProfile(
                    "office",
                    "office-online",
                    true,
                    false,
                    "Office 文件建议使用在线预览或外部应用打开。",
                    fileSize > 30L * 1024 * 1024
            );
        }
        if (isArchive(ext)) {
            return new FilePreviewProfile(
                    "archive",
                    "download-only",
                    false,
                    false,
                    "压缩文件暂不支持在线预览，请下载后查看。",
                    fileSize > 0
            );
        }
        return new FilePreviewProfile(
                "binary",
                "download-only",
                false,
                false,
                "当前文件类型暂不支持在线预览，请下载或外部打开。",
                fileSize > 0
        );
    }

    private String extensionOf(String fileName) {
        if (!StringUtils.hasText(fileName)) {
            return "";
        }
        int dotIndex = fileName.lastIndexOf('.');
        if (dotIndex < 0 || dotIndex == fileName.length() - 1) {
            return "";
        }
        return fileName.substring(dotIndex + 1).toLowerCase(Locale.ROOT);
    }

    private boolean isImage(String ext, String mime) {
        return mime.startsWith("image/") || switch (ext) {
            case "jpg", "jpeg", "png", "gif", "bmp", "webp", "svg", "heic", "heif", "tif", "tiff" -> true;
            default -> false;
        };
    }

    private boolean isPdf(String ext, String mime) {
        return "pdf".equals(ext) || mime.contains("pdf");
    }

    private boolean isVideo(String ext, String mime) {
        return mime.startsWith("video/") || switch (ext) {
            case "mp4", "mov", "m4v", "avi", "wmv", "mkv", "flv", "webm" -> true;
            default -> false;
        };
    }

    private boolean isAudio(String ext, String mime) {
        return mime.startsWith("audio/") || switch (ext) {
            case "mp3", "wav", "m4a", "aac", "flac", "ogg", "wma" -> true;
            default -> false;
        };
    }

    private boolean isText(String ext, String mime) {
        return mime.startsWith("text/")
                || mime.contains("json")
                || mime.contains("xml")
                || switch (ext) {
                    case "txt", "md", "json", "csv", "log", "xml", "html", "htm", "js", "ts",
                         "css", "java", "sql", "yml", "yaml", "kt", "swift", "py", "sh" -> true;
                    default -> false;
                };
    }

    private boolean isOffice(String ext) {
        return switch (ext) {
            case "doc", "docx", "xls", "xlsx", "ppt", "pptx" -> true;
            default -> false;
        };
    }

    private boolean isArchive(String ext) {
        return switch (ext) {
            case "zip", "rar", "7z", "tar", "gz", "bz2", "xz" -> true;
            default -> false;
        };
    }

    private record FilePreviewProfile(
            String previewType,
            String previewMode,
            boolean previewSupported,
            boolean autoPreview,
            String previewMessage,
            boolean largeFile
    ) {
    }

    private boolean matchesIfNoneMatch(String ifNoneMatch, String etag) {
        if (!StringUtils.hasText(ifNoneMatch) || !StringUtils.hasText(etag)) {
            return false;
        }
        String normalizedEtag = normalizeEtag(etag);
        for (String token : ifNoneMatch.split(",")) {
            String candidate = token.trim();
            if ("*".equals(candidate)) {
                return true;
            }
            if (normalizedEtag.equals(normalizeEtag(candidate))) {
                return true;
            }
        }
        return false;
    }

    private String normalizeEtag(String value) {
        if (value == null) return "";
        String normalized = value.trim();
        if (normalized.startsWith("W/")) {
            normalized = normalized.substring(2).trim();
        }
        return normalized;
    }
}



