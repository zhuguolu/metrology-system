package com.metrology.dto;

import lombok.Data;

import java.util.List;

@Data
public class AnalysisCapabilityRequest {
    private Double lsl;
    private Double usl;
    private Double target;
    private Integer subgroupSize;
    private Integer bins;
    private List<List<Double>> gridValues;
    private String rawValues;
}
