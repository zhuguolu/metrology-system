package com.metrology.service;

import com.metrology.dto.SettingsDto;
import com.metrology.dto.MaintenanceRunResultDto;
import com.metrology.entity.Device;
import com.metrology.entity.User;
import com.metrology.entity.UserSettings;
import com.metrology.repository.DeviceRepository;
import com.metrology.repository.UserRepository;
import com.metrology.repository.UserSettingsRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Service;

import java.time.LocalDate;
import java.time.temporal.ChronoUnit;
import java.util.List;

@Service
@RequiredArgsConstructor
public class SettingsService {

    private final UserSettingsRepository settingsRepository;
    private final UserRepository userRepository;
    private final DeviceRepository deviceRepository;
    private final SystemMaintenanceService systemMaintenanceService;

    public SettingsDto getSettings(String username) {
        User user = userRepository.findByUsername(username).orElseThrow();
        UserSettings s = settingsRepository.findByUserId(user.getId())
                .orElseGet(() -> createDefault(user.getId()));
        SettingsDto dto = new SettingsDto();
        dto.setWarningDays(s.getWarningDays());
        dto.setExpiredDays(s.getExpiredDays());
        dto.setAutoLedgerExportEnabled(Boolean.TRUE.equals(s.getAutoLedgerExportEnabled()));
        dto.setDatabaseBackupEnabled(Boolean.TRUE.equals(s.getDatabaseBackupEnabled()));
        dto.setCmsRootPath(systemMaintenanceService.getCmsRootPath());
        dto.setLedgerExportPath(systemMaintenanceService.getLedgerExportAbsolutePath());
        dto.setDatabaseBackupPath(systemMaintenanceService.getDatabaseBackupAbsolutePath());
        return dto;
    }

    public SettingsDto saveSettings(String username, SettingsDto dto) {
        User user = userRepository.findByUsername(username).orElseThrow();
        ensureAdmin(user);
        UserSettings s = settingsRepository.findByUserId(user.getId())
                .orElseGet(() -> createDefault(user.getId()));
        s.setWarningDays(dto.getWarningDays());
        s.setExpiredDays(dto.getExpiredDays());
        s.setAutoLedgerExportEnabled(Boolean.TRUE.equals(dto.getAutoLedgerExportEnabled()));
        s.setDatabaseBackupEnabled(Boolean.TRUE.equals(dto.getDatabaseBackupEnabled()));
        settingsRepository.save(s);

        // recalculate validity for all devices with new settings
        List<Device> devices = deviceRepository.findAll();
        for (Device d : devices) {
            String[] metrics = calculateMetrics(d.getCalDate(), dto.getWarningDays(), dto.getExpiredDays());
            d.setValidity(metrics[0]);
            d.setDaysPassed(Integer.parseInt(metrics[1]));
        }
        deviceRepository.saveAll(devices);
        return getSettings(username);
    }

    public MaintenanceRunResultDto runMaintenanceNow(String username) {
        User user = userRepository.findByUsername(username).orElseThrow();
        ensureAdmin(user);
        return systemMaintenanceService.runMaintenanceNow(username);
    }

    private String[] calculateMetrics(LocalDate calDate, int warningDays, int expiredDays) {
        if (calDate == null) return new String[]{"有效", "0"};
        LocalDate today = LocalDate.now();
        long days = ChronoUnit.DAYS.between(calDate, today);
        if (days < 0) days = 0;
        String validity;
        if (days >= expiredDays) validity = "失效";
        else if (days >= warningDays) validity = "即将过期";
        else validity = "有效";
        return new String[]{validity, String.valueOf(days)};
    }

    private UserSettings createDefault(Long userId) {
        UserSettings s = new UserSettings();
        s.setUserId(userId);
        s.setWarningDays(315);
        s.setExpiredDays(360);
        s.setAutoLedgerExportEnabled(Boolean.FALSE);
        s.setDatabaseBackupEnabled(Boolean.FALSE);
        return settingsRepository.save(s);
    }

    private void ensureAdmin(User user) {
        if (!"ADMIN".equalsIgnoreCase(user.getRole())) {
            throw new AccessDeniedException("Admin role required");
        }
    }
}
