package com.metrology.controller;

import com.metrology.dto.DashboardStats;
import com.metrology.dto.DeviceDto;
import com.metrology.dto.PageResult;
import com.metrology.entity.AuditRecord;
import com.metrology.repository.UserRepository;
import com.metrology.service.AuditService;
import com.metrology.service.DeviceService;
import com.metrology.service.PermissionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.Map;

@RestController
@RequestMapping("/api/devices")
@RequiredArgsConstructor
public class DeviceController {

    private final DeviceService deviceService;
    private final PermissionService permissionService;
    private final AuditService auditService;
    private final UserRepository userRepository;

    private boolean isAdmin(String username) {
        return userRepository.findByUsername(username)
                .map(u -> "ADMIN".equals(u.getRole())).orElse(false);
    }

    /** 全量列表（校准管理使用） */
    @GetMapping
    public ResponseEntity<?> list(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String assetNo,
            @RequestParam(required = false) String serialNo,
            @RequestParam(required = false) String dept,
            @RequestParam(required = false) String validity,
            @RequestParam(required = false) String responsiblePerson,
            @RequestParam(required = false) String useStatus) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_VIEW)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        return ResponseEntity.ok(deviceService.getDevices(
                userDetails.getUsername(), search, assetNo, serialNo, dept, validity, responsiblePerson, useStatus));
    }

    /** 分页列表（设备台账使用） */
    @GetMapping("/paged")
    public ResponseEntity<?> listPaged(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String assetNo,
            @RequestParam(required = false) String serialNo,
            @RequestParam(required = false) String dept,
            @RequestParam(required = false) String validity,
            @RequestParam(required = false) String responsiblePerson,
            @RequestParam(required = false) String useStatus,
            @RequestParam(required = false) String nextDateFrom,
            @RequestParam(required = false) String nextDateTo,
            @RequestParam(defaultValue = "false") boolean todoOnly,
            @RequestParam(defaultValue = "1") int page,
            @RequestParam(defaultValue = "20") int size) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_VIEW)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        return ResponseEntity.ok(deviceService.getDevicesPaged(
                userDetails.getUsername(), search, assetNo, serialNo, dept, validity, responsiblePerson, useStatus,
                nextDateFrom, nextDateTo, todoOnly, page, size));
    }

    @PostMapping
    public ResponseEntity<?> create(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody DeviceDto dto) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_CREATE)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足：无法新增设备"));
        }
        // 普通用户提交审核，管理员直接执行
        if (!isAdmin(userDetails.getUsername())) {
            AuditRecord record = auditService.submitCreate(userDetails.getUsername(), dto);
            return ResponseEntity.status(HttpStatus.ACCEPTED).body(
                    Map.of("auditId", record.getId(), "message", "您的新增申请已提交，等待管理员审核"));
        }
        DeviceDto created = deviceService.createDevice(userDetails.getUsername(), dto);
        auditService.recordDirectCreate(userDetails.getUsername(), created);
        return ResponseEntity.ok(created);
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> update(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id,
            @RequestBody DeviceDto dto) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_UPDATE)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足：无法修改设备"));
        }
        if (!isAdmin(userDetails.getUsername())) {
            AuditRecord record = auditService.submitUpdate(userDetails.getUsername(), id, dto);
            return ResponseEntity.status(HttpStatus.ACCEPTED).body(
                    Map.of("auditId", record.getId(), "message", "您的修改申请已提交，等待管理员审核"));
        }
        try {
            auditService.recordDirectUpdate(userDetails.getUsername(), id, dto);
            return ResponseEntity.ok(deviceService.updateDevice(userDetails.getUsername(), id, dto));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @PutMapping("/{id}/calibration")
    public ResponseEntity<?> updateCalibration(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id,
            @RequestBody DeviceDto dto) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.CALIBRATION_RECORD)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足：无法记录校准"));
        }

        DeviceDto calibrationDto = new DeviceDto();
        calibrationDto.setCalDate(dto.getCalDate());
        calibrationDto.setCycle(dto.getCycle());
        calibrationDto.setCalibrationResult(dto.getCalibrationResult());
        calibrationDto.setRemark(dto.getRemark());

        if (!isAdmin(userDetails.getUsername())) {
            AuditRecord record = auditService.submitUpdate(userDetails.getUsername(), id, calibrationDto);
            return ResponseEntity.status(HttpStatus.ACCEPTED).body(
                    Map.of("auditId", record.getId(), "message", "您的校准记录申请已提交，等待管理员审核"));
        }
        try {
            auditService.recordDirectUpdate(userDetails.getUsername(), id, calibrationDto);
            return ResponseEntity.ok(deviceService.updateDevice(userDetails.getUsername(), id, calibrationDto));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.notFound().build();
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_DELETE)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足：无法删除设备"));
        }
        if (!isAdmin(userDetails.getUsername())) {
            AuditRecord record = auditService.submitDelete(userDetails.getUsername(), id);
            return ResponseEntity.status(HttpStatus.ACCEPTED).body(
                    Map.of("auditId", record.getId(), "message", "您的删除申请已提交，等待管理员审核"));
        }
        auditService.recordDirectDelete(userDetails.getUsername(), id);
        deviceService.deleteDevice(id);
        return ResponseEntity.ok().build();
    }

    @GetMapping("/dashboard")
    public ResponseEntity<DashboardStats> dashboard(@AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(deviceService.getDashboardStats(userDetails.getUsername()));
    }

    /** 设备台账导出（支持筛选条件） */
    @GetMapping("/export")
    public ResponseEntity<byte[]> export(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String assetNo,
            @RequestParam(required = false) String serialNo,
            @RequestParam(required = false) String dept,
            @RequestParam(required = false) String validity,
            @RequestParam(required = false) String useStatus) throws IOException {
        byte[] data = deviceService.exportExcel(userDetails.getUsername(), search, assetNo, serialNo, dept, validity, useStatus);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"devices.xlsx\"")
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(data);
    }

    /** 校准管理导出（支持筛选条件） */
    @GetMapping("/export/calibration")
    public ResponseEntity<byte[]> exportCalibration(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) String dept,
            @RequestParam(required = false) String validity,
            @RequestParam(required = false) String responsiblePerson,
            @RequestParam(required = false) String useStatus) throws IOException {
        byte[] data = deviceService.exportCalibration(
                userDetails.getUsername(), search, dept, validity, responsiblePerson);
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"calibration.xlsx\"")
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(data);
    }

    @GetMapping("/template")
    public ResponseEntity<byte[]> template() throws IOException {
        byte[] data = deviceService.getTemplate();
        return ResponseEntity.ok()
                .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"import_template.xlsx\"")
                .contentType(MediaType.parseMediaType("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"))
                .body(data);
    }

    @PostMapping("/import")
    public ResponseEntity<?> importExcel(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestParam("file") MultipartFile file) throws IOException {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.DEVICE_CREATE)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        int count = deviceService.importExcel(userDetails.getUsername(), file);
        return ResponseEntity.ok(Map.of("count", count, "message", "成功导入 " + count + " 条设备"));
    }

    @PostMapping("/upload")
    public ResponseEntity<Map<String, String>> uploadFile(
            @RequestParam("file") MultipartFile file) throws IOException {
        String path = deviceService.saveFile(file);
        return ResponseEntity.ok(Map.of("path", path, "name",
                file.getOriginalFilename() != null ? file.getOriginalFilename() : ""));
    }
}
