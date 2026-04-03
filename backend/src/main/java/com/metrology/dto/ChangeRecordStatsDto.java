package com.metrology.dto;

import lombok.Data;

@Data
public class ChangeRecordStatsDto {
    private long total;
    private long pending;
    private long approved;
    private long rejected;
    private long createCount;
    private long updateCount;
    private long deleteCount;
    private long submitterCount;
}
