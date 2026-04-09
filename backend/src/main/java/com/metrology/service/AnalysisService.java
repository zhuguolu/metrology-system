package com.metrology.service;

import com.metrology.dto.*;
import org.apache.poi.hssf.usermodel.HSSFCell;
import org.apache.poi.hssf.usermodel.HSSFCellStyle;
import org.apache.poi.hssf.usermodel.HSSFFont;
import org.apache.poi.hssf.usermodel.HSSFRow;
import org.apache.poi.hssf.usermodel.HSSFSheet;
import org.apache.poi.hssf.usermodel.HSSFWorkbook;
import org.apache.poi.ss.usermodel.BorderStyle;
import org.apache.poi.ss.usermodel.FillPatternType;
import org.apache.poi.ss.usermodel.HorizontalAlignment;
import org.apache.poi.ss.usermodel.IndexedColors;
import org.apache.poi.ss.usermodel.VerticalAlignment;
import org.apache.poi.ss.util.CellRangeAddress;
import org.apache.poi.ss.util.CellReference;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.time.LocalDate;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

@Service
public class AnalysisService {

    private static final Pattern NUMBER_PATTERN =
            Pattern.compile("[-+]?(?:\\d*\\.\\d+|\\d+)(?:[eE][-+]?\\d+)?");
    private static final Map<Integer, Double> D2_CONSTANTS = Map.ofEntries(
            Map.entry(2, 1.128), Map.entry(3, 1.693), Map.entry(4, 2.059), Map.entry(5, 2.326),
            Map.entry(6, 2.534), Map.entry(7, 2.704), Map.entry(8, 2.847), Map.entry(9, 2.970),
            Map.entry(10, 3.078), Map.entry(11, 3.173), Map.entry(12, 3.258), Map.entry(13, 3.336),
            Map.entry(14, 3.407), Map.entry(15, 3.472), Map.entry(16, 3.532), Map.entry(17, 3.588),
            Map.entry(18, 3.640), Map.entry(19, 3.689), Map.entry(20, 3.735), Map.entry(21, 3.778),
            Map.entry(22, 3.819), Map.entry(23, 3.858), Map.entry(24, 3.895), Map.entry(25, 3.931)
    );
    private static final Map<Integer, Double> A2_BY_TRIAL = Map.ofEntries(
            Map.entry(2, 1.880), Map.entry(3, 1.023), Map.entry(4, 0.729), Map.entry(5, 0.577),
            Map.entry(6, 0.483), Map.entry(7, 0.419), Map.entry(8, 0.373), Map.entry(9, 0.337),
            Map.entry(10, 0.308), Map.entry(11, 0.285), Map.entry(12, 0.266), Map.entry(13, 0.249),
            Map.entry(14, 0.235), Map.entry(15, 0.223), Map.entry(16, 0.212), Map.entry(17, 0.203),
            Map.entry(18, 0.194), Map.entry(19, 0.187), Map.entry(20, 0.180), Map.entry(21, 0.173),
            Map.entry(22, 0.167), Map.entry(23, 0.162), Map.entry(24, 0.157), Map.entry(25, 0.153)
    );
    private static final Map<Integer, Double> D3_BY_TRIAL = Map.ofEntries(
            Map.entry(2, 0.000), Map.entry(3, 0.000), Map.entry(4, 0.000), Map.entry(5, 0.000),
            Map.entry(6, 0.000), Map.entry(7, 0.076), Map.entry(8, 0.136), Map.entry(9, 0.184),
            Map.entry(10, 0.223), Map.entry(11, 0.256), Map.entry(12, 0.283), Map.entry(13, 0.307),
            Map.entry(14, 0.328), Map.entry(15, 0.347), Map.entry(16, 0.363), Map.entry(17, 0.378),
            Map.entry(18, 0.391), Map.entry(19, 0.403), Map.entry(20, 0.415), Map.entry(21, 0.425),
            Map.entry(22, 0.434), Map.entry(23, 0.443), Map.entry(24, 0.451), Map.entry(25, 0.459)
    );
    private static final Map<Integer, Double> D4_BY_TRIAL = Map.ofEntries(
            Map.entry(2, 3.267), Map.entry(3, 2.574), Map.entry(4, 2.282), Map.entry(5, 2.114),
            Map.entry(6, 2.004), Map.entry(7, 1.924), Map.entry(8, 1.864), Map.entry(9, 1.816),
            Map.entry(10, 1.777), Map.entry(11, 1.744), Map.entry(12, 1.717), Map.entry(13, 1.693),
            Map.entry(14, 1.672), Map.entry(15, 1.653), Map.entry(16, 1.637), Map.entry(17, 1.622),
            Map.entry(18, 1.608), Map.entry(19, 1.597), Map.entry(20, 1.585), Map.entry(21, 1.575),
            Map.entry(22, 1.566), Map.entry(23, 1.557), Map.entry(24, 1.548), Map.entry(25, 1.541)
    );
    private static final Map<Integer, Double> K1_BY_TRIAL = Map.ofEntries(
            Map.entry(2, 0.8862), Map.entry(3, 0.5908), Map.entry(4, 0.4857), Map.entry(5, 0.4299),
            Map.entry(6, 0.3946), Map.entry(7, 0.3698), Map.entry(8, 0.3512), Map.entry(9, 0.3367),
            Map.entry(10, 0.3249)
    );
    private static final Map<Integer, Double> K2K3_BY_COUNT = Map.ofEntries(
            Map.entry(2, 0.7071), Map.entry(3, 0.5231), Map.entry(4, 0.4467), Map.entry(5, 0.4030),
            Map.entry(6, 0.3742), Map.entry(7, 0.3534), Map.entry(8, 0.3375), Map.entry(9, 0.3249),
            Map.entry(10, 0.3146)
    );

        public AnalysisCapabilityResponse calculateCapability(AnalysisCapabilityRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("鐠囬攱鐪伴崣鍌涙殶娑撳秷鍏樻稉铏光敄");
        }
        double lsl = requireFinite(request.getLsl(), "LSL 娑撳秷鍏樻稉铏光敄");
        double usl = requireFinite(request.getUsl(), "USL 娑撳秷鍏樻稉铏光敄");
        if (usl <= lsl) {
            throw new IllegalArgumentException("USL 韫囧懘銆忔径褌绨?LSL");
        }
        double target = request.getTarget() != null && Double.isFinite(request.getTarget())
                ? request.getTarget()
                : (lsl + usl) / 2.0;
        List<Double> values = resolveValues(request.getGridValues(), request.getRawValues());
        if (values.size() < 2) {
            throw new IllegalArgumentException("閺嶉攱婀伴弫浼村櫤閼峰啿鐨棁鈧憰?2 娑?);
        }
        int subgroupSize = request.getSubgroupSize() == null ? 0 : request.getSubgroupSize();
        if (subgroupSize < 0) {
            throw new IllegalArgumentException("鐎涙劗绮嶆径褍鐨稉宥堝厴鐏忓繋绨?0");
        }
        if (subgroupSize == 1) {
            throw new IllegalArgumentException("鐎涙劗绮嶆径褍鐨稉?1 閺冭埖妫ゅ▔鏇☆吀缁犳绮嶉崘鍛皾閸旑煉绱濈拠鐤翻閸?2~25 閹存牜鏆€缁?);
        }
        if (subgroupSize > 25) {
            throw new IllegalArgumentException("鐎涙劗绮嶆径褍鐨禒鍛暜閹?2~25");
        }
        double mean = mean(values);
        double min = values.stream().min(Double::compareTo).orElse(0.0);
        double max = values.stream().max(Double::compareTo).orElse(0.0);
        double sigmaOverall = sampleStdDev(values);
        if (sigmaOverall <= 0) {
            throw new IllegalArgumentException("閺嶉攱婀板▔銏犲З娑?0閿涘本妫ゅ▔鏇☆吀缁犳鍏橀崝娑欏瘹閺?);
        }
        String chartType = "MR";
        int groupCount = Math.max(values.size() - 1, 1);
        double sigmaWithin;
        if (subgroupSize > 1) {
            if (values.size() % subgroupSize != 0) {
                throw new IllegalArgumentException("閺嶉攱婀伴弫浼村櫤韫囧懘銆忛懗鍊燁潶鐎涙劗绮嶆径褍鐨弫鎾珟");
            }
            List<List<Double>> groups = chunk(values, subgroupSize);
            if (groups.size() < 2) {
                throw new IllegalArgumentException("閼峰啿鐨棁鈧憰?2 娑擃亜鐡欑紒?);
            }
            double d2 = requireD2(subgroupSize, "鐎涙劗绮嶆径褍鐨?);
            double avgRange = groups.stream().mapToDouble(this::range).average().orElse(0.0);
            sigmaWithin = avgRange / d2;
            groupCount = groups.size();
            chartType = "XR";
        } else {
            List<Double> movingRanges = movingRanges(values);
            if (movingRanges.isEmpty()) {
                throw new IllegalArgumentException("閺嶉攱婀伴弫浼村櫤娑撳秷鍐婚敍灞炬￥濞夋洝顓哥粻妤冃╅崝銊︾€?);
            }
            double d2 = requireD2(2, "缁夎濮╅弸浣告▕");
            sigmaWithin = mean(movingRanges) / d2;
            subgroupSize = 2;
            groupCount = movingRanges.size();
        }
        if (sigmaWithin <= 0) {
            throw new IllegalArgumentException("缂佸嫬鍞村▔銏犲З娑?0閿涘本妫ゅ▔鏇☆吀缁?Cpk");
        }
        double specWidth = usl - lsl;
        double cp = specWidth / (6.0 * sigmaWithin);
        double cpl = (mean - lsl) / (3.0 * sigmaWithin);
        double cpu = (usl - mean) / (3.0 * sigmaWithin);
        double cpk = Math.min(cpl, cpu);

        double pp = specWidth / (6.0 * sigmaOverall);
        double ppl = (mean - lsl) / (3.0 * sigmaOverall);
        double ppu = (usl - mean) / (3.0 * sigmaOverall);
        double ppk = Math.min(ppl, ppu);

        long lowerCount = values.stream().filter(v -> v < lsl).count();
        long upperCount = values.stream().filter(v -> v > usl).count();
        long inSpecCount = values.size() - lowerCount - upperCount;

        double observedPpmLower = ppm(lowerCount, values.size());
        double observedPpmUpper = ppm(upperCount, values.size());
        double observedPpmTotal = observedPpmLower + observedPpmUpper;

        double withinPpmLower = normalTailPpmLower(lsl, mean, sigmaWithin);
        double withinPpmUpper = normalTailPpmUpper(usl, mean, sigmaWithin);
        double overallPpmLower = normalTailPpmLower(lsl, mean, sigmaOverall);
        double overallPpmUpper = normalTailPpmUpper(usl, mean, sigmaOverall);

                List<AnalysisHistogramBin> histogram = buildHistogram(values, request.getBins());
        List<AnalysisValidationItem> validationMessages = buildCapabilityValidationMessages(
                values.size(),
                subgroupSize,
                groupCount,
                cpk,
                ppk,
                cpl,
                cpu,
                observedPpmTotal,
                overallPpmLower + overallPpmUpper
        );
        String assessmentLevel = capabilityAssessmentLevel(cpk, ppk);
        return AnalysisCapabilityResponse.builder()
                .sampleCount(values.size())
                .subgroupSize(subgroupSize)
                .groupCount(groupCount)
                .chartType(chartType)
                .summary(capabilitySummary(cpk, ppk))
                .lsl(lsl)
                .usl(usl)
                .target(target)
                .mean(mean)
                .min(min)
                .max(max)
                .plus3Sigma(mean + 3.0 * sigmaOverall)
                .minus3Sigma(mean - 3.0 * sigmaOverall)
                .sigmaWithin(sigmaWithin)
                .sigmaOverall(sigmaOverall)
                .cp(cp)
                .cpk(cpk)
                .cpl(cpl)
                .cpu(cpu)
                .pp(pp)
                .ppk(ppk)
                .ppl(ppl)
                .ppu(ppu)
                .outLowerCount(lowerCount)
                .outUpperCount(upperCount)
                .inSpecCount(inSpecCount)
                .observedPpmBelowLsl(observedPpmLower)
                .observedPpmAboveUsl(observedPpmUpper)
                .observedPpmTotal(observedPpmTotal)
                .predictedPpmBelowLslWithin(withinPpmLower)
                .predictedPpmAboveUslWithin(withinPpmUpper)
                .predictedPpmTotalWithin(withinPpmLower + withinPpmUpper)
                .predictedPpmBelowLslOverall(overallPpmLower)
                .predictedPpmAboveUslOverall(overallPpmUpper)
                .predictedPpmTotalOverall(overallPpmLower + overallPpmUpper)
                .assessmentLevel(assessmentLevel)
                .professionalConclusion(capabilityConclusion(assessmentLevel, cpk, ppk, cpl, cpu))
                .recommendedAction(capabilityRecommendedAction(assessmentLevel, validationMessages))
                .readyForReport(isReadyForReport(validationMessages))
                .rulesVersion("capability-v1")
                .validationMessages(validationMessages)
                .values(values)
                .histogram(histogram)
                .build();
    }
    public AnalysisGrrResponse calculateGrr(AnalysisGrrRequest request) {
        GrrDataset ds = resolveGrrDataset(request);
        int appraiserCount = ds.appraiserCount();
        int partCount = ds.partCount();
        int trialCount = ds.trialCount();
        int requiredCount = appraiserCount * partCount * trialCount;

        double grandSum = 0.0;
        double[] operatorMeans = new double[appraiserCount];
        double[] operatorRangeMeans = new double[appraiserCount];
        double[] partMeans = new double[partCount];

        for (int o = 0; o < appraiserCount; o++) {
            double operatorSum = 0.0;
            double operatorRangeSum = 0.0;
            for (int p = 0; p < partCount; p++) {
                double partTrialSum = 0.0;
                double min = Double.POSITIVE_INFINITY;
                double max = Double.NEGATIVE_INFINITY;
                for (int t = 0; t < trialCount; t++) {
                    double value = ds.data()[o][p][t];
                    partTrialSum += value;
                    operatorSum += value;
                    grandSum += value;
                    if (value < min) min = value;
                    if (value > max) max = value;
                }
                partMeans[p] += partTrialSum;
                operatorRangeSum += (max - min);
            }
            operatorMeans[o] = operatorSum / (partCount * trialCount);
            operatorRangeMeans[o] = operatorRangeSum / partCount;
        }

        for (int p = 0; p < partCount; p++) {
            partMeans[p] = partMeans[p] / (appraiserCount * trialCount);
        }

        double grandMean = grandSum / requiredCount;
        double rbar = mean(arrayToList(operatorRangeMeans));
        double xDiff = Arrays.stream(operatorMeans).max().orElse(0.0)
                - Arrays.stream(operatorMeans).min().orElse(0.0);
        double rp = Arrays.stream(partMeans).max().orElse(0.0)
                - Arrays.stream(partMeans).min().orElse(0.0);

        double k1 = k1ForTrial(trialCount);
        double k2 = kForCount(appraiserCount);
        double k3 = kForCount(partCount);

        double svRepeatability = rbar * k1;
        double avTerm = Math.pow(xDiff * k2, 2) - (Math.pow(svRepeatability, 2) / (partCount * trialCount));
        double svReproducibility = Math.sqrt(Math.max(avTerm, 0.0));
        double svGrr = Math.sqrt(Math.pow(svRepeatability, 2) + Math.pow(svReproducibility, 2));
        double svPartToPart = rp * k3;
        double svTotal = Math.sqrt(Math.pow(svGrr, 2) + Math.pow(svPartToPart, 2));
        if (!Double.isFinite(svTotal) || svTotal <= 0) {
            throw new IllegalArgumentException("闁诡剝顕цぐ澶婎啅椤旀槒绀?0闁挎稑鏈Λ銈呪枖閺団槅鍚€缂?GRR");
        }

        double sdRepeatability = svRepeatability / 6.0;
        double sdReproducibility = svReproducibility / 6.0;
        double sdGrr = svGrr / 6.0;
        double sdPartToPart = svPartToPart / 6.0;
        double sdTotal = svTotal / 6.0;

        double varRepeatability = sdRepeatability * sdRepeatability;
        double varReproducibility = sdReproducibility * sdReproducibility;
        double varGrr = sdGrr * sdGrr;
        double varPartToPart = sdPartToPart * sdPartToPart;
        double varTotal = sdTotal * sdTotal;

        double pctContributionRepeatability = percent(varRepeatability, varTotal);
        double pctContributionReproducibility = percent(varReproducibility, varTotal);
        double pctContributionGrr = percent(varGrr, varTotal);
        double pctContributionPartToPart = percent(varPartToPart, varTotal);

        double pctStudyVarRepeatability = percent(svRepeatability, svTotal);
        double pctStudyVarReproducibility = percent(svReproducibility, svTotal);
        double pctStudyVarGrr = percent(svGrr, svTotal);
        double pctStudyVarPartToPart = percent(svPartToPart, svTotal);

        Double tolerance = request.getTolerance();
        Double pctToleranceRepeatability = null;
        Double pctToleranceReproducibility = null;
        Double pctToleranceGrr = null;
        Double pctTolerancePartToPart = null;
        if (tolerance != null && Double.isFinite(tolerance) && tolerance > 0) {
            pctToleranceRepeatability = percent(svRepeatability, tolerance);
            pctToleranceReproducibility = percent(svReproducibility, tolerance);
            pctToleranceGrr = percent(svGrr, tolerance);
            pctTolerancePartToPart = percent(svPartToPart, tolerance);
        }

                double ndc = (svGrr <= 0) ? 0.0 : 1.41 * svPartToPart / svGrr;
        List<AnalysisValidationItem> validationMessages = buildGrrValidationMessages(
                pctStudyVarGrr,
                ndc,
                tolerance,
                appraiserCount,
                partCount,
                trialCount
        );
        String assessmentLevel = grrAssessmentLevel(pctStudyVarGrr, ndc);
        return AnalysisGrrResponse.builder()
                .sampleCount(requiredCount)
                .appraiserCount(appraiserCount)
                .partCount(partCount)
                .trialCount(trialCount)
                .tolerance(tolerance)
                .grandMean(grandMean)
                .msPart(varPartToPart)
                .msAppraiser(varReproducibility)
                .msInteraction(0.0)
                .msRepeatability(varRepeatability)
                .varRepeatability(varRepeatability)
                .varAppraiser(varReproducibility)
                .varInteraction(0.0)
                .varReproducibility(varReproducibility)
                .varGrr(varGrr)
                .varPartToPart(varPartToPart)
                .varTotal(varTotal)
                .sdRepeatability(sdRepeatability)
                .sdReproducibility(sdReproducibility)
                .sdGrr(sdGrr)
                .sdPartToPart(sdPartToPart)
                .sdTotal(sdTotal)
                .svRepeatability(svRepeatability)
                .svReproducibility(svReproducibility)
                .svGrr(svGrr)
                .svPartToPart(svPartToPart)
                .svTotal(svTotal)
                .pctContributionRepeatability(pctContributionRepeatability)
                .pctContributionReproducibility(pctContributionReproducibility)
                .pctContributionGrr(pctContributionGrr)
                .pctContributionPartToPart(pctContributionPartToPart)
                .pctStudyVarRepeatability(pctStudyVarRepeatability)
                .pctStudyVarReproducibility(pctStudyVarReproducibility)
                .pctStudyVarGrr(pctStudyVarGrr)
                .pctStudyVarPartToPart(pctStudyVarPartToPart)
                .pctToleranceRepeatability(pctToleranceRepeatability)
                .pctToleranceReproducibility(pctToleranceReproducibility)
                .pctToleranceGrr(pctToleranceGrr)
                .pctTolerancePartToPart(pctTolerancePartToPart)
                .ndc(ndc)
                .summary(grrSummary(pctStudyVarGrr, ndc))
                .assessmentLevel(assessmentLevel)
                .professionalConclusion(grrConclusion(assessmentLevel, pctStudyVarGrr, ndc))
                .recommendedAction(grrRecommendedAction(assessmentLevel, validationMessages))
                .readyForReport(isReadyForReport(validationMessages))
                .rulesVersion("grr-v1")
                .validationMessages(validationMessages)
                .build();
    }
    public byte[] exportGrrFullReport(AnalysisGrrRequest request) throws IOException {
        GrrDataset dataset = resolveGrrDataset(request);
        AnalysisGrrResponse result = calculateGrr(request);
        try (HSSFWorkbook workbook = new HSSFWorkbook();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            ReportStyles styles = createReportStyles(workbook);
            GrrDataRefs refs = buildDataSheet(workbook, styles, dataset);
            buildAnalysisSheet(workbook, styles, dataset, refs, result);
            workbook.setForceFormulaRecalculation(true);
            workbook.write(out);
            return out.toByteArray();
        }
    }

    public byte[] exportCapabilityProfessionalReport(AnalysisCapabilityRequest request) throws IOException {
        AnalysisCapabilityResponse capability = calculateCapability(request);
        List<Double> rawValues = resolveValues(request.getGridValues(), request.getRawValues());

        try (HSSFWorkbook workbook = new HSSFWorkbook();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            SimpleReportStyles styles = createSimpleReportStyles(workbook);

            HSSFSheet summary = workbook.createSheet("CPK_PPK_Report");
            for (int c = 0; c <= 7; c++) {
                setColumnWidth(summary, c, c == 0 ? 18 : 14);
            }
            setText(row(summary, 0), 0, "CPK/PPK Professional Report", styles.title());
            summary.addMergedRegion(new CellRangeAddress(0, 0, 0, 7));

            HSSFRow meta = row(summary, 2);
            setText(meta, 0, "Report Date", styles.label());
            setText(meta, 1, LocalDate.now().toString(), styles.text());
            setText(meta, 2, "Chart Type", styles.label());
            setText(meta, 3, capability.getChartType(), styles.text());
            setText(meta, 4, "Sample Count", styles.label());
            setNumber(meta, 5, capability.getSampleCount(), styles.number0());
            setText(meta, 6, "Subgroup Size", styles.label());
            setNumber(meta, 7, capability.getSubgroupSize(), styles.number0());

            setText(row(summary, 4), 0, "Capability Summary", styles.section());
            summary.addMergedRegion(new CellRangeAddress(4, 4, 0, 7));
            HSSFRow param = row(summary, 5);
            setText(param, 0, "LSL", styles.label()); setNumber(param, 1, capability.getLsl(), styles.number4());
            setText(param, 2, "USL", styles.label()); setNumber(param, 3, capability.getUsl(), styles.number4());
            setText(param, 4, "Target", styles.label()); setNumber(param, 5, capability.getTarget(), styles.number4());
            setText(param, 6, "Mean", styles.label()); setNumber(param, 7, capability.getMean(), styles.number6());

            HSSFRow param2 = row(summary, 6);
            setText(param2, 0, "Sigma Within", styles.label()); setNumber(param2, 1, capability.getSigmaWithin(), styles.number6());
            setText(param2, 2, "Sigma Overall", styles.label()); setNumber(param2, 3, capability.getSigmaOverall(), styles.number6());
            setText(param2, 4, "Min", styles.label()); setNumber(param2, 5, capability.getMin(), styles.number4());
            setText(param2, 6, "Max", styles.label()); setNumber(param2, 7, capability.getMax(), styles.number4());

            setText(row(summary, 8), 0, "闁煎疇妫勬慨蹇涘箰閸ャ劎鍨?, styles.section());
            summary.addMergedRegion(new CellRangeAddress(8, 8, 0, 7));
            HSSFRow idx1 = row(summary, 9);
            setText(idx1, 0, "CPK", styles.label()); setNumber(idx1, 1, capability.getCpk(), styles.number4());
            setText(idx1, 2, "CP", styles.label()); setNumber(idx1, 3, capability.getCp(), styles.number4());
            setText(idx1, 4, "PPK", styles.label()); setNumber(idx1, 5, capability.getPpk(), styles.number4());
            setText(idx1, 6, "PP", styles.label()); setNumber(idx1, 7, capability.getPp(), styles.number4());

            HSSFRow idx2 = row(summary, 10);
            setText(idx2, 0, "CPL", styles.label()); setNumber(idx2, 1, capability.getCpl(), styles.number4());
            setText(idx2, 2, "CPU", styles.label()); setNumber(idx2, 3, capability.getCpu(), styles.number4());
            setText(idx2, 4, "PPL", styles.label()); setNumber(idx2, 5, capability.getPpl(), styles.number4());
            setText(idx2, 6, "PPU", styles.label()); setNumber(idx2, 7, capability.getPpu(), styles.number4());

            HSSFRow ppm = row(summary, 11);
            setText(ppm, 0, "Observed PPM Total", styles.label()); setNumber(ppm, 1, capability.getObservedPpmTotal(), styles.number2());
            setText(ppm, 2, "Pred PPM (Within)", styles.label()); setNumber(ppm, 3, capability.getPredictedPpmTotalWithin(), styles.number2());
            setText(ppm, 4, "Pred PPM (Overall)", styles.label()); setNumber(ppm, 5, capability.getPredictedPpmTotalOverall(), styles.number2());
            setText(ppm, 6, "Conclusion", styles.label()); setText(ppm, 7, capability.getSummary(), styles.text());

            HSSFSheet raw = workbook.createSheet("RawValues");
            setColumnWidth(raw, 0, 10);
            setColumnWidth(raw, 1, 16);
            setText(row(raw, 0), 0, "Index", styles.header());
            setText(row(raw, 0), 1, "Sample Value", styles.header());
            for (int i = 0; i < rawValues.size(); i++) {
                HSSFRow rr = row(raw, i + 1);
                setNumber(rr, 0, i + 1, styles.number0());
                setNumber(rr, 1, rawValues.get(i), styles.number6());
            }

            HSSFSheet bins = workbook.createSheet("HistogramBins");
            setText(row(bins, 0), 0, "Lower", styles.header());
            setText(row(bins, 0), 1, "Upper", styles.header());
            setText(row(bins, 0), 2, "Center", styles.header());
            setText(row(bins, 0), 3, "Count", styles.header());
            for (int i = 0; i < capability.getHistogram().size(); i++) {
                AnalysisHistogramBin bin = capability.getHistogram().get(i);
                HSSFRow br = row(bins, i + 1);
                setNumber(br, 0, bin.getLower(), styles.number6());
                setNumber(br, 1, bin.getUpper(), styles.number6());
                setNumber(br, 2, bin.getCenter(), styles.number6());
                setNumber(br, 3, bin.getCount(), styles.number0());
            }

            workbook.write(out);
            return out.toByteArray();
        }
    }

    public byte[] exportRepeatabilityProfessionalReport(AnalysisRepeatabilityRequest request) throws IOException {
        RepeatabilityResult rr = calculateRepeatability(request);
        try (HSSFWorkbook workbook = new HSSFWorkbook();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            SimpleReportStyles styles = createSimpleReportStyles(workbook);

            HSSFSheet summary = workbook.createSheet("Repeatability_Report");
            for (int c = 0; c <= 7; c++) {
                setColumnWidth(summary, c, c == 0 ? 18 : 14);
            }
            setText(row(summary, 0), 0, "Repeatability Professional Report", styles.title());
            summary.addMergedRegion(new CellRangeAddress(0, 0, 0, 7));

            HSSFRow meta = row(summary, 2);
            setText(meta, 0, "Report Date", styles.label()); setText(meta, 1, LocalDate.now().toString(), styles.text());
            setText(meta, 2, "Part Count", styles.label()); setNumber(meta, 3, rr.partCount(), styles.number0());
            setText(meta, 4, "闂佹彃绉撮ˇ鎻掆枎閳╁啯娈?, styles.label()); setNumber(meta, 5, rr.trialCount(), styles.number0());
            setText(meta, 6, "闁哄秹鏀卞﹢浼存倷鐟欏嫭娈?, styles.label()); setNumber(meta, 7, rr.sampleCount(), styles.number0());

            setText(row(summary, 4), 0, "闁稿繑濞婇弫顓㈠箰閸ャ劎鍨?, styles.section());
            summary.addMergedRegion(new CellRangeAddress(4, 4, 0, 7));
            HSSFRow k1 = row(summary, 5);
            setText(k1, 0, "Rbar", styles.label()); setNumber(k1, 1, rr.rbar(), styles.number6());
            setText(k1, 2, "Sigma Repeatability", styles.label()); setNumber(k1, 3, rr.sigmaRepeatability(), styles.number6());
            setText(k1, 4, "EV (6sigma)", styles.label()); setNumber(k1, 5, rr.ev(), styles.number4());
            setText(k1, 6, "%Tolerance", styles.label()); setText(k1, 7, pctText(rr.pctTolerance()), styles.text());

            HSSFRow k2 = row(summary, 6);
            setText(k2, 0, "R UCL/LCL", styles.label());
            setText(k2, 1, String.format(Locale.ROOT, "%.4f / %.4f", rr.rUcl(), rr.rLcl()), styles.text());
            setText(k2, 2, "Xbar UCL/LCL", styles.label());
            setText(k2, 3, String.format(Locale.ROOT, "%.4f / %.4f", rr.xUcl(), rr.xLcl()), styles.text());
            setText(k2, 4, "閻犲洤瀚悳?, styles.label());
            setText(k2, 5, rr.summary(), styles.text());
            summary.addMergedRegion(new CellRangeAddress(6, 6, 5, 7));

            HSSFSheet data = workbook.createSheet("RawData");
            setColumnWidth(data, 0, 10);
            for (int t = 0; t < rr.trialCount(); t++) {
                setColumnWidth(data, t + 1, 12);
            }
            setColumnWidth(data, rr.trialCount() + 1, 12);
            setColumnWidth(data, rr.trialCount() + 2, 12);
            HSSFRow head = row(data, 0);
            setText(head, 0, "Part", styles.header());
            for (int t = 0; t < rr.trialCount(); t++) {
                setText(head, t + 1, "Trial " + (t + 1), styles.header());
            }
            setText(head, rr.trialCount() + 1, "Mean", styles.header());
            setText(head, rr.trialCount() + 2, "Range", styles.header());

            for (int p = 0; p < rr.partCount(); p++) {
                HSSFRow dr = row(data, p + 1);
                setText(dr, 0, "C" + (p + 1), styles.text());
                for (int t = 0; t < rr.trialCount(); t++) {
                    setNumber(dr, t + 1, rr.data()[p][t], styles.number6());
                }
                setNumber(dr, rr.trialCount() + 1, rr.partMeans()[p], styles.number6());
                setNumber(dr, rr.trialCount() + 2, rr.partRanges()[p], styles.number6());
            }

            workbook.write(out);
            return out.toByteArray();
        }
    }

    public byte[] exportReproducibilityProfessionalReport(AnalysisGrrRequest request) throws IOException {
        GrrDataset ds = resolveGrrDataset(request);
        AnalysisGrrResponse grr = calculateGrr(request);

        double[] operatorMeans = new double[ds.appraiserCount()];
        for (int o = 0; o < ds.appraiserCount(); o++) {
            double sum = 0.0;
            for (int p = 0; p < ds.partCount(); p++) {
                for (int t = 0; t < ds.trialCount(); t++) {
                    sum += ds.data()[o][p][t];
                }
            }
            operatorMeans[o] = sum / (ds.partCount() * ds.trialCount());
        }
        double operatorMeanDiff = Arrays.stream(operatorMeans).max().orElse(0.0)
                - Arrays.stream(operatorMeans).min().orElse(0.0);

        try (HSSFWorkbook workbook = new HSSFWorkbook();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            SimpleReportStyles styles = createSimpleReportStyles(workbook);

            HSSFSheet summary = workbook.createSheet("Reproducibility_Report");
            for (int c = 0; c <= 7; c++) {
                setColumnWidth(summary, c, c == 0 ? 18 : 14);
            }
            setText(row(summary, 0), 0, "Reproducibility Professional Report", styles.title());
            summary.addMergedRegion(new CellRangeAddress(0, 0, 0, 7));

            HSSFRow meta = row(summary, 2);
            setText(meta, 0, "Report Date", styles.label()); setText(meta, 1, LocalDate.now().toString(), styles.text());
            setText(meta, 2, "闁瑰灝绉崇紞鏃堟嚀閸涱喗娈?, styles.label()); setNumber(meta, 3, grr.getAppraiserCount(), styles.number0());
            setText(meta, 4, "Part Count", styles.label()); setNumber(meta, 5, grr.getPartCount(), styles.number0());
            setText(meta, 6, "闂佹彃绉撮ˇ鎻掆枎閳╁啯娈?, styles.label()); setNumber(meta, 7, grr.getTrialCount(), styles.number0());

            setText(row(summary, 4), 0, "闁稿繑濞婇弫顓㈠箰閸ャ劎鍨?, styles.section());
            summary.addMergedRegion(new CellRangeAddress(4, 4, 0, 7));
            HSSFRow k1 = row(summary, 5);
            setText(k1, 0, "AV (6sigma)", styles.label()); setNumber(k1, 1, grr.getSvReproducibility(), styles.number4());
            setText(k1, 2, "EV (6閿?", styles.label()); setNumber(k1, 3, grr.getSvRepeatability(), styles.number4());
            setText(k1, 4, "%StudyVar AV", styles.label()); setNumber(k1, 5, grr.getPctStudyVarReproducibility(), styles.percent2());
            setText(k1, 6, "%Tolerance AV", styles.label()); setText(k1, 7, pctText(grr.getPctToleranceReproducibility()), styles.text());

            HSSFRow k2 = row(summary, 6);
            setText(k2, 0, "Operator Mean Diff", styles.label()); setNumber(k2, 1, operatorMeanDiff, styles.number6());
            setText(k2, 2, "Conclusion", styles.label()); setText(k2, 3, grrSummary(grr.getPctStudyVarReproducibility(), grr.getNdc()), styles.text());
            summary.addMergedRegion(new CellRangeAddress(6, 6, 3, 7));

            HSSFSheet data = workbook.createSheet("RawData");
            setColumnWidth(data, 0, 10);
            setColumnWidth(data, 1, 10);
            for (int p = 0; p < ds.partCount(); p++) {
                setColumnWidth(data, p + 2, 12);
            }
            HSSFRow head = row(data, 0);
            setText(head, 0, "Operator", styles.header());
            setText(head, 1, "Trial", styles.header());
            for (int p = 0; p < ds.partCount(); p++) {
                setText(head, p + 2, "C" + (p + 1), styles.header());
            }
            int rowIndex = 1;
            for (int o = 0; o < ds.appraiserCount(); o++) {
                for (int t = 0; t < ds.trialCount(); t++) {
                    HSSFRow dr = row(data, rowIndex++);
                    setText(dr, 0, toOperatorLabel(o), styles.text());
                    setNumber(dr, 1, t + 1, styles.number0());
                    for (int p = 0; p < ds.partCount(); p++) {
                        setNumber(dr, p + 2, ds.data()[o][p][t], styles.number6());
                    }
                }
            }

            workbook.write(out);
            return out.toByteArray();
        }
    }

    public byte[] exportLinearityProfessionalReport(AnalysisLinearityRequest request) throws IOException {
        LinearityResult linearity = calculateLinearity(request);
        try (HSSFWorkbook workbook = new HSSFWorkbook();
             ByteArrayOutputStream out = new ByteArrayOutputStream()) {
            SimpleReportStyles styles = createSimpleReportStyles(workbook);

            HSSFSheet summary = workbook.createSheet("Linearity_Report");
            for (int c = 0; c <= 7; c++) {
                setColumnWidth(summary, c, c == 0 ? 18 : 14);
            }
            setText(row(summary, 0), 0, "Linearity Professional Report", styles.title());
            summary.addMergedRegion(new CellRangeAddress(0, 0, 0, 7));

            HSSFRow meta = row(summary, 2);
            setText(meta, 0, "闁汇垻鍠愰崹姘跺籍閵夛附鍩?, styles.label()); setText(meta, 1, LocalDate.now().toString(), styles.text());
            setText(meta, 2, "闁哄牆顦伴弲銉╂倷闁稓绉?, styles.label()); setNumber(meta, 3, linearity.sampleCount(), styles.number0());
            setText(meta, 4, "Mean Bias", styles.label()); setNumber(meta, 5, linearity.meanBias(), styles.number6());
            setText(meta, 6, "Max Abs Bias", styles.label()); setNumber(meta, 7, linearity.maxAbsBias(), styles.number6());

            setText(row(summary, 4), 0, "闁搞儳鍋涚紞濠勭磼閹惧浜?, styles.section());
            summary.addMergedRegion(new CellRangeAddress(4, 4, 0, 7));
            HSSFRow reg = row(summary, 5);
            setText(reg, 0, "Slope", styles.label()); setNumber(reg, 1, linearity.slope(), styles.number6());
            setText(reg, 2, "Intercept", styles.label()); setNumber(reg, 3, linearity.intercept(), styles.number6());
            setText(reg, 4, "R2", styles.label()); setNumber(reg, 5, linearity.r2(), styles.number6());
            setText(reg, 6, "%Tolerance", styles.label()); setText(reg, 7, pctText(linearity.pctTolerance()), styles.text());

            HSSFRow conclusion = row(summary, 6);
            setText(conclusion, 0, "Conclusion", styles.label());
            setText(conclusion, 1, linearity.summary(), styles.text());
            summary.addMergedRegion(new CellRangeAddress(6, 6, 1, 7));

            HSSFSheet data = workbook.createSheet("RawData");
            int maxMeasures = linearity.points().stream().mapToInt(p -> p.measures().size()).max().orElse(0);
            setColumnWidth(data, 0, 8);
            setColumnWidth(data, 1, 14);
            for (int m = 0; m < maxMeasures; m++) {
                setColumnWidth(data, m + 2, 12);
            }
            setColumnWidth(data, maxMeasures + 2, 14);
            setColumnWidth(data, maxMeasures + 3, 14);

            HSSFRow head = row(data, 0);
            setText(head, 0, "Index", styles.header());
            setText(head, 1, "Reference", styles.header());
            for (int m = 0; m < maxMeasures; m++) {
                setText(head, m + 2, "Trial " + (m + 1), styles.header());
            }
            setText(head, maxMeasures + 2, "妤犵偛鍟垮搴∶圭€ｎ喖娅?, styles.header());
            setText(head, maxMeasures + 3, "Bias", styles.header());

            for (int i = 0; i < linearity.points().size(); i++) {
                LinearityPoint point = linearity.points().get(i);
                HSSFRow dr = row(data, i + 1);
                setNumber(dr, 0, i + 1, styles.number0());
                setNumber(dr, 1, point.reference(), styles.number6());
                for (int m = 0; m < point.measures().size(); m++) {
                    setNumber(dr, m + 2, point.measures().get(m), styles.number6());
                }
                setNumber(dr, maxMeasures + 2, point.meanMeasure(), styles.number6());
                setNumber(dr, maxMeasures + 3, point.bias(), styles.number6());
            }

            workbook.write(out);
            return out.toByteArray();
        }
    }

    private RepeatabilityResult calculateRepeatability(AnalysisRepeatabilityRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("Request payload cannot be null");
        }
        int partCount = requirePositive(request.getPartCount(), "Part count is required");
        int trialCount = requirePositive(request.getTrialCount(), "Trial count is required");
        if (partCount < 2) {
            throw new IllegalArgumentException("Part count must be at least 2");
        }
        if (trialCount < 2) {
            throw new IllegalArgumentException("Trial count must be at least 2");
        }
        if (trialCount > 25) {
            throw new IllegalArgumentException("Trial count must be within 2~25");
        }

        List<Double> values = resolveValues(request.getGridValues(), request.getRawValues());
        int required = partCount * trialCount;
        if (values.size() < required) {
            throw new IllegalArgumentException("Sample count is insufficient, at least " + required + " values are required");
        }

        double[][] data = new double[partCount][trialCount];
        int idx = 0;
        for (int p = 0; p < partCount; p++) {
            for (int t = 0; t < trialCount; t++) {
                data[p][t] = values.get(idx++);
            }
        }

        double[] partMeans = new double[partCount];
        double[] partRanges = new double[partCount];
        for (int p = 0; p < partCount; p++) {
            List<Double> row = new ArrayList<>(trialCount);
            for (int t = 0; t < trialCount; t++) {
                row.add(data[p][t]);
            }
            partMeans[p] = mean(row);
            partRanges[p] = range(row);
        }

        double rbar = mean(arrayToList(partRanges));
        double sigmaRepeatability = rbar / requireD2(trialCount, "闂佹彃绉撮ˇ鎻掆枎閳╁啯娈?);
        double ev = sigmaRepeatability * 6.0;
        double xbarbar = mean(arrayToList(partMeans));
        double a2 = nearestConstant(A2_BY_TRIAL, trialCount, 1.023);
        double d3 = nearestConstant(D3_BY_TRIAL, trialCount, 0.0);
        double d4 = nearestConstant(D4_BY_TRIAL, trialCount, 2.574);

        Double tolerance = request.getTolerance();
        Double pctTolerance = null;
        if (tolerance != null && Double.isFinite(tolerance) && tolerance > 0) {
            pctTolerance = percent(ev, tolerance);
        }

        return new RepeatabilityResult(
                required, partCount, trialCount,
                data, partMeans, partRanges,
                rbar, sigmaRepeatability, ev,
                pctTolerance, xbarbar,
                rbar * d4, Math.max(rbar * d3, 0.0),
                xbarbar + a2 * rbar, xbarbar - a2 * rbar,
                repeatabilitySummary(pctTolerance)
        );
    }

    private LinearityResult calculateLinearity(AnalysisLinearityRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("Request payload cannot be null");
        }
        List<List<Double>> grid = request.getGridValues();
        if (grid == null || grid.isEmpty()) {
            throw new IllegalArgumentException("Linearity analysis requires at least 3 valid rows");
        }

        List<LinearityPoint> points = new ArrayList<>();
        for (List<Double> row : grid) {
            if (row == null || row.size() < 2) {
                continue;
            }
            Double ref = row.get(0);
            if (ref == null || !Double.isFinite(ref)) {
                continue;
            }
            List<Double> measures = new ArrayList<>();
            for (int i = 1; i < row.size(); i++) {
                Double v = row.get(i);
                if (v != null && Double.isFinite(v)) {
                    measures.add(v);
                }
            }
            if (measures.isEmpty()) {
                continue;
            }
            double meanMeasure = mean(measures);
            points.add(new LinearityPoint(ref, measures, meanMeasure, meanMeasure - ref));
        }

        if (points.size() < 3) {
            throw new IllegalArgumentException("缂佺偓瀵ч埀顑啫鐎婚柡瀣姌閸わ妇浜搁幋锔戒粯閻?濞戞搩浜濆﹢渚€寮崼銏犱化濞?);
        }

        double xMean = mean(points.stream().map(LinearityPoint::reference).toList());
        double yMean = mean(points.stream().map(LinearityPoint::bias).toList());
        double sxx = 0.0;
        double sxy = 0.0;
        for (LinearityPoint point : points) {
            sxx += Math.pow(point.reference() - xMean, 2);
            sxy += (point.reference() - xMean) * (point.bias() - yMean);
        }
        double slope = (Math.abs(sxx) < 1e-12) ? 0.0 : sxy / sxx;
        double intercept = yMean - slope * xMean;

        double ssTot = points.stream().mapToDouble(p -> Math.pow(p.bias() - yMean, 2)).sum();
        double ssRes = points.stream().mapToDouble(p -> {
            double pred = intercept + slope * p.reference();
            return Math.pow(p.bias() - pred, 2);
        }).sum();
        double r2 = Math.abs(ssTot) < 1e-12 ? 1.0 : Math.max(0.0, 1.0 - (ssRes / ssTot));

        double meanBias = mean(points.stream().map(LinearityPoint::bias).toList());
        double maxAbsBias = points.stream().mapToDouble(p -> Math.abs(p.bias())).max().orElse(0.0);

        Double tolerance = request.getTolerance();
        Double pctTolerance = null;
        if (tolerance != null && Double.isFinite(tolerance) && tolerance > 0) {
            pctTolerance = percent(maxAbsBias, tolerance);
        }

        return new LinearityResult(
                points.size(), points,
                slope, intercept, r2,
                meanBias, maxAbsBias,
                pctTolerance,
                linearitySummary(pctTolerance, slope)
        );
    }

    private GrrDataset resolveGrrDataset(AnalysisGrrRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("Request payload cannot be null");
        }
        int appraiserCount = requirePositive(request.getAppraiserCount(), "Appraiser count must be greater than 0");
        int partCount = requirePositive(request.getPartCount(), "Part count must be greater than 0");
        int trialCount = requirePositive(request.getTrialCount(), "Trial count must be greater than 0");
        if (appraiserCount < 2) {
            throw new IllegalArgumentException("Appraiser count must be at least 2");
        }
        if (partCount < 2) {
            throw new IllegalArgumentException("Part count must be at least 2");
        }
        if (trialCount < 2) {
            throw new IllegalArgumentException("Trial count must be at least 2");
        }

        List<Double> rawValues = resolveValues(request.getGridValues(), request.getRawValues());
        int requiredCount = appraiserCount * partCount * trialCount;
        if (rawValues.size() < requiredCount) {
            throw new IllegalArgumentException("Sample count is insufficient, at least " + requiredCount + " values are required");
        }

        List<Double> values = rawValues.subList(0, requiredCount);
        double[][][] data = new double[appraiserCount][partCount][trialCount];
        int index = 0;
        for (int o = 0; o < appraiserCount; o++) {
            for (int p = 0; p < partCount; p++) {
                for (int t = 0; t < trialCount; t++) {
                    data[o][p][t] = values.get(index++);
                }
            }
        }
        return new GrrDataset(appraiserCount, partCount, trialCount, data);
    }

    private GrrDataRefs buildDataSheet(HSSFWorkbook workbook, ReportStyles styles, GrrDataset ds) {
        HSSFSheet sheet = workbook.createSheet("DataSheet");
        int partStartCol = 2;
        int partEndCol = partStartCol + ds.partCount() - 1;
        int meanCol = partEndCol + 1;
        int headerRow = 3;
        int partHeaderRow = 4;
        int dataStartRow = 5;
        int groupHeight = ds.trialCount() + 2;

        setColumnWidth(sheet, 0, 20);
        setColumnWidth(sheet, 1, 10);
        for (int c = partStartCol; c <= partEndCol; c++) {
            setColumnWidth(sheet, c, 10);
        }
        setColumnWidth(sheet, meanCol, 12);
        setColumnWidth(sheet, meanCol + 2, 14);
        setColumnWidth(sheet, meanCol + 3, 10);

        HSSFRow row1 = row(sheet, 0);
        setText(row1, Math.max(meanCol - 2, 0), "Form No.", styles.metaLabel());
        setText(row1, meanCol, "J-27-05-B", styles.metaValue());

        HSSFRow row2 = row(sheet, 1);
        setText(row2, 0, "Gage R&R raw data sheet", styles.title());
        sheet.addMergedRegion(new CellRangeAddress(1, 1, 0, meanCol));

        HSSFRow row3 = row(sheet, 2);
        setText(row3, 0, "Specification", styles.metaLabel());
        setText(row3, Math.max(meanCol - 1, 0), "J-27-05-B", styles.metaValue());

        HSSFRow row4 = row(sheet, headerRow);
        setText(row4, 0, "Trial", styles.header());
        setText(row4, partStartCol, "Part Number", styles.header());
        setText(row4, meanCol, "Mean", styles.header());

        HSSFRow row5 = row(sheet, partHeaderRow);
        for (int p = 0; p < ds.partCount(); p++) {
            setNumber(row5, partStartCol + p, p + 1, styles.headerNumber());
        }

        sheet.addMergedRegion(new CellRangeAddress(headerRow, partHeaderRow, 0, 1));
        sheet.addMergedRegion(new CellRangeAddress(headerRow, headerRow, partStartCol, partEndCol));
        sheet.addMergedRegion(new CellRangeAddress(headerRow, partHeaderRow, meanCol, meanCol));

        List<Integer> meanRows = new ArrayList<>();
        List<Integer> rangeRows = new ArrayList<>();
        int serial = 1;

        for (int o = 0; o < ds.appraiserCount(); o++) {
            int operatorStartRow = dataStartRow + o * groupHeight;
            String operatorLabel = toOperatorLabel(o);
            for (int t = 0; t < ds.trialCount(); t++) {
                int r = operatorStartRow + t;
                HSSFRow row = row(sheet, r);
                setText(row, 0, t == 0 ? serial + ". " + operatorLabel : serial + ".", styles.textCell());
                setText(row, 1, String.valueOf(t + 1), styles.centerTextCell());
                for (int p = 0; p < ds.partCount(); p++) {
                    setNumber(row, partStartCol + p, ds.data()[o][p][t], styles.blueNumber3());
                }
                setFormula(row, meanCol, avgRangeFormula(r, partStartCol, partEndCol), styles.number4());
                serial++;
            }

            int meanRow = operatorStartRow + ds.trialCount();
            HSSFRow rowMean = row(sheet, meanRow);
            setText(rowMean, 0, serial + ".", styles.textCell());
            setText(rowMean, 1, "Mean", styles.centerTextCell());
            for (int p = 0; p < ds.partCount(); p++) {
                String col = colName(partStartCol + p);
                String formula = "AVERAGE(" + col + (operatorStartRow + 1) + ":" + col + (operatorStartRow + ds.trialCount()) + ")";
                setFormula(rowMean, partStartCol + p, formula, styles.number3());
            }
            setFormula(rowMean, meanCol, avgRangeFormula(meanRow, partStartCol, partEndCol), styles.meanGreen4());
            meanRows.add(meanRow);
            serial++;

            int rangeRow = meanRow + 1;
            HSSFRow rowRange = row(sheet, rangeRow);
            setText(rowRange, 0, serial + ".", styles.textCell());
            setText(rowRange, 1, "Range", styles.centerTextCell());
            for (int p = 0; p < ds.partCount(); p++) {
                String col = colName(partStartCol + p);
                String formula = "MAX(" + col + (operatorStartRow + 1) + ":" + col + (operatorStartRow + ds.trialCount())
                        + ")-MIN(" + col + (operatorStartRow + 1) + ":" + col + (operatorStartRow + ds.trialCount()) + ")";
                setFormula(rowRange, partStartCol + p, formula, styles.number3());
            }
            setFormula(rowRange, meanCol, avgRangeFormula(rangeRow, partStartCol, partEndCol), styles.meanGreen4());
            rangeRows.add(rangeRow);
            serial++;
        }

        int partMeanRow = dataStartRow + ds.appraiserCount() * groupHeight;
        HSSFRow rowPartMean = row(sheet, partMeanRow);
        setText(rowPartMean, 0, serial + ".", styles.textCell());
        setText(rowPartMean, 1, "Part Mean", styles.centerTextCell());
        for (int p = 0; p < ds.partCount(); p++) {
            String col = colName(partStartCol + p);
            List<String> blocks = new ArrayList<>();
            for (int o = 0; o < ds.appraiserCount(); o++) {
                int start = dataStartRow + o * groupHeight;
                int end = start + ds.trialCount() - 1;
                blocks.add(col + (start + 1) + ":" + col + (end + 1));
            }
            setFormula(rowPartMean, partStartCol + p, "AVERAGE(" + String.join(",", blocks) + ")", styles.number3());
        }
        setFormula(rowPartMean, meanCol, avgRangeFormula(partMeanRow, partStartCol, partEndCol), styles.meanYellow4());
        serial++;

        int partRangeRow = partMeanRow + 1;
        HSSFRow rowPartRange = row(sheet, partRangeRow);
        setText(rowPartRange, 0, serial + ".", styles.textCell());
        setText(rowPartRange, 1, "Part Range", styles.centerTextCell());
        for (int p = 0; p < ds.partCount(); p++) {
            String col = colName(partStartCol + p);
            List<String> refs = new ArrayList<>();
            for (Integer mr : meanRows) {
                refs.add(col + (mr + 1));
            }
            String refsExpr = String.join(",", refs);
            setFormula(rowPartRange, partStartCol + p, "MAX(" + refsExpr + ")-MIN(" + refsExpr + ")", styles.number3());
        }
        setFormula(rowPartRange, meanCol, avgRangeFormula(partRangeRow, partStartCol, partEndCol), styles.meanYellow4());

        int calcStartRow = partRangeRow + 2;
        HSSFRow rbarRow = row(sheet, calcStartRow);
        setText(rbarRow, 0, "Rbar", styles.metaLabel());
        List<String> rangeMeanRefs = new ArrayList<>();
        for (Integer rr : rangeRows) {
            rangeMeanRefs.add(colName(meanCol) + (rr + 1));
        }
        setFormula(rbarRow, 1, "AVERAGE(" + String.join(",", rangeMeanRefs) + ")", styles.number4());

        HSSFRow xDiffRow = row(sheet, calcStartRow + 1);
        setText(xDiffRow, 0, "XDIFF", styles.metaLabel());
        List<String> meanMeanRefs = new ArrayList<>();
        for (Integer mr : meanRows) {
            meanMeanRefs.add(colName(meanCol) + (mr + 1));
        }
        String meanExpr = String.join(",", meanMeanRefs);
        setFormula(xDiffRow, 1, "MAX(" + meanExpr + ")-MIN(" + meanExpr + ")", styles.number4());

        HSSFRow rpRow = row(sheet, calcStartRow + 2);
        setText(rpRow, 0, "RP", styles.metaLabel());
        String partRangeExpr = colName(partStartCol) + (partMeanRow + 1) + ":" + colName(partEndCol) + (partMeanRow + 1);
        setFormula(rpRow, 1, "MAX(" + partRangeExpr + ")-MIN(" + partRangeExpr + ")", styles.number4());

        HSSFRow noteRow = row(sheet, calcStartRow + 5);
        setText(noteRow, 0, "Reference formulas kept for backward compatibility and manual review.", styles.tip());
        sheet.addMergedRegion(new CellRangeAddress(calcStartRow + 5, calcStartRow + 5, 0, meanCol));

        HSSFRow refTitle = row(sheet, 5);
        setText(refTitle, meanCol + 2, "Reference", styles.metaLabel());
        HSSFRow refSub = row(sheet, 6);
        setText(refSub, meanCol + 2, "%R&R", styles.metaLabel());
        setText(refSub, meanCol + 3, "Ndc", styles.metaLabel());
        HSSFRow refVal = row(sheet, 7);
        setFormula(refVal, meanCol + 2, "'闂佸憡甯掑Λ娆撴倵?!D12", styles.number3());
        setFormula(refVal, meanCol + 3, "'闂佸憡甯掑Λ娆撴倵?!B18", styles.number3());

        sheet.createFreezePane(2, 5);
        return new GrrDataRefs(
                "B" + (calcStartRow + 1),
                "B" + (calcStartRow + 2),
                "B" + (calcStartRow + 3)
        );
    }

    private void buildAnalysisSheet(HSSFWorkbook workbook,
                                    ReportStyles styles,
                                    GrrDataset ds,
                                    GrrDataRefs refs,
                                    AnalysisGrrResponse result) {
        HSSFSheet sheet = workbook.createSheet("AnalysisSheet");
        for (int c = 0; c <= 7; c++) {
            setColumnWidth(sheet, c, c == 0 ? 20 : 14);
        }

        HSSFRow titleRow = row(sheet, 0);
        setText(titleRow, 0, "Gage R&R Analysis Summary", styles.title());
        sheet.addMergedRegion(new CellRangeAddress(0, 0, 0, 7));

        HSSFRow meta = row(sheet, 2);
        setText(meta, 0, "Part Count", styles.metaLabel());
        setNumber(meta, 1, ds.partCount(), styles.metaValueNumber());
        setText(meta, 2, "Appraiser Count", styles.metaLabel());
        setNumber(meta, 3, ds.appraiserCount(), styles.metaValueNumber());
        setText(meta, 4, "Trial Count", styles.metaLabel());
        setNumber(meta, 5, ds.trialCount(), styles.metaValueNumber());
        setText(meta, 6, "Report Date", styles.metaLabel());
        setText(meta, 7, LocalDate.now().toString(), styles.metaValue());

        HSSFRow section1 = row(sheet, 4);
        setText(section1, 0, "Core Calculation", styles.section());
        sheet.addMergedRegion(new CellRangeAddress(4, 4, 0, 7));

        double k1 = k1ForTrial(ds.trialCount());
        double k2 = kForCount(ds.appraiserCount());
        double k3 = kForCount(ds.partCount());

        HSSFRow base = row(sheet, 5);
        setText(base, 0, "Rbar", styles.label());
        setFormula(base, 1, "'闂佽桨鑳舵晶妤€鐣?!" + refs.rbarCell(), styles.number4());
        setText(base, 2, "XDIFF", styles.label());
        setFormula(base, 3, "'闂佽桨鑳舵晶妤€鐣?!" + refs.xDiffCell(), styles.number4());
        setText(base, 4, "RP", styles.label());
        setFormula(base, 5, "'闂佽桨鑳舵晶妤€鐣?!" + refs.rpCell(), styles.number4());
        setText(base, 6, "K1", styles.label());
        setNumber(base, 7, k1, styles.number4());

        HSSFRow kRow = row(sheet, 6);
        setText(kRow, 4, "K2", styles.label());
        setNumber(kRow, 5, k2, styles.number4());
        setText(kRow, 6, "K3", styles.label());
        setNumber(kRow, 7, k3, styles.number4());

        HSSFRow evRow = row(sheet, 7);
        setText(evRow, 0, "EV", styles.label());
        setFormula(evRow, 1, "B6*H6", styles.number4());
        setText(evRow, 2, "%EV", styles.label());
        setFormula(evRow, 3, "IF(B16=0,0,B8/B16*100)", styles.percent2());

        HSSFRow avRow = row(sheet, 9);
        setText(avRow, 0, "AV", styles.label());
        setFormula(avRow, 1, "SQRT(MAX((D6*F7)^2-(B8^2/(B3*F3)),0))", styles.number4());
        setText(avRow, 2, "%AV", styles.label());
        setFormula(avRow, 3, "IF(B16=0,0,B10/B16*100)", styles.percent2());

        HSSFRow rrRow = row(sheet, 11);
        setText(rrRow, 0, "R&R", styles.label());
        setFormula(rrRow, 1, "SQRT(B8^2+B10^2)", styles.number4());
        setText(rrRow, 2, "%R&R", styles.label());
        setFormula(rrRow, 3, "IF(B16=0,0,B12/B16*100)", styles.percent2Emphasis());

        HSSFRow pvRow = row(sheet, 13);
        setText(pvRow, 0, "PV", styles.label());
        setFormula(pvRow, 1, "F6*H7", styles.number4());
        setText(pvRow, 2, "%PV", styles.label());
        setFormula(pvRow, 3, "IF(B16=0,0,B14/B16*100)", styles.percent2());

        HSSFRow tvRow = row(sheet, 15);
        setText(tvRow, 0, "TV", styles.label());
        setFormula(tvRow, 1, "SQRT(B12^2+B14^2)", styles.number4());

        HSSFRow ndcRow = row(sheet, 17);
        setText(ndcRow, 0, "NDC", styles.label());
        setFormula(ndcRow, 1, "IF(B12=0,0,1.41*B14/B12)", styles.number2Emphasis());

        HSSFRow conclusion = row(sheet, 19);
        setText(conclusion, 0, "Conclusion", styles.label());
        setText(conclusion, 1, result.getSummary(), styles.conclusion());
        // Legacy formula-based conclusion removed during UTF-8 cleanup.
        // The runtime summary text above is now used directly.
        // Reserved for future formula restoration if needed.
        //
        sheet.addMergedRegion(new CellRangeAddress(19, 21, 1, 7));

        HSSFRow section2 = row(sheet, 23);
        setText(section2, 0, "闂佸搫鐗嗙粔瀛樻叏閻旂儤濯奸柨娑樺閺嗩剛绱撴担瑙勫鞍闁诲繐顦甸弫宥夊醇濠垫劕娈搁梺缁樻寙瀹ュ洨顦?, styles.section());
        sheet.addMergedRegion(new CellRangeAddress(23, 23, 0, 7));

        HSSFRow s1 = row(sheet, 24);
        setText(s1, 0, "GRR(6闁?", styles.label());
        setNumber(s1, 1, result.getSvGrr(), styles.number4());
        setText(s1, 2, "%StudyVar GRR", styles.label());
        setNumber(s1, 3, result.getPctStudyVarGrr(), styles.percent2Emphasis());

        HSSFRow s2 = row(sheet, 25);
        setText(s2, 0, "PV(6闁?", styles.label());
        setNumber(s2, 1, result.getSvPartToPart(), styles.number4());
        setText(s2, 2, "NDC", styles.label());
        setNumber(s2, 3, result.getNdc(), styles.number2Emphasis());

        HSSFRow s3 = row(sheet, 26);
        setText(s3, 0, "Summary", styles.label());
        setText(s3, 1, result.getSummary(), styles.metaValue());
        sheet.addMergedRegion(new CellRangeAddress(26, 26, 1, 7));
    }

    private ReportStyles createReportStyles(HSSFWorkbook workbook) {
        HSSFFont normalFont = workbook.createFont();
        normalFont.setFontName("Microsoft YaHei");
        normalFont.setFontHeightInPoints((short) 10);

        HSSFFont boldFont = workbook.createFont();
        boldFont.setFontName("Microsoft YaHei");
        boldFont.setBold(true);
        boldFont.setFontHeightInPoints((short) 10);

        HSSFFont titleFont = workbook.createFont();
        titleFont.setFontName("Microsoft YaHei");
        titleFont.setBold(true);
        titleFont.setFontHeightInPoints((short) 14);

        HSSFFont blueFont = workbook.createFont();
        blueFont.setFontName("Consolas");
        blueFont.setColor(IndexedColors.BLUE.getIndex());
        blueFont.setFontHeightInPoints((short) 10);

        short fmtNum2 = workbook.createDataFormat().getFormat("0.00");
        short fmtNum3 = workbook.createDataFormat().getFormat("0.000");
        short fmtNum4 = workbook.createDataFormat().getFormat("0.0000");

        HSSFCellStyle title = style(workbook, titleFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, false);
        HSSFCellStyle metaLabel = style(workbook, boldFont, HorizontalAlignment.LEFT, VerticalAlignment.CENTER, IndexedColors.GREY_25_PERCENT.getIndex(), true);
        HSSFCellStyle metaValue = style(workbook, normalFont, HorizontalAlignment.LEFT, VerticalAlignment.CENTER, null, true);
        HSSFCellStyle metaValueNumber = style(workbook, normalFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, true);
        metaValueNumber.setDataFormat(fmtNum2);

        HSSFCellStyle header = style(workbook, boldFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, IndexedColors.GREY_25_PERCENT.getIndex(), true);
        HSSFCellStyle headerNumber = style(workbook, boldFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, IndexedColors.GREY_25_PERCENT.getIndex(), true);
        headerNumber.setDataFormat(fmtNum2);

        HSSFCellStyle textCell = style(workbook, normalFont, HorizontalAlignment.LEFT, VerticalAlignment.CENTER, null, true);
        HSSFCellStyle centerTextCell = style(workbook, normalFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, true);
        HSSFCellStyle blueNumber3 = style(workbook, blueFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, true);
        blueNumber3.setDataFormat(fmtNum3);
        HSSFCellStyle number3 = style(workbook, normalFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, true);
        number3.setDataFormat(fmtNum3);
        HSSFCellStyle number4 = style(workbook, normalFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, true);
        number4.setDataFormat(fmtNum4);
        HSSFCellStyle meanGreen4 = style(workbook, normalFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, IndexedColors.LIGHT_GREEN.getIndex(), true);
        meanGreen4.setDataFormat(fmtNum4);
        HSSFCellStyle meanYellow4 = style(workbook, normalFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, IndexedColors.LIGHT_YELLOW.getIndex(), true);
        meanYellow4.setDataFormat(fmtNum4);

        HSSFCellStyle section = style(workbook, boldFont, HorizontalAlignment.LEFT, VerticalAlignment.CENTER, IndexedColors.LIGHT_CORNFLOWER_BLUE.getIndex(), true);
        HSSFCellStyle label = style(workbook, boldFont, HorizontalAlignment.LEFT, VerticalAlignment.CENTER, IndexedColors.LEMON_CHIFFON.getIndex(), true);
        HSSFCellStyle percent2 = style(workbook, normalFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, true);
        percent2.setDataFormat(fmtNum2);
        HSSFCellStyle percent2Emphasis = style(workbook, boldFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, IndexedColors.ROSE.getIndex(), true);
        percent2Emphasis.setDataFormat(fmtNum2);
        HSSFCellStyle number2Emphasis = style(workbook, boldFont, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, IndexedColors.LIGHT_GREEN.getIndex(), true);
        number2Emphasis.setDataFormat(fmtNum2);
        HSSFCellStyle conclusion = style(workbook, normalFont, HorizontalAlignment.LEFT, VerticalAlignment.TOP, null, true);
        conclusion.setWrapText(true);
        HSSFCellStyle tip = style(workbook, normalFont, HorizontalAlignment.LEFT, VerticalAlignment.CENTER, null, false);

        return new ReportStyles(
                title, metaLabel, metaValue, metaValueNumber,
                header, headerNumber,
                textCell, centerTextCell,
                blueNumber3, number3, number4,
                meanGreen4, meanYellow4,
                section, label,
                percent2, percent2Emphasis, number2Emphasis,
                conclusion, tip
        );
    }

    private HSSFCellStyle style(HSSFWorkbook workbook,
                                HSSFFont font,
                                HorizontalAlignment hAlign,
                                VerticalAlignment vAlign,
                                Short fillColor,
                                boolean withBorder) {
        HSSFCellStyle style = workbook.createCellStyle();
        style.setFont(font);
        style.setAlignment(hAlign);
        style.setVerticalAlignment(vAlign);
        if (withBorder) {
            style.setBorderTop(BorderStyle.THIN);
            style.setBorderBottom(BorderStyle.THIN);
            style.setBorderLeft(BorderStyle.THIN);
            style.setBorderRight(BorderStyle.THIN);
        }
        if (fillColor != null) {
            style.setFillForegroundColor(fillColor);
            style.setFillPattern(FillPatternType.SOLID_FOREGROUND);
        }
        return style;
    }

    private void setColumnWidth(HSSFSheet sheet, int col, int widthChars) {
        sheet.setColumnWidth(col, widthChars * 256);
    }

    private HSSFRow row(HSSFSheet sheet, int rowIndex) {
        HSSFRow r = sheet.getRow(rowIndex);
        if (r == null) {
            r = sheet.createRow(rowIndex);
        }
        return r;
    }

    private HSSFCell setText(HSSFRow row, int col, String value, HSSFCellStyle style) {
        HSSFCell cell = row.getCell(col);
        if (cell == null) {
            cell = row.createCell(col);
        }
        cell.setCellValue(value == null ? "" : value);
        if (style != null) {
            cell.setCellStyle(style);
        }
        return cell;
    }

    private HSSFCell setNumber(HSSFRow row, int col, double value, HSSFCellStyle style) {
        HSSFCell cell = row.getCell(col);
        if (cell == null) {
            cell = row.createCell(col);
        }
        cell.setCellValue(value);
        if (style != null) {
            cell.setCellStyle(style);
        }
        return cell;
    }

    private HSSFCell setFormula(HSSFRow row, int col, String formula, HSSFCellStyle style) {
        HSSFCell cell = row.getCell(col);
        if (cell == null) {
            cell = row.createCell(col);
        }
        cell.setCellFormula(formula);
        if (style != null) {
            cell.setCellStyle(style);
        }
        return cell;
    }

    private String avgRangeFormula(int rowIndex, int startCol, int endCol) {
        return "AVERAGE(" + colName(startCol) + (rowIndex + 1) + ":" + colName(endCol) + (rowIndex + 1) + ")";
    }

    private String colName(int colIndex) {
        return CellReference.convertNumToColString(colIndex);
    }

    private String toOperatorLabel(int index) {
        int n = index + 1;
        StringBuilder label = new StringBuilder();
        while (n > 0) {
            int mod = (n - 1) % 26;
            label.insert(0, (char) ('A' + mod));
            n = (n - 1) / 26;
        }
        return label.toString();
    }

    private double k1ForTrial(int trialCount) {
        if (K1_BY_TRIAL.containsKey(trialCount)) {
            return K1_BY_TRIAL.get(trialCount);
        }
        Double d2 = D2_CONSTANTS.get(trialCount);
        if (d2 == null || d2 <= 0) {
            return 0.5908;
        }
        return 1.0 / d2;
    }

    private double kForCount(int count) {
        if (K2K3_BY_COUNT.containsKey(count)) {
            return K2K3_BY_COUNT.get(count);
        }
        if (count <= 0) {
            return 0.0;
        }
        return 1.41 / Math.sqrt(count);
    }

    private double nearestConstant(Map<Integer, Double> constants, int key, double fallback) {
        if (constants.containsKey(key)) {
            return constants.get(key);
        }
        List<Integer> keys = new ArrayList<>(constants.keySet());
        if (keys.isEmpty()) {
            return fallback;
        }
        keys.sort(Integer::compareTo);
        int nearest = keys.get(0);
        for (int candidate : keys) {
            if (Math.abs(candidate - key) < Math.abs(nearest - key)) {
                nearest = candidate;
            }
        }
        return constants.getOrDefault(nearest, fallback);
    }

    private String repeatabilitySummary(Double pctTolerance) {
        if (pctTolerance == null || !Double.isFinite(pctTolerance)) {
            return "Tolerance was not provided; only repeatability sigma is reported.";
        }
        if (pctTolerance <= 10) {
            return "Repeatability is excellent: tolerance ratio <= 10%.";
        }
        if (pctTolerance <= 30) {
            return "Repeatability is acceptable: tolerance ratio within 10%~30%.";
        }
        return "Repeatability is high: tolerance ratio > 30%, please inspect fixture or method consistency.";
    }

    private String linearitySummary(Double pctTolerance, double slope) {
        if (pctTolerance != null && Double.isFinite(pctTolerance)) {
            if (pctTolerance <= 10 && Math.abs(slope) <= 0.1) {
                return "Linearity is excellent and slope is close to zero.";
            }
            if (pctTolerance <= 30) {
                return "缂佺偓瀵ч埀顑啫璁查柟鎭掑劚瑜板牓鏁嶉崼婵堢处閻犱緡鍠楃€垫梻绱掗鐘崇＇闁硅矇宥囩";
            }
            return "Linearity is high, please inspect reference standard and test method.";
        }
        if (Math.abs(slope) <= 0.05) {
            return "Linearity drift is very small.";
        }
        if (Math.abs(slope) <= 0.15) {
            return "Linearity drift is noticeable and should be reviewed.";
        }
        return "Linearity drift is large, please review calibration method and reference samples.";
    }

    private String pctText(Double value) {
        if (value == null || !Double.isFinite(value)) {
            return "-";
        }
        return String.format(Locale.ROOT, "%.2f%%", value);
    }

    private List<Double> arrayToList(double[] values) {
        List<Double> list = new ArrayList<>(values.length);
        for (double value : values) {
            list.add(value);
        }
        return list;
    }

    private record GrrDataset(int appraiserCount, int partCount, int trialCount, double[][][] data) {}

    private record GrrDataRefs(String rbarCell, String xDiffCell, String rpCell) {}

    private record ReportStyles(
            HSSFCellStyle title,
            HSSFCellStyle metaLabel,
            HSSFCellStyle metaValue,
            HSSFCellStyle metaValueNumber,
            HSSFCellStyle header,
            HSSFCellStyle headerNumber,
            HSSFCellStyle textCell,
            HSSFCellStyle centerTextCell,
            HSSFCellStyle blueNumber3,
            HSSFCellStyle number3,
            HSSFCellStyle number4,
            HSSFCellStyle meanGreen4,
            HSSFCellStyle meanYellow4,
            HSSFCellStyle section,
            HSSFCellStyle label,
            HSSFCellStyle percent2,
            HSSFCellStyle percent2Emphasis,
            HSSFCellStyle number2Emphasis,
            HSSFCellStyle conclusion,
            HSSFCellStyle tip
    ) {}

    private record RepeatabilityResult(
            int sampleCount,
            int partCount,
            int trialCount,
            double[][] data,
            double[] partMeans,
            double[] partRanges,
            double rbar,
            double sigmaRepeatability,
            double ev,
            Double pctTolerance,
            double xbarbar,
            double rUcl,
            double rLcl,
            double xUcl,
            double xLcl,
            String summary
    ) {}

    private record LinearityPoint(double reference, List<Double> measures, double meanMeasure, double bias) {}

    private record LinearityResult(
            int sampleCount,
            List<LinearityPoint> points,
            double slope,
            double intercept,
            double r2,
            double meanBias,
            double maxAbsBias,
            Double pctTolerance,
            String summary
    ) {}

    private record SimpleReportStyles(
            HSSFCellStyle title,
            HSSFCellStyle section,
            HSSFCellStyle header,
            HSSFCellStyle label,
            HSSFCellStyle text,
            HSSFCellStyle number0,
            HSSFCellStyle number2,
            HSSFCellStyle number4,
            HSSFCellStyle number6,
            HSSFCellStyle percent2
    ) {}

    private SimpleReportStyles createSimpleReportStyles(HSSFWorkbook workbook) {
        HSSFFont normal = workbook.createFont();
        normal.setFontName("Arial");
        normal.setFontHeightInPoints((short) 10);

        HSSFFont bold = workbook.createFont();
        bold.setFontName("Arial");
        bold.setBold(true);
        bold.setFontHeightInPoints((short) 10);

        HSSFFont title = workbook.createFont();
        title.setFontName("Arial");
        title.setBold(true);
        title.setFontHeightInPoints((short) 14);

        short fmt0 = workbook.createDataFormat().getFormat("0");
        short fmt2 = workbook.createDataFormat().getFormat("0.00");
        short fmt4 = workbook.createDataFormat().getFormat("0.0000");
        short fmt6 = workbook.createDataFormat().getFormat("0.000000");

        HSSFCellStyle titleStyle = style(workbook, title, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, false);
        HSSFCellStyle sectionStyle = style(workbook, bold, HorizontalAlignment.LEFT, VerticalAlignment.CENTER, IndexedColors.LIGHT_CORNFLOWER_BLUE.getIndex(), true);
        HSSFCellStyle headerStyle = style(workbook, bold, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, IndexedColors.GREY_25_PERCENT.getIndex(), true);
        HSSFCellStyle labelStyle = style(workbook, bold, HorizontalAlignment.LEFT, VerticalAlignment.CENTER, IndexedColors.LEMON_CHIFFON.getIndex(), true);
        HSSFCellStyle textStyle = style(workbook, normal, HorizontalAlignment.LEFT, VerticalAlignment.CENTER, null, true);
        HSSFCellStyle number0Style = style(workbook, normal, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, true);
        number0Style.setDataFormat(fmt0);
        HSSFCellStyle number2Style = style(workbook, normal, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, true);
        number2Style.setDataFormat(fmt2);
        HSSFCellStyle number4Style = style(workbook, normal, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, true);
        number4Style.setDataFormat(fmt4);
        HSSFCellStyle number6Style = style(workbook, normal, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, true);
        number6Style.setDataFormat(fmt6);
        HSSFCellStyle percent2Style = style(workbook, normal, HorizontalAlignment.CENTER, VerticalAlignment.CENTER, null, true);
        percent2Style.setDataFormat(fmt2);

        return new SimpleReportStyles(
                titleStyle, sectionStyle, headerStyle, labelStyle, textStyle,
                number0Style, number2Style, number4Style, number6Style, percent2Style
        );
    }

    private List<Double> resolveValues(List<List<Double>> gridValues, String rawValues) {
        List<Double> values = new ArrayList<>();
        if (gridValues != null) {
            for (List<Double> row : gridValues) {
                if (row == null) {
                    continue;
                }
                for (Double value : row) {
                    if (value == null || !Double.isFinite(value)) {
                        continue;
                    }
                    values.add(value);
                }
            }
        }
        if (!values.isEmpty()) {
            return values;
        }

        if (rawValues == null || rawValues.isBlank()) {
            return values;
        }
        Matcher matcher = NUMBER_PATTERN.matcher(rawValues);
        while (matcher.find()) {
            String token = matcher.group();
            try {
                double value = Double.parseDouble(token);
                if (Double.isFinite(value)) {
                    values.add(value);
                }
            } catch (NumberFormatException ignored) {
            }
        }
        return values;
    }

    private List<AnalysisHistogramBin> buildHistogram(List<Double> values, Integer requestedBins) {
        int bins = requestedBins == null ? 8 : requestedBins;
        bins = Math.max(5, Math.min(30, bins));

        double min = values.stream().min(Double::compareTo).orElse(0.0);
        double max = values.stream().max(Double::compareTo).orElse(0.0);
        if (Math.abs(max - min) < 1e-12) {
            max = min + 1.0;
        }

        double width = (max - min) / bins;
        long[] counts = new long[bins];
        for (double value : values) {
            int idx = (int) ((value - min) / width);
            if (idx < 0) {
                idx = 0;
            }
            if (idx >= bins) {
                idx = bins - 1;
            }
            counts[idx]++;
        }

        List<AnalysisHistogramBin> result = new ArrayList<>(bins);
        for (int i = 0; i < bins; i++) {
            double lower = min + i * width;
            double upper = (i == bins - 1) ? max : lower + width;
            double center = (lower + upper) / 2.0;
            result.add(new AnalysisHistogramBin(lower, upper, center, counts[i]));
        }
        return result;
    }

    private double requireFinite(Double value, String message) {
        if (value == null || !Double.isFinite(value)) {
            throw new IllegalArgumentException(message);
        }
        return value;
    }

    private int requirePositive(Integer value, String message) {
        if (value == null || value <= 0) {
            throw new IllegalArgumentException(message);
        }
        return value;
    }

        private double requireD2(int n, String context) {
        Double d2 = D2_CONSTANTS.get(n);
        if (d2 == null) {
            throw new IllegalArgumentException(context + " 閺嗗倷绗夐弨顖涘瘮 n=" + n + "閿涘矁顕担璺ㄦ暏 2~25");
        }
        return d2;
    }

    private double mean(List<Double> values) {
        if (values.isEmpty()) {
            return 0.0;
        }
        double sum = 0.0;
        for (double v : values) {
            sum += v;
        }
        return sum / values.size();
    }

    private double sampleStdDev(List<Double> values) {
        if (values.size() < 2) {
            return 0.0;
        }
        double avg = mean(values);
        double sum = 0.0;
        for (double v : values) {
            double diff = v - avg;
            sum += diff * diff;
        }
        return Math.sqrt(sum / (values.size() - 1));
    }

    private List<List<Double>> chunk(List<Double> values, int size) {
        List<List<Double>> result = new ArrayList<>();
        for (int i = 0; i < values.size(); i += size) {
            result.add(new ArrayList<>(values.subList(i, i + size)));
        }
        return result;
    }

    private double range(List<Double> values) {
        if (values.isEmpty()) {
            return 0.0;
        }
        double min = Collections.min(values);
        double max = Collections.max(values);
        return max - min;
    }

    private List<Double> movingRanges(List<Double> values) {
        List<Double> result = new ArrayList<>();
        if (values.size() < 2) {
            return result;
        }
        for (int i = 1; i < values.size(); i++) {
            result.add(Math.abs(values.get(i) - values.get(i - 1)));
        }
        return result;
    }

    private double ppm(long count, int total) {
        if (total <= 0) {
            return 0.0;
        }
        return count * 1_000_000.0 / total;
    }

    private double safeDivide(double numerator, int denominator) {
        if (denominator <= 0) {
            return 0.0;
        }
        return numerator / denominator;
    }

    private double percent(double numerator, double denominator) {
        if (!Double.isFinite(denominator) || Math.abs(denominator) < 1e-12) {
            return 0.0;
        }
        return numerator * 100.0 / denominator;
    }

        private String capabilitySummary(double cpk, double ppk) {
        if (cpk >= 1.67 && ppk >= 1.67) {
            return "閼宠棄濮忔导妯碱潊";
        }
        if (cpk >= 1.33 && ppk >= 1.33) {
            return "閼宠棄濮忛懝顖氥偨";
        }
        if (cpk >= 1.00 && ppk >= 1.00) {
            return "閼宠棄濮忔稉鈧懜?;
        }
        return "閼宠棄濮忛崑蹇庣秵";
    }
    private String capabilityAssessmentLevel(double cpk, double ppk) {
        if (cpk >= 1.67 && ppk >= 1.67) {
            return "娴兼顫?;
        }
        if (cpk >= 1.33 && ppk >= 1.33) {
            return "閼诡垰銈?;
        }
        if (cpk >= 1.00 && ppk >= 1.00) {
            return "閸欘垱甯撮崣?;
        }
        return "闂団偓閺佸瓨鏁?;
    }
    private String capabilityConclusion(String assessmentLevel, double cpk, double ppk, double cpl, double cpu) {
        return switch (assessmentLevel) {
            case "娴兼顫? -> "鏉╁洨鈻奸懗钘夊閸忓懓鍐婚敍宀€绮嶉崘鍛瑢閺佺繝缍嬬悰銊у箛闁€熺窛缁嬪啿鐣鹃敍灞藉讲娴ｆ粈璐熸导妯哄帥閸欏倽鈧啰绮ㄩ弸婧库偓?;
            case "閼诡垰銈? -> "鏉╁洨鈻奸懗钘夊鏉堟儳鍩岀敮姝岊潐閹貉冨煑鐟曚焦鐪伴敍灞界紦鐠侇喚鎴风紒顓濈箽閹镐椒鑵戣箛鍐ㄢ偓闂寸瑢濞夈垹濮╅幒褍鍩楅妴?;
            case "閸欘垱甯撮崣? -> "鏉╁洨鈻奸懗钘夊婢跺嫪绨稉瀵告櫕閸欘垱甯撮崣妤€灏梻杈剧礉瀵ら缚顔呮径宥嗙壋娑擃厼绺鹃崑蹇曅╅獮鑸靛瘮缂侇叀顫囩€电喆鈧?;
            default -> (cpl < cpu
                    ? "鏉╁洨鈻奸懗钘夊娑撳秷鍐婚敍灞煎瘜鐟曚線顥撻梽鈺呮肠娑擃厼婀棃鐘虹箮娑撳顫夐弽濂告娑撯偓娓氀佲偓?
                    : "鏉╁洨鈻奸懗钘夊娑撳秷鍐婚敍灞煎瘜鐟曚線顥撻梽鈺呮肠娑擃厼婀棃鐘虹箮娑撳﹨顫夐弽濂告娑撯偓娓氀佲偓?)
                    + " 瀵ら缚顔呴崗鍫滅喘閸栨牞绻冪粙瀣倵閸愬秴褰傜敮鍐╊劀瀵繒绮ㄧ拋鎭掆偓?;
        };
    }
    private String capabilityRecommendedAction(String assessmentLevel, List<AnalysisValidationItem> items) {
        boolean hasShift = items.stream().anyMatch(item -> "CAP_SHIFT".equals(item.getCode()) || "CAP_CENTER_OFF".equals(item.getCode()));
        return switch (assessmentLevel) {
            case "娴兼顫? -> "瀵ら缚顔呴幐澶婄秼閸撳秴寮弫鎵埛缂侇厾娲冮幒褝绱濋獮璺虹殺閺堫剚顐肩紒鎾寸亯娴ｆ粈璐熼崺铏瑰殠閻楀牊婀版穱婵嗙摠閵?;
            case "閼诡垰銈? -> hasShift
                    ? "瀵ら缚顔呮导妯哄帥濡偓閺屻儴绻冪粙瀣╄厬韫囧啫浜哥粔浼欑礉閸愬秵瀵旂紒顓＄闊亝澹掗梻瀛樺皾閸斻劊鈧?
                    : "瀵ら缚顔呮穱婵囧瘮瑜版挸澧犲銉ㄥ閸欏倹鏆熼敍灞借嫙閹稿顓搁崚鎺戞噯閺堢喎顦插ù瀣ㄢ偓?;
            case "閸欘垱甯撮崣? -> "瀵ら缚顔呯悰銉ュ帠閺嶉攱婀伴獮璺侯槻閺嶆瓕绻冪粙瀣╄厬韫囧喛绱濊箛鍛邦洣閺冨爼鍣搁弬鎷岊啎鐎规碍甯堕崚鍓佹櫕闂勬劑鈧?;
            default -> "瀵ら缚顔呴弳鍌氫粻閻╁瓨甯村鏇犳暏閺堫剛绮ㄩ弸婊冧粵濮濓絽绱￠弨鎹愵攽閿涘苯鍘涙禒搴ゎ啎婢跺洢鈧礁浼愰懝鍝勬嫲閸欐牗鐗遍弬瑙勭《娑撳鏌熼棃銏℃殻閺€骞库偓?;
        };
    }
        private String grrSummary(double pctStudyVarGrr, double ndc) {
        if (pctStudyVarGrr <= 10 && ndc >= 5) {
            return "GRR 娴兼顫呴敍灞藉讲閻╁瓨甯撮悽銊ょ艾鏉╁洨鈻奸幒褍鍩?;
        }
        if (pctStudyVarGrr <= 30) {
            return "GRR 閸欘垱甯撮崣妤嬬礉瀵ら缚顔呯紒鎾虫値娑撴艾濮熸搴ㄦ珦鐠囧嫪鍙婇崥搴濆▏閻?;
        }
        return "GRR 閸嬪繘鐝敍灞界紦鐠侇喕绱崗鍫滅喘閸栨牠鍣洪崗鏋偓浣规煙濞夋洘鍨ㄩ幙宥勭稊閸涙ü绔撮懛瀛樷偓?;
    }
    private String grrAssessmentLevel(double pctStudyVarGrr, double ndc) {
        if (pctStudyVarGrr <= 10 && ndc >= 5) {
            return "娴兼顫?;
        }
        if (pctStudyVarGrr <= 30 && ndc >= 3) {
            return "閸欘垱甯撮崣?;
        }
        return "闂団偓閺佸瓨鏁?;
    }
    private String grrConclusion(String assessmentLevel, double pctStudyVarGrr, double ndc) {
        return switch (assessmentLevel) {
            case "娴兼顫? -> "濞村鍣虹化鑽ょ埠闁插秴顦查幀褌绗岄崘宥囧箛閹嗐€冮悳鎷屽婵傛枻绱濋崣顖滄纯閹恒儲鏁幘鎴ｇ箖缁嬪甯堕崚韬测偓?;
            case "閸欘垱甯撮崣? -> "濞村鍣虹化鑽ょ埠閸╃儤婀伴崣顖滄暏閿涘奔绲炬禒宥呯紦鐠侇喚绮ㄩ崥鍫滅瑹閸旓繝顥撻梽鈺佹嫲閸忔娊鏁悧瑙勨偓褌濞囬悽銊ｂ偓?;
            default -> "濞村鍣虹化鑽ょ埠濞夈垹濮╅崑蹇涚彯閹存牕灏崚鍡氬厴閸旀稐绗夌搾绛圭礉瑜版挸澧犳稉宥呯紦鐠侇喚娲块幒銉ょ稊娑撶儤娓剁紒鍫濆灲鐎规矮绶烽幑顔衡偓?;
        } + " 瑜版挸澧?%Study Var=" + String.format(Locale.ROOT, "%.2f", pctStudyVarGrr)
                + "%閿涘DC=" + String.format(Locale.ROOT, "%.2f", ndc) + "閵?;
    }
    private String grrRecommendedAction(String assessmentLevel, List<AnalysisValidationItem> items) {
        boolean lowNdc = items.stream().anyMatch(item -> "GRR_NDC_LOW".equals(item.getCode()));
        return switch (assessmentLevel) {
            case "娴兼顫? -> "瀵ら缚顔呯紒瀛樺瘮瑜版挸澧犻柌蹇撳徔娑撳孩鎼锋担婊嗩潐閼煎喛绱濋獮鏈电稊娑撴椽鍣哄ù瀣兇缂佺喎鐔€缁惧じ绻氱€涙ǜ鈧?;
            case "閸欘垱甯撮崣? -> lowNdc
                    ? "瀵ら缚顔呮导妯哄帥婢х偛濮為梿鏈垫瀹割喖绱撻弽閿嬫拱閿涘苯鍟€婢跺秵鐗抽幙宥勭稊閸涙顔勭紒鍐х閼峰瓨鈧佲偓?
                    : "瀵ら缚顔呯紒鎾虫値娴溠冩惂妞嬪酣娅撶紒褏鐢绘担璺ㄦ暏閿涘苯鑻熺€瑰甯撻崥搴ｇ敾婢跺秵绁寸涵顔款吇閵?;
            default -> "瀵ら缚顔呮导妯哄帥閹烘帗鐓￠柌蹇撳徔閻樿埖鈧降鈧礁銇欏▽璇插徔閵嗕焦鎼锋担婊勬煙濞夋洖鎷伴幙宥勭稊閸涙顔勭紒鍐跨礉閸愬秹鍣搁弬鐗堝⒔鐞?GRR閵?;
        };
    }
    private List<AnalysisValidationItem> buildCapabilityValidationMessages(
            int sampleCount,
            int subgroupSize,
            int groupCount,
            double cpk,
            double ppk,
            double cpl,
            double cpu,
            double observedPpmTotal,
            double predictedPpmTotalOverall
    ) {
        List<AnalysisValidationItem> items = new ArrayList<>();
        if (sampleCount < 30) {
            items.add(validation("CAP_SAMPLE_LOW", "WARNING", "閺嶉攱婀伴柌蹇撶毌娴?30閿涘苯缂撶拋顔藉⒖閸忓懏鐗遍張顒€鎮楅崘宥呭絺鐢啯顒滃蹇曠波鐠佹亽鈧?));
        } else {
            items.add(validation("CAP_SAMPLE_OK", "INFO", "閺嶉攱婀伴柌蹇斿姬鐡掑啿鐖剁憴鍕厴閸旀稑鍨庨弸鎰畱閸╄櫣顢呯憰浣圭湴閵?));
        }
        if (subgroupSize > 1 && groupCount < 20) {
            items.add(validation("CAP_GROUP_LOW", "WARNING", "鐎涙劗绮嶉弫浼村櫤閸嬪繐鐨敍宀€绮嶉崘鍛皾閸斻劋鍙婄拋锛勄旂€规碍鈧傜閼割兙鈧?));
        }
        if (Math.abs(cpk - ppk) >= 0.20) {
            items.add(validation("CAP_SHIFT", "WARNING", "CPK 娑?PPK 瀹割喖绱撴潏鍐ㄣ亣閿涘矁绻冪粙瀣讲閼宠棄鐡ㄩ崷銊︾磽缁夌粯鍨ㄩ幍褰掓？濞夈垹濮╅妴?));
        }
        if (Math.abs(cpl - cpu) >= 0.20) {
            items.add(validation("CAP_CENTER_OFF", "WARNING", "鏉╁洨鈻奸崸鍥р偓鐓庝焊閸氭垼顫夐弽闂寸娓氀嶇礉瀵ら缚顔呭Λ鈧弻銉よ厬韫囧啫鈧壈顔曠€规哎鈧?));
        }
        if (cpk < 1.00 || ppk < 1.00) {
            items.add(validation("CAP_NOT_CAPABLE", "RISK", "瑜版挸澧犳潻鍥┾柤閼宠棄濮忔稉宥堝喕閿涘苯缂撶拋顔芥畯閸嬫粌鐨㈤張顒傜波閺嬫粈缍旀稉鐑橆劀瀵繑鏂佺悰灞肩贩閹诡喓鈧?));
        } else if (cpk >= 1.33 && ppk >= 1.33) {
            items.add(validation("CAP_GOOD", "INFO", "鏉╁洨鈻奸懗钘夊鏉堟儳鍩岀敮姝岊潐闁插繋楠囩憰浣圭湴閵?));
        }
        if (observedPpmTotal > 1000 || predictedPpmTotalOverall > 1000) {
            items.add(validation("CAP_PPM_HIGH", "WARNING", "娑撳秷澹?ppm 閸嬪繘鐝敍灞界紦鐠侇喚绮ㄩ崥鍫濈磽鐢摜鍋ｆ稉搴ゎ啎婢跺洨濮搁幀浣界箻娑撯偓濮濄儱顦查弽鎼炩偓?));
        }
        return items;
    }
    private List<AnalysisValidationItem> buildGrrValidationMessages(
            double pctStudyVarGrr,
            double ndc,
            Double tolerance,
            int appraiserCount,
            int partCount,
            int trialCount
    ) {
        List<AnalysisValidationItem> items = new ArrayList<>();
        if (pctStudyVarGrr > 30) {
            items.add(validation("GRR_HIGH", "RISK", "GRR 閸楃姵鐦搾鍛扮箖 30%閿涘本绁撮柌蹇曢兇缂佺喐娈忔稉宥呯紦鐠侇喚娲块幒銉ф暏娴滃孩顒滃蹇撳灲鐎规哎鈧?));
        } else if (pctStudyVarGrr > 10) {
            items.add(validation("GRR_MEDIUM", "WARNING", "GRR 婢跺嫪绨?10%~30%閿涘苯缂撶拋顔剧波閸氬牅绗熼崝锟狀棑闂勨晞鐦庢导鏉挎倵娴ｈ法鏁ら妴?));
        } else {
            items.add(validation("GRR_OK", "INFO", "GRR 閸楃姵鐦潏鍐х秵閿涘本绁撮柌蹇曢兇缂佺喕銆冮悳鎷屽婵傚鈧?));
        }
        if (ndc < 5) {
            items.add(validation("GRR_NDC_LOW", "WARNING", "NDC 鐏忓繋绨?5閿涘苯灏崚鍡曠瑝閸氬矂娴傛禒鍓佹畱閼宠棄濮忛崑蹇撴€ラ妴?));
        } else {
            items.add(validation("GRR_NDC_OK", "INFO", "NDC 濠娐ゅ喕閸栧搫鍨庨懗钘夊鐟曚焦鐪伴妴?));
        }
        if (tolerance == null || !Double.isFinite(tolerance) || tolerance <= 0) {
            items.add(validation("GRR_NO_TOL", "INFO", "閺堫亝褰佹笟娑樺彆瀹割噯绱濊ぐ鎾冲缂佹捁顔戦張顏勫瘶閸氼偄鍙曞顔煎窗濮ｆ柨鍨介弬顓溾偓?));
        }
        if (appraiserCount < 3) {
            items.add(validation("GRR_APPRAISER_LOW", "INFO", "閹垮秳缍旈崨妯绘殶闁插繗绶濈亸鎴礉瀵ら缚顔呴崥搴ｇ敾閹碘晛鍘栭幙宥勭稊閸涙ɑ鐗遍張顒€顦查弽鎼炩偓?));
        }
        if (partCount < 10 || trialCount < 3) {
            items.add(validation("GRR_DESIGN_LIGHT", "WARNING", "闂嗘湹娆㈤弫鐗堝灗闁插秴顦插▎鈩冩殶閸嬪繐鐨敍灞界紦鐠侇喛藟閸忓懎鎮楅崘宥呬粵閺堚偓缂佸牆缍婂锝冣偓?));
        }
        return items;
    }
    private AnalysisValidationItem validation(String code, String severity, String message) {
        return AnalysisValidationItem.builder()
                .code(code)
                .severity(severity)
                .message(message)
                .build();
    }
    private boolean isReadyForReport(List<AnalysisValidationItem> items) {
        return items.stream().noneMatch(item -> "RISK".equalsIgnoreCase(item.getSeverity()));
    }
    private double normalTailPpmLower(double threshold, double mean, double sigma) {
        if (sigma <= 0) {
            return 0.0;
        }
        double z = (threshold - mean) / sigma;
        return normalCdf(z) * 1_000_000.0;
    }

    private double normalTailPpmUpper(double threshold, double mean, double sigma) {
        if (sigma <= 0) {
            return 0.0;
        }
        double z = (threshold - mean) / sigma;
        return (1.0 - normalCdf(z)) * 1_000_000.0;
    }

    private double normalCdf(double z) {
        return 0.5 * (1.0 + erf(z / Math.sqrt(2.0)));
    }

    private double erf(double x) {
        double sign = x < 0 ? -1.0 : 1.0;
        double absX = Math.abs(x);
        double t = 1.0 / (1.0 + 0.3275911 * absX);
        double y = 1.0 - (((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t
                - 0.284496736) * t + 0.254829592) * t) * Math.exp(-absX * absX);
        return sign * y;
    }
}

