package com.metrology.config;

import com.metrology.entity.Department;
import com.metrology.entity.DeviceStatus;
import com.metrology.entity.User;
import com.metrology.entity.UserSettings;
import com.metrology.repository.DepartmentRepository;
import com.metrology.repository.DeviceStatusRepository;
import com.metrology.repository.UserRepository;
import com.metrology.repository.UserSettingsRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;

import java.util.List;

@Component
@RequiredArgsConstructor
@Slf4j
public class DataInitializer implements ApplicationRunner {

    private final UserRepository userRepository;
    private final UserSettingsRepository settingsRepository;
    private final DeviceStatusRepository statusRepository;
    private final DepartmentRepository departmentRepository;
    private final PasswordEncoder passwordEncoder;

    @Override
    public void run(ApplicationArguments args) {
        if (userRepository.count() == 0) {
            User admin = new User();
            admin.setUsername("admin");
            admin.setPassword(passwordEncoder.encode("admin123"));
            admin.setRole("ADMIN");
            userRepository.save(admin);
            UserSettings s = new UserSettings();
            s.setUserId(admin.getId());
            s.setWarningDays(315);
            s.setExpiredDays(360);
            s.setAutoLedgerExportEnabled(Boolean.FALSE);
            s.setDatabaseBackupEnabled(Boolean.FALSE);
            settingsRepository.save(s);
            log.info("Default admin created: admin / admin123");
        }
        if (statusRepository.count() == 0) {
            List<String> defaults = List.of("正常", "故障", "维修", "报废");
            for (int i = 0; i < defaults.size(); i++) {
                DeviceStatus s = new DeviceStatus();
                s.setName(defaults.get(i));
                s.setSortOrder(i);
                statusRepository.save(s);
            }
            log.info("Default device statuses initialized");
        }
        if (departmentRepository.count() == 0) {
            List<String> defaultDepts = List.of(
                "开发一部", "开发二部", "生产一部", "生产二部",
                "工程一部", "工程二部", "品保一部", "品保二部",
                "采购部", "分选室", "实验室", "新能源生产部", "新能源开发部", "新能源品保部"
            );
            for (int i = 0; i < defaultDepts.size(); i++) {
                Department dept = new Department();
                dept.setName(defaultDepts.get(i));
                dept.setSortOrder(i);
                departmentRepository.save(dept);
            }
            log.info("Default departments initialized");
        }
    }
}
