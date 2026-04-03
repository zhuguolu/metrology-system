package com.metrology.dto;

import lombok.Data;

import java.time.LocalDateTime;

@Data
public class ChangeRecordItemDto {
    private Long id;
    private String type;
    private String status;
    private String entityType;
    private Long entityId;
    private String submittedBy;
    private LocalDateTime submittedAt;
    private String approvedBy;
    private LocalDateTime approvedAt;
    private String remark;
    private String rejectReason;
    private String deviceName;
    private String metricNo;
    private Integer changedFieldCount;
}
