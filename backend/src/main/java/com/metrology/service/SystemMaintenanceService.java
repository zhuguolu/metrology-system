package com.metrology.service;

import com.metrology.dto.MaintenanceRunResultDto;
import com.metrology.entity.User;
import com.metrology.entity.UserSettings;
import com.metrology.repository.UserRepository;
import com.metrology.repository.UserSettingsRepository;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;

import javax.sql.DataSource;
import java.io.BufferedWriter;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Statement;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Base64;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Objects;
import java.util.Optional;
import java.util.Set;

@Service
@RequiredArgsConstructor
@Slf4j
public class SystemMaintenanceService {

    private final DeviceService deviceService;
    private final UserRepository userRepository;
    private final UserSettingsRepository userSettingsRepository;
    private final DataSource dataSource;

    @Value("${maintenance.cms-root-path:/app/cms}")
    private String cmsRootPath;

    @Value("${maintenance.ledger-export-file-name:device-ledger-latest.xlsx}")
    private String ledgerExportFileName;

    @Value("${maintenance.database-backup-file-name:metrology-db-backup.sql}")
    private String databaseBackupFileName;

    @Value("${maintenance.zone:Asia/Shanghai}")
    private String maintenanceZone;

    @Scheduled(cron = "${maintenance.cron:0 0 23 * * *}", zone = "${maintenance.zone:Asia/Shanghai}")
    public void runNightlyMaintenance() {
        Optional<User> adminOpt = findAdminUser();
        if (adminOpt.isEmpty()) {
            log.warn("Nightly maintenance skipped because no admin user was found");
            return;
        }

        User admin = adminOpt.get();
        UserSettings settings = userSettingsRepository.findByUserId(admin.getId())
                .orElseGet(() -> createDefaultSettings(admin.getId()));

        if (!Boolean.TRUE.equals(settings.getAutoLedgerExportEnabled())
                && !Boolean.TRUE.equals(settings.getDatabaseBackupEnabled())) {
            log.info("Nightly maintenance skipped because all maintenance switches are disabled");
            return;
        }

        MaintenanceRunResultDto result = runMaintenance(admin.getUsername(), settings);
        log.info("Nightly maintenance finished: {}", result.getMessage());
    }

    public MaintenanceRunResultDto runMaintenanceNow(String username) {
        User admin = userRepository.findByUsername(username).orElseThrow();
        UserSettings settings = userSettingsRepository.findByUserId(admin.getId())
                .orElseGet(() -> createDefaultSettings(admin.getId()));
        return runMaintenance(username, settings);
    }

    public String getCmsRootPath() {
        return cmsRootPath;
    }

    public String getLedgerExportAbsolutePath() {
        return resolveCmsPath(ledgerExportFileName).toString();
    }

    public String getDatabaseBackupAbsolutePath() {
        return resolveCmsPath(databaseBackupFileName).toString();
    }

    private MaintenanceRunResultDto runMaintenance(String username, UserSettings settings) {
        MaintenanceRunResultDto result = new MaintenanceRunResultDto();
        result.setLedgerExportPath(getLedgerExportAbsolutePath());
        result.setDatabaseBackupPath(getDatabaseBackupAbsolutePath());

        try {
            ensureCmsRootExists();

            if (Boolean.TRUE.equals(settings.getAutoLedgerExportEnabled())) {
                exportLedger(username);
                result.setLedgerExported(true);
            }

            if (Boolean.TRUE.equals(settings.getDatabaseBackupEnabled())) {
                backupDatabase();
                result.setDatabaseBackedUp(true);
            }

            if (!result.isLedgerExported() && !result.isDatabaseBackedUp()) {
                result.setMessage("All maintenance tasks are disabled");
            } else {
                result.setMessage(buildSuccessMessage(result));
            }
            return result;
        } catch (Exception e) {
            String message = "System maintenance failed: " + e.getMessage();
            log.error(message, e);
            result.setMessage(message);
            throw new IllegalStateException(message, e);
        }
    }

    private void exportLedger(String username) throws IOException {
        byte[] data = deviceService.exportExcel(username, null, null, null, null, null, null);
        Files.write(resolveCmsPath(ledgerExportFileName), data);
    }

    private void backupDatabase() throws IOException, SQLException {
        Path output = resolveCmsPath(databaseBackupFileName);
        try (Connection connection = dataSource.getConnection();
             BufferedWriter writer = Files.newBufferedWriter(output, StandardCharsets.UTF_8)) {
            String catalog = connection.getCatalog();
            List<String> tables = resolveTables(connection, catalog);

            writer.write("-- Metrology database backup");
            writer.newLine();
            writer.write("-- Generated at " + LocalDateTime.now().format(DateTimeFormatter.ISO_LOCAL_DATE_TIME));
            writer.newLine();
            writer.write("-- Time zone: " + maintenanceZone);
            writer.newLine();
            writer.write("SET NAMES utf8mb4;");
            writer.newLine();
            writer.write("SET FOREIGN_KEY_CHECKS=0;");
            writer.newLine();
            writer.newLine();

            List<String> deleteOrder = new ArrayList<>(tables);
            deleteOrder.sort(Comparator.reverseOrder());
            for (String table : deleteOrder) {
                writer.write("DELETE FROM `" + table + "`;");
                writer.newLine();
            }
            writer.newLine();

            for (String table : tables) {
                writeTableData(connection, writer, table);
                writer.newLine();
            }

            writer.write("SET FOREIGN_KEY_CHECKS=1;");
            writer.newLine();
        }
    }

    private List<String> resolveTables(Connection connection, String catalog) throws SQLException {
        Set<String> discovered = new LinkedHashSet<>();
        DatabaseMetaData metaData = connection.getMetaData();
        try (ResultSet rs = metaData.getTables(catalog, null, "%", new String[]{"TABLE"})) {
            while (rs.next()) {
                String table = rs.getString("TABLE_NAME");
                if (table != null && !table.isBlank()) {
                    discovered.add(table);
                }
            }
        }

        List<String> preferredOrder = Arrays.asList(
                "departments",
                "device_statuses",
                "users",
                "user_permissions",
                "user_settings",
                "devices",
                "audit_records",
                "audit_workflow_steps",
                "user_files",
                "user_file_grants",
                "webdav_mounts"
        );

        List<String> ordered = new ArrayList<>();
        for (String table : preferredOrder) {
            if (discovered.remove(table)) {
                ordered.add(table);
            }
        }

        discovered.stream().sorted().forEach(ordered::add);
        return ordered;
    }

    private void writeTableData(Connection connection, BufferedWriter writer, String table) throws SQLException, IOException {
        try (Statement statement = connection.createStatement();
             ResultSet rs = statement.executeQuery("SELECT * FROM `" + table + "`")) {
            ResultSetMetaData metaData = rs.getMetaData();
            int columnCount = metaData.getColumnCount();

            while (rs.next()) {
                writer.write("INSERT INTO `" + table + "` (");
                for (int i = 1; i <= columnCount; i++) {
                    if (i > 1) {
                        writer.write(", ");
                    }
                    writer.write("`" + metaData.getColumnLabel(i) + "`");
                }
                writer.write(") VALUES (");
                for (int i = 1; i <= columnCount; i++) {
                    if (i > 1) {
                        writer.write(", ");
                    }
                    writer.write(formatSqlValue(rs.getObject(i)));
                }
                writer.write(");");
                writer.newLine();
            }
        }
    }

    private String formatSqlValue(Object value) {
        if (value == null) {
            return "NULL";
        }
        if (value instanceof Number) {
            return value.toString();
        }
        if (value instanceof Boolean bool) {
            return bool ? "1" : "0";
        }
        if (value instanceof byte[] bytes) {
            return "FROM_BASE64('" + Base64.getEncoder().encodeToString(bytes) + "')";
        }
        String text = Objects.toString(value, "");
        return "'" + escapeSql(text) + "'";
    }

    private String escapeSql(String input) {
        return input
                .replace("\\", "\\\\")
                .replace("'", "''")
                .replace("\r", "\\r")
                .replace("\n", "\\n");
    }

    private String buildSuccessMessage(MaintenanceRunResultDto result) {
        List<String> parts = new ArrayList<>();
        if (result.isLedgerExported()) {
            parts.add("ledger exported to " + result.getLedgerExportPath());
        }
        if (result.isDatabaseBackedUp()) {
            parts.add("database backup written to " + result.getDatabaseBackupPath());
        }
        return String.join("; ", parts);
    }

    private void ensureCmsRootExists() throws IOException {
        Files.createDirectories(Paths.get(cmsRootPath));
    }

    private Path resolveCmsPath(String fileName) {
        return Paths.get(cmsRootPath, fileName);
    }

    private Optional<User> findAdminUser() {
        return userRepository.findAll().stream()
                .filter(user -> "ADMIN".equalsIgnoreCase(user.getRole()))
                .findFirst();
    }

    private UserSettings createDefaultSettings(Long userId) {
        UserSettings settings = new UserSettings();
        settings.setUserId(userId);
        settings.setWarningDays(315);
        settings.setExpiredDays(360);
        settings.setAutoLedgerExportEnabled(Boolean.FALSE);
        settings.setDatabaseBackupEnabled(Boolean.FALSE);
        return userSettingsRepository.save(settings);
    }
}
