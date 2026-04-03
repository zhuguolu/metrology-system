package com.metrology.controller;

import com.metrology.entity.UserFile;
import com.metrology.service.UserFileService;
import lombok.RequiredArgsConstructor;
import org.springframework.core.io.InputStreamResource;
import org.springframework.core.io.Resource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.server.ResponseStatusException;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.Map;

@RestController
@RequestMapping("/api/public/shares")
@RequiredArgsConstructor
public class PublicShareController {

    private final UserFileService userFileService;

    @GetMapping("/{token}")
    public ResponseEntity<?> getShare(
            @PathVariable String token,
            @RequestParam(required = false) Long folderId,
            @RequestParam(required = false) String password) {
        try {
            return ResponseEntity.ok(userFileService.getPublicShare(token, folderId, password));
        } catch (ResponseStatusException e) {
            return ResponseEntity.status(e.getStatusCode())
                    .body(Map.of("message", e.getReason() != null ? e.getReason() : "访问失败"));
        }
    }

    @GetMapping("/{token}/files/{id}/download")
    public ResponseEntity<?> download(
            @PathVariable String token,
            @PathVariable Long id,
            @RequestParam(required = false) String password) throws IOException {
        try {
            UserFile file = userFileService.getPublicSharedFile(token, id, password, true);
            File target = userFileService.resolveDownloadTarget(file);
            String encoded = URLEncoder.encode(file.getName(), StandardCharsets.UTF_8).replace("+", "%20");
            Resource resource = new InputStreamResource(new FileInputStream(target));
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + encoded)
                    .contentType(MediaType.parseMediaType(
                            file.getMimeType() != null ? file.getMimeType() : "application/octet-stream"))
                    .contentLength(target.length())
                    .body(resource);
        } catch (ResponseStatusException e) {
            return ResponseEntity.status(e.getStatusCode())
                    .body(Map.of("message", e.getReason() != null ? e.getReason() : "下载失败"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @GetMapping("/{token}/files/{id}/raw")
    public ResponseEntity<?> raw(
            @PathVariable String token,
            @PathVariable Long id,
            @RequestParam(required = false) String password) throws IOException {
        try {
            UserFile file = userFileService.getPublicSharedFile(token, id, password, false);
            File target = userFileService.resolveDownloadTarget(file);
            String encoded = URLEncoder.encode(file.getName(), StandardCharsets.UTF_8).replace("+", "%20");
            Resource resource = new InputStreamResource(new FileInputStream(target));
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename*=UTF-8''" + encoded)
                    .contentType(MediaType.parseMediaType(
                            file.getMimeType() != null ? file.getMimeType() : "application/octet-stream"))
                    .contentLength(target.length())
                    .body(resource);
        } catch (ResponseStatusException e) {
            return ResponseEntity.status(e.getStatusCode())
                    .body(Map.of("message", e.getReason() != null ? e.getReason() : "预览失败"));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }
}
