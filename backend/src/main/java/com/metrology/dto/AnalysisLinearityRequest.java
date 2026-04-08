package com.metrology.dto;

import lombok.Data;

import java.util.List;

@Data
public class AnalysisLinearityRequest {
    private Double tolerance;
    // 每行：第一列参考值，后续列为重复测量值
    private List<List<Double>> gridValues;
    private String rawValues;
}
