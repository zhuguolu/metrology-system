package com.metrology.controller;

import com.metrology.entity.DeviceStatus;
import com.metrology.service.DeviceStatusService;
import com.metrology.service.PermissionService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api/device-statuses")
@RequiredArgsConstructor
public class DeviceStatusController {

    private final DeviceStatusService statusService;
    private final PermissionService permissionService;

    @GetMapping
    public ResponseEntity<List<DeviceStatus>> list() {
        return ResponseEntity.ok(statusService.getAll());
    }

    @PostMapping
    public ResponseEntity<?> create(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody Map<String, String> body) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.STATUS_MANAGE)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        try {
            return ResponseEntity.ok(statusService.create(body.get("name")));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @PutMapping("/{id}")
    public ResponseEntity<?> update(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id,
            @RequestBody Map<String, String> body) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.STATUS_MANAGE)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        try {
            return ResponseEntity.ok(statusService.update(id, body.get("name")));
        } catch (IllegalArgumentException e) {
            return ResponseEntity.badRequest().body(Map.of("message", e.getMessage()));
        }
    }

    @DeleteMapping("/{id}")
    public ResponseEntity<?> delete(
            @AuthenticationPrincipal UserDetails userDetails,
            @PathVariable Long id) {
        if (!permissionService.hasPermission(userDetails.getUsername(), PermissionService.STATUS_MANAGE)) {
            return ResponseEntity.status(403).body(Map.of("message", "权限不足"));
        }
        statusService.delete(id);
        return ResponseEntity.ok().build();
    }
}
