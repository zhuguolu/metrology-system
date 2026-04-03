package com.metrology.entity;

import jakarta.persistence.*;
import lombok.Data;
import lombok.NoArgsConstructor;

@Entity
@Table(name = "user_settings")
@Data
@NoArgsConstructor
public class UserSettings {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", unique = true)
    private Long userId;

    @Column(name = "warning_days")
    private Integer warningDays = 315;

    @Column(name = "expired_days")
    private Integer expiredDays = 360;

    @Column(name = "auto_ledger_export_enabled")
    private Boolean autoLedgerExportEnabled = Boolean.FALSE;

    @Column(name = "database_backup_enabled")
    private Boolean databaseBackupEnabled = Boolean.FALSE;
}
