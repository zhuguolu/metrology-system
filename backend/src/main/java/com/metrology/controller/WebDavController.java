package com.metrology.controller;

import com.metrology.service.PermissionService;
import com.metrology.service.WebDavService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;

@RestController
@RequestMapping("/api/webdav")
@RequiredArgsConstructor
public class WebDavController {

    private final WebDavService webDavService;
    private final PermissionService permissionService;

    private ResponseEntity<?> checkWebDavAccess(String username) {
        if (!permissionService.hasPermission(username, PermissionService.WEBDAV_ACCESS)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).body(Map.of("message", "无权访问网络挂载模块"));
        }
        return null;
    }

    @GetMapping("/mounts")
    public ResponseEntity<?> listMounts(@AuthenticationPrincipal UserDetails user) {
        ResponseEntity<?> check = checkWebDavAccess(user.getUsername());
        if (check != null) return check;
        return ResponseEntity.ok(webDavService.listMounts(user.getUsername()));
    }

    @PostMapping("/mounts")
    public ResponseEntity<?> createMount(@AuthenticationPrincipal UserDetails user,
                                          @RequestBody Map<String, String> body) {
        ResponseEntity<?> check = checkWebDavAccess(user.getUsername());
        if (check != null) return check;
        try {
            return ResponseEntity.ok(webDavService.saveMount(user.getUsername(), body));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PutMapping("/mounts/{id}")
    public ResponseEntity<?> updateMount(@AuthenticationPrincipal UserDetails user,
                                          @PathVariable Long id,
                                          @RequestBody Map<String, String> body) {
        ResponseEntity<?> check = checkWebDavAccess(user.getUsername());
        if (check != null) return check;
        try {
            return ResponseEntity.ok(webDavService.updateMount(user.getUsername(), id, body));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @DeleteMapping("/mounts/{id}")
    public ResponseEntity<?> deleteMount(@AuthenticationPrincipal UserDetails user,
                                          @PathVariable Long id) {
        ResponseEntity<?> check = checkWebDavAccess(user.getUsername());
        if (check != null) return check;
        try {
            webDavService.deleteMount(user.getUsername(), id);
            return ResponseEntity.ok().build();
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PostMapping("/mounts/test")
    public ResponseEntity<?> testConnection(@RequestBody Map<String, String> body) {
        boolean ok = webDavService.testConnection(
                body.get("url"),
                body.getOrDefault("username", ""),
                body.getOrDefault("password", ""));
        return ResponseEntity.ok(Map.of("success", ok));
    }

    @GetMapping("/browse")
    public ResponseEntity<?> browse(@AuthenticationPrincipal UserDetails user,
                                     @RequestParam Long mountId,
                                     @RequestParam(required = false) String path) {
        ResponseEntity<?> check = checkWebDavAccess(user.getUsername());
        if (check != null) return check;
        try {
            return ResponseEntity.ok(webDavService.listFiles(user.getUsername(), mountId, path));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @GetMapping("/download")
    public ResponseEntity<byte[]> download(@AuthenticationPrincipal UserDetails user,
                                            @RequestParam Long mountId,
                                            @RequestParam String path,
                                            @RequestParam(required = false) String filename) throws Exception {
        if (!permissionService.hasPermission(user.getUsername(), PermissionService.WEBDAV_ACCESS)) {
            return ResponseEntity.status(HttpStatus.FORBIDDEN).build();
        }
        byte[] data = webDavService.downloadFile(user.getUsername(), mountId, path);
        String name = filename != null ? filename : path.substring(path.lastIndexOf('/') + 1);
        String encodedName = URLEncoder.encode(name, StandardCharsets.UTF_8).replace("+", "%20");
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + encodedName)
                .contentType(MediaType.APPLICATION_OCTET_STREAM)
                .body(data);
    }

    @PostMapping("/upload")
    public ResponseEntity<?> upload(@AuthenticationPrincipal UserDetails user,
                                     @RequestParam Long mountId,
                                     @RequestParam String path,
                                     @RequestParam MultipartFile file) throws Exception {
        ResponseEntity<?> check = checkWebDavAccess(user.getUsername());
        if (check != null) return check;
        webDavService.uploadFile(user.getUsername(), mountId, path + file.getOriginalFilename(),
                file.getBytes(), file.getContentType());
        return ResponseEntity.ok(Map.of("message", "上传成功"));
    }
}
