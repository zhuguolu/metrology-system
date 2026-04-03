package com.metrology.controller;

import com.metrology.entity.UserFile;
import com.metrology.service.PermissionService;
import com.metrology.service.UserFileService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.InputStreamResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
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
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("message", "无权访问文件模块"));
        }
        return null;
    }

    private ResponseEntity<?> checkFileWriteAccess(String username) {
        if (!permissionService.hasPermission(username, PermissionService.FILE_ACCESS)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("message", "当前账号只有文件只读权限"));
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

    @GetMapping("/{id}/download")
    public ResponseEntity<Resource> download(
            @AuthenticationPrincipal UserDetails u,
            @PathVariable Long id) throws IOException {
        if (!permissionService.hasFileModuleAccess(u.getUsername())) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
        UserFile f = service.getFile(u.getUsername(), id);
        File target = service.resolveDownloadTarget(f);
        String encoded = URLEncoder.encode(f.getName(), StandardCharsets.UTF_8).replace("+", "%20");
        InputStreamResource resource = new InputStreamResource(new FileInputStream(target));
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + encoded)
                .contentType(MediaType.parseMediaType(
                        f.getMimeType() != null ? f.getMimeType() : "application/octet-stream"))
                .contentLength(target.length())
                .body(resource);
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
}
