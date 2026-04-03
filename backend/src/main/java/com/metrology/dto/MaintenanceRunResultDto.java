package com.metrology.dto;

import lombok.Data;

@Data
public class MaintenanceRunResultDto {
    private boolean ledgerExported;
    private boolean databaseBackedUp;
    private String ledgerExportPath;
    private String databaseBackupPath;
    private String message;
}
