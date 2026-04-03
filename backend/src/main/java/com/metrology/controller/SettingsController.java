package com.metrology.controller;

import com.metrology.dto.SettingsDto;
import com.metrology.dto.MaintenanceRunResultDto;
import com.metrology.service.SettingsService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/settings")
@RequiredArgsConstructor
public class SettingsController {

    private final SettingsService settingsService;

    @GetMapping
    public ResponseEntity<SettingsDto> get(@AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(settingsService.getSettings(userDetails.getUsername()));
    }

    @PutMapping
    public ResponseEntity<SettingsDto> save(
            @AuthenticationPrincipal UserDetails userDetails,
            @RequestBody SettingsDto dto) {
        return ResponseEntity.ok(settingsService.saveSettings(userDetails.getUsername(), dto));
    }

    @PostMapping("/maintenance/run")
    public ResponseEntity<MaintenanceRunResultDto> runMaintenanceNow(
            @AuthenticationPrincipal UserDetails userDetails) {
        return ResponseEntity.ok(settingsService.runMaintenanceNow(userDetails.getUsername()));
    }
}
