package com.metrology.dto;

import lombok.Data;

import java.util.List;

@Data
public class ChangeRecordPageDto {
    private List<ChangeRecordItemDto> items;
    private long total;
    private int page;
    private int size;
    private ChangeRecordStatsDto stats;
}
