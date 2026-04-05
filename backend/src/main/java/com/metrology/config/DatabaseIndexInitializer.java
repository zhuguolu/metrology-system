package com.metrology.config;

import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Component;

import java.util.List;

@Slf4j
@Component
@RequiredArgsConstructor
public class DatabaseIndexInitializer implements ApplicationRunner {

    private final JdbcTemplate jdbcTemplate;

    @Override
    public void run(ApplicationArguments args) {
        List<IndexDefinition> indexes = List.of(
                new IndexDefinition("devices", "idx_devices_metric_no", "metric_no"),
                new IndexDefinition("devices", "idx_devices_asset_no", "asset_no"),
                new IndexDefinition("devices", "idx_devices_serial_no", "serial_no"),
                new IndexDefinition("devices", "idx_devices_dept", "dept"),
                new IndexDefinition("devices", "idx_devices_responsible_person", "responsible_person"),
                new IndexDefinition("devices", "idx_devices_use_status", "use_status"),
                new IndexDefinition("devices", "idx_devices_validity", "validity"),
                new IndexDefinition("devices", "idx_devices_next_date", "next_date"),
                new IndexDefinition("devices", "idx_devices_cal_date", "cal_date"),
                new IndexDefinition("devices", "idx_devices_todo_lookup", "use_status, validity, next_date"),
                new IndexDefinition("devices", "idx_devices_dept_next_date", "dept, next_date"),
                new IndexDefinition("devices", "idx_devices_sort_default", "use_status, next_date, id"),
                new IndexDefinition("devices", "idx_devices_sort_todo", "days_passed, next_date, id"),
                new IndexDefinition("devices", "idx_devices_filter_scope", "dept, responsible_person, use_status, validity, next_date"),
                new IndexDefinition("user_files", "idx_user_files_user_parent_type_name", "user_id, parent_id, type, name"),
                new IndexDefinition("user_files", "idx_user_files_user_parent_name", "user_id, parent_id, name"),
                new IndexDefinition("user_files", "idx_user_files_parent_type_name", "parent_id, type, name"),
                new IndexDefinition("user_files", "idx_user_files_parent", "parent_id"),
                new IndexDefinition("user_file_grants", "idx_user_file_grants_user", "user_id"),
                new IndexDefinition("user_file_grants", "idx_user_file_grants_folder", "folder_id")
        );

        for (IndexDefinition definition : indexes) {
            ensureIndex(definition);
        }
    }

    private void ensureIndex(IndexDefinition definition) {
        Integer count = jdbcTemplate.queryForObject(
                """
                SELECT COUNT(1)
                FROM information_schema.statistics
                WHERE table_schema = DATABASE()
                  AND table_name = ?
                  AND index_name = ?
                """,
                Integer.class,
                definition.tableName(),
                definition.indexName()
        );

        if (count != null && count > 0) {
            return;
        }

        String sql = "CREATE INDEX " + definition.indexName()
                + " ON " + definition.tableName()
                + " (" + definition.columns() + ")";
        jdbcTemplate.execute(sql);
        log.info("Created database index {} on {}({})", definition.indexName(), definition.tableName(), definition.columns());
    }

    private record IndexDefinition(String tableName, String indexName, String columns) {
    }
}
