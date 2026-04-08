package com.metrology.dto;

import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class AnalysisGrrResponse {
    private int sampleCount;
    private int appraiserCount;
    private int partCount;
    private int trialCount;
    private Double tolerance;

    private double grandMean;
    private double msPart;
    private double msAppraiser;
    private double msInteraction;
    private double msRepeatability;

    private double varRepeatability;
    private double varAppraiser;
    private double varInteraction;
    private double varReproducibility;
    private double varGrr;
    private double varPartToPart;
    private double varTotal;

    private double sdRepeatability;
    private double sdReproducibility;
    private double sdGrr;
    private double sdPartToPart;
    private double sdTotal;

    private double svRepeatability;
    private double svReproducibility;
    private double svGrr;
    private double svPartToPart;
    private double svTotal;

    private double pctContributionRepeatability;
    private double pctContributionReproducibility;
    private double pctContributionGrr;
    private double pctContributionPartToPart;

    private double pctStudyVarRepeatability;
    private double pctStudyVarReproducibility;
    private double pctStudyVarGrr;
    private double pctStudyVarPartToPart;

    private Double pctToleranceRepeatability;
    private Double pctToleranceReproducibility;
    private Double pctToleranceGrr;
    private Double pctTolerancePartToPart;

    private double ndc;
    private String summary;
}
