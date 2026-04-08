package com.metrology.dto;

import lombok.Data;

import java.util.List;

@Data
public class AnalysisGrrRequest {
    private Integer appraiserCount;
    private Integer partCount;
    private Integer trialCount;
    private Double tolerance;
    private List<List<Double>> gridValues;
    private String rawValues;
}
