package com.metrology.dto;

import lombok.Data;

@Data
public class SettingsDto {
    private Integer warningDays;
    private Integer expiredDays;
    private Boolean autoLedgerExportEnabled;
    private Boolean databaseBackupEnabled;
    private String cmsRootPath;
    private String ledgerExportPath;
    private String databaseBackupPath;
}
