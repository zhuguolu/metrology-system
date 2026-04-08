package com.metrology.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AnalysisCapabilityResponse {
    private int sampleCount;
    private int subgroupSize;
    private int groupCount;
    private String chartType;
    private String summary;

    private double lsl;
    private double usl;
    private double target;
    private double mean;
    private double min;
    private double max;
    private double plus3Sigma;
    private double minus3Sigma;

    private double sigmaWithin;
    private double sigmaOverall;
    private double cp;
    private double cpk;
    private double cpl;
    private double cpu;
    private double pp;
    private double ppk;
    private double ppl;
    private double ppu;

    private long outLowerCount;
    private long outUpperCount;
    private long inSpecCount;
    private double observedPpmBelowLsl;
    private double observedPpmAboveUsl;
    private double observedPpmTotal;
    private double predictedPpmBelowLslWithin;
    private double predictedPpmAboveUslWithin;
    private double predictedPpmTotalWithin;
    private double predictedPpmBelowLslOverall;
    private double predictedPpmAboveUslOverall;
    private double predictedPpmTotalOverall;

    private List<Double> values;
    private List<AnalysisHistogramBin> histogram;
}
