package com.metrology.controller;

import com.metrology.dto.AnalysisCapabilityRequest;
import com.metrology.dto.AnalysisGrrRequest;
import com.metrology.dto.AnalysisLinearityRequest;
import com.metrology.dto.AnalysisRepeatabilityRequest;
import com.metrology.service.AnalysisService;
import com.metrology.service.PermissionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.time.LocalDate;
import java.util.Map;

@RestController
@RequestMapping("/api/analysis")
@RequiredArgsConstructor
public class AnalysisController {

    private final AnalysisService analysisService;
    private final PermissionService permissionService;

    @PostMapping("/capability")
    public ResponseEntity<?> capability(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody AnalysisCapabilityRequest request) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_VIEW)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        try {
            return ResponseEntity.ok(analysisService.calculateCapability(request));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        }
    }

    @PostMapping("/grr")
    public ResponseEntity<?> grr(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody AnalysisGrrRequest request) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_VIEW)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        try {
            return ResponseEntity.ok(analysisService.calculateGrr(request));
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        }
    }

    @PostMapping("/grr/report")
    public ResponseEntity<?> exportGrrReport(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody AnalysisGrrRequest request) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_VIEW)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        try {
            byte[] data = analysisService.exportGrrFullReport(request);
            String filename = URLEncoder.encode(
                    "GRR完整报告-" + LocalDate.now() + ".xls",
                    StandardCharsets.UTF_8
            ).replace("+", "%20");
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + filename)
                    .contentType(MediaType.parseMediaType("application/vnd.ms-excel"))
                    .body(data);
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        } catch (Exception ex) {
            return ResponseEntity.internalServerError().body(Map.of("message", "导出失败，请稍后重试"));
        }
    }

    @PostMapping("/capability/report")
    public ResponseEntity<?> exportCapabilityReport(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody AnalysisCapabilityRequest request) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_VIEW)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        try {
            byte[] data = analysisService.exportCapabilityProfessionalReport(request);
            String filename = URLEncoder.encode(
                    "CPK_PPK_专业报告-" + LocalDate.now() + ".xls",
                    StandardCharsets.UTF_8
            ).replace("+", "%20");
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + filename)
                    .contentType(MediaType.parseMediaType("application/vnd.ms-excel"))
                    .body(data);
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        } catch (Exception ex) {
            return ResponseEntity.internalServerError().body(Map.of("message", "导出失败，请稍后重试"));
        }
    }

    @PostMapping("/repeatability/report")
    public ResponseEntity<?> exportRepeatabilityReport(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody AnalysisRepeatabilityRequest request) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_VIEW)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        try {
            byte[] data = analysisService.exportRepeatabilityProfessionalReport(request);
            String filename = URLEncoder.encode(
                    "重复性_专业报告-" + LocalDate.now() + ".xls",
                    StandardCharsets.UTF_8
            ).replace("+", "%20");
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + filename)
                    .contentType(MediaType.parseMediaType("application/vnd.ms-excel"))
                    .body(data);
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        } catch (Exception ex) {
            return ResponseEntity.internalServerError().body(Map.of("message", "导出失败，请稍后重试"));
        }
    }

    @PostMapping("/reproducibility/report")
    public ResponseEntity<?> exportReproducibilityReport(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody AnalysisGrrRequest request) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_VIEW)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        try {
            byte[] data = analysisService.exportReproducibilityProfessionalReport(request);
            String filename = URLEncoder.encode(
                    "再现性_专业报告-" + LocalDate.now() + ".xls",
                    StandardCharsets.UTF_8
            ).replace("+", "%20");
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + filename)
                    .contentType(MediaType.parseMediaType("application/vnd.ms-excel"))
                    .body(data);
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        } catch (Exception ex) {
            return ResponseEntity.internalServerError().body(Map.of("message", "导出失败，请稍后重试"));
        }
    }

    @PostMapping("/linearity/report")
    public ResponseEntity<?> exportLinearityReport(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody AnalysisLinearityRequest request) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_VIEW)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        try {
            byte[] data = analysisService.exportLinearityProfessionalReport(request);
            String filename = URLEncoder.encode(
                    "线性分析_专业报告-" + LocalDate.now() + ".xls",
                    StandardCharsets.UTF_8
            ).replace("+", "%20");
            return ResponseEntity.ok()
                    .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename*=UTF-8''" + filename)
                    .contentType(MediaType.parseMediaType("application/vnd.ms-excel"))
                    .body(data);
        } catch (IllegalArgumentException ex) {
            return ResponseEntity.badRequest().body(Map.of("message", ex.getMessage()));
        } catch (Exception ex) {
            return ResponseEntity.internalServerError().body(Map.of("message", "导出失败，请稍后重试"));
        }
    }
}
