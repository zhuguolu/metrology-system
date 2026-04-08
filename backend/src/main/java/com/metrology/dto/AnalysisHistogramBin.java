package com.metrology.dto;

import lombok.AllArgsConstructor;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@NoArgsConstructor
@AllArgsConstructor
public class AnalysisHistogramBin {
    private double lower;
    private double upper;
    private double center;
    private long count;
}
