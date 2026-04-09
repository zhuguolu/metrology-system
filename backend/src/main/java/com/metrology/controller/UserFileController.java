package com.metrology.controller;

import com.metrology.dto.FileMetadataDto;
import com.metrology.entity.UserFile;
import com.metrology.service.PermissionService;
import com.metrology.service.UserFileService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.ResourceRegion;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpRange;
import org.springframework.http.HttpStatus;
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
import java.util.Map;

@RestController
@RequestMapping("/api/files")
@RequiredArgsConstructor
public class UserFileController {

    private final UserFileService service;
    private final PermissionService permissionService;

    private ResponseEntity<?> checkFileAccess(String username) {
        if (!permissionService.hasFileModuleAccess(username)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("message", "当前账号没有文件模块访问权限"));
        }
        return null;
    }

    private ResponseEntity<?> checkFileWriteAccess(String username) {
        if (!permissionService.hasPermission(username, PermissionService.FILE_ACCESS)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("message", "当前账号仅有文件只读权限"));
        }
        return null;
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
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
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
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
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
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
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
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @GetMapping("/grantable-folders")
    public ResponseEntity<?> grantableFolders(@AuthenticationPrincipal UserDetails u) {
        ResponseEntity<?> check = checkFileWriteAccess(u.getUsername());
        if (check != null) return check;
        try {
            return ResponseEntity.ok(service.listGrantableFolders(u.getUsername()));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
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
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @GetMapping("/{id}/download")
    public ResponseEntity<?> download(
            @AuthenticationPrincipal UserDetails u,
            @PathVariable Long id,
            @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch,
            @RequestHeader(value = HttpHeaders.RANGE, required = false) String rangeHeader) throws IOException {
        if (!permissionService.hasFileModuleAccess(u.getUsername())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
        UserFile f = service.getFile(u.getUsername(), id);
        File target = service.resolveDownloadTarget(f);
        String encoded = URLEncoder.encode(f.getName(), StandardCharsets.UTF_8).replace("+", "%20");
        MediaType mediaType = MediaType.parseMediaType(
                f.getMimeType() != null ? f.getMimeType() : "application/octet-stream");
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

        Resource resource = new FileSystemResource(target);
        if (StringUtils.hasText(rangeHeader)) {
            try {
                var ranges = HttpRange.parseRanges(rangeHeader);
                if (ranges.isEmpty()) {
                    throw new IllegalArgumentException("Invalid range");
                }
                HttpRange range = ranges.get(0);
                ResourceRegion region = range.toResourceRegion(resource);
                long start = region.getPosition();
                long end = Math.min(start + region.getCount() - 1, target.length() - 1);
                return ResponseEntity.status(HttpStatus.PARTIAL_CONTENT)
                        .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + encoded)
                        .header(HttpHeaders.ETAG, etag)
                        .lastModified(target.lastModified())
                        .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                        .header(HttpHeaders.CACHE_CONTROL, "private, max-age=0, must-revalidate")
                        .header(HttpHeaders.CONTENT_RANGE, "bytes " + start + "-" + end + "/" + target.length())
                        .contentType(mediaType)
                        .contentLength(region.getCount())
                        .body(region);
            } catch (IllegalArgumentException ex) {
                return ResponseEntity.status(HttpStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
                        .header(HttpHeaders.CONTENT_RANGE, "bytes */" + target.length())
                        .header(HttpHeaders.ETAG, etag)
                        .lastModified(target.lastModified())
                        .header(HttpHeaders.ACCEPT_RANGES, "bytes")
                        .build();
            }
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
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
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
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
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
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
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
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
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
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
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
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    private String buildWeakEtag(File file) {
        return "W/\"" + Long.toHexString(file.lastModified()) + "-" + Long.toHexString(file.length()) + "\"";
    }

    private FileMetadataDto buildMetadata(UserFile file, File target) {
        return new FileMetadataDto(
                file.getId(),
                file.getName(),
                target.length(),
                file.getMimeType(),
                buildWeakEtag(target),
                Instant.ofEpochMilli(target.lastModified()).toString(),
                Boolean.TRUE
        );
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
