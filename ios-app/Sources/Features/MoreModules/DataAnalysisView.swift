import Foundation
import SwiftUI

struct DataAnalysisView: View {
    @StateObject private var viewModel = DataAnalysisViewModel()

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    heroSection
                    reportSummarySection
                    exportPreparationSection
                    explanationHierarchySection
                    capabilityCard
                    capabilityResultCard
                    grrCard
                    grrResultCard
                    hintLine
                }
                .padding(.horizontal, MetrologyLayout.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            if let errorMessage = viewModel.errorMessage {
                MetrologyNoticeDialog(
                    title: "提示",
                    message: errorMessage
                ) {
                    viewModel.errorMessage = nil
                }
            }
        }
        .navigationTitle("数据分析")
    }

    private var heroSection: some View {
        MetrologyPageHeroCard(
            eyebrow: "Analysis",
            title: "数据分析",
            subtitle: "把过程能力与量具 GRR 收到同一页，适合快速计算、结果查看与专业判断。",
            accent: .neutral
        ) {
            VStack(alignment: .center, spacing: 8) {
                Text("当前模块")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(viewModel.capabilityResult == nil && viewModel.grrResult == nil ? "待计算" : "已产出")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundStyle(MetrologyPalette.navActive)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text("能力 / GRR")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, MetrologyLayout.pageHorizontalPadding)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(hex: 0xC5D8F7), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private var reportSummarySection: some View {
        if viewModel.capabilityResult != nil || viewModel.grrResult != nil {
            MetrologySectionPanel(
                title: "报告摘要",
                subtitle: "把当前已生成的分析结果汇总成一页，便于后续截图、复核与报告整理。"
            ) {
                VStack(spacing: 10) {
                    if let result = viewModel.capabilityResult {
                        AnalysisNarrativeCard(
                            title: "过程能力 · \(result.summary)",
                            message: "Cpk \(result.cpk.formatted(3)) / Ppk \(result.ppk.formatted(3))，\(result.riskLevelDescription)",
                            tone: result.riskTone
                        )
                    }

                    if let result = viewModel.grrResult {
                        AnalysisNarrativeCard(
                            title: "量具 GRR · \(result.summary)",
                            message: "%GRR \(result.percentGRR.formatted(2))%，ndc \(result.ndc.map(String.init) ?? "-")，\(result.riskLevelDescription)",
                            tone: result.riskTone
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var exportPreparationSection: some View {
        if viewModel.capabilityResult != nil || viewModel.grrResult != nil {
            MetrologySectionPanel(
                title: "导出前摘要",
                subtitle: "导出、截图或整理报告前，先确认本次结果、风险等级与建议动作。"
            ) {
                VStack(spacing: 10) {
                    if let result = viewModel.capabilityResult {
                        AnalysisExportSummaryCard(
                            title: "过程能力结果",
                            summary: "Cpk \(result.cpk.formatted(3)) / Ppk \(result.ppk.formatted(3)) · \(result.summary)",
                            badge: result.riskLevelTitle,
                            notes: result.exportNotes,
                            tone: result.riskTone
                        )
                    }

                    if let result = viewModel.grrResult {
                        AnalysisExportSummaryCard(
                            title: "量具 GRR 结果",
                            summary: "%GRR \(result.percentGRR.formatted(2))% / ndc \(result.ndc.map(String.init) ?? "-") · \(result.summary)",
                            badge: result.riskLevelTitle,
                            notes: result.exportNotes,
                            tone: result.riskTone
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var explanationHierarchySection: some View {
        if viewModel.capabilityResult != nil || viewModel.grrResult != nil {
            MetrologySectionPanel(
                title: "结果说明层级",
                subtitle: "建议按“核心结论 → 风险等级 → 建议动作”的顺序阅读和复核。"
            ) {
                VStack(spacing: 10) {
                    if let result = viewModel.capabilityResult {
                        AnalysisHierarchyCard(
                            title: "过程能力",
                            tone: result.heroTone,
                            stages: [
                                AnalysisHierarchyStage(step: "01", title: "核心结论", message: result.summary),
                                AnalysisHierarchyStage(step: "02", title: "风险等级", message: result.riskLevelDescription),
                                AnalysisHierarchyStage(step: "03", title: "建议动作", message: result.recommendedActions.first ?? "继续保持当前过程监控。")
                            ]
                        )
                    }

                    if let result = viewModel.grrResult {
                        AnalysisHierarchyCard(
                            title: "量具 GRR",
                            tone: result.heroTone,
                            stages: [
                                AnalysisHierarchyStage(step: "01", title: "核心结论", message: result.summary),
                                AnalysisHierarchyStage(step: "02", title: "风险等级", message: result.riskLevelDescription),
                                AnalysisHierarchyStage(step: "03", title: "建议动作", message: result.recommendedActions.first ?? "继续按周期复核量具系统。")
                            ]
                        )
                    }
                }
            }
        }
    }

    private var capabilityCard: some View {
        MetrologySectionPanel(title: "过程能力指数", subtitle: "输入样本与规格上下限，计算 Cp / Cpk / Pp / Ppk。") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("规格下限（LSL）", text: $viewModel.capabilityLSLText)
                        .keyboardType(.decimalPad)
                        .metrologyInput()

                    TextField("规格上限（USL）", text: $viewModel.capabilityUSLText)
                        .keyboardType(.decimalPad)
                        .metrologyInput()
                }

                TextField("子组大小（可选）", text: $viewModel.capabilitySubgroupText)
                    .keyboardType(.numberPad)
                    .metrologyInput()

                AnalysisTextEditor(
                    placeholder: "样本数据（支持换行、逗号、空格）\n示例：10.02, 10.05, 9.98, 10.11",
                    text: $viewModel.capabilityDataText,
                    minHeight: 108
                )

                HStack(spacing: 10) {
                    Button("示例") {
                        metrologyDismissKeyboard()
                        viewModel.fillCapabilityExample()
                    }
                    .buttonStyle(MetrologySecondaryButtonStyle())
                    .frame(maxWidth: .infinity)

                    Button("计算能力指数") {
                        metrologyDismissKeyboard()
                        viewModel.calculateCapability()
                    }
                    .buttonStyle(MetrologyPrimaryButtonStyle())
                    .frame(maxWidth: .infinity)

                    Button("清空") {
                        metrologyDismissKeyboard()
                        viewModel.clearCapabilityInputs()
                    }
                    .buttonStyle(MetrologySecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var capabilityResultCard: some View {
        if let result = viewModel.capabilityResult {
            VStack(spacing: 10) {
                AnalysisResultHeroCard(
                    eyebrow: "CPK / PPK",
                    title: result.summary,
                    subtitle: result.capabilityAdvice,
                    tone: result.heroTone,
                    highlights: [
                        AnalysisHighlight(title: "Cpk", value: result.cpk.formatted(3)),
                        AnalysisHighlight(title: "Ppk", value: result.ppk.formatted(3)),
                        AnalysisHighlight(title: "样本", value: "\(result.sampleCount)")
                    ]
                )

                MetrologySectionPanel(title: "能力结果", subtitle: "核心指标已按能力等级着色，便于快速判断。") {
                    AnalysisMetricGrid(items: [
                        AnalysisMetric(title: "样本数", value: "\(result.sampleCount)", tone: .neutral),
                        AnalysisMetric(title: "子组数", value: "\(result.groupCount)", tone: .neutral),
                        AnalysisMetric(title: "平均值", value: result.mean.formatted(4), tone: .normal),
                        AnalysisMetric(title: "组内标准差", value: result.sigmaWithin.formatted(6), tone: .normal),
                        AnalysisMetric(title: "整体标准差", value: result.sigmaOverall.formatted(6), tone: .normal),
                        AnalysisMetric(title: "Cp", value: result.cp.formatted(4), tone: result.capabilityTone),
                        AnalysisMetric(title: "Cpk", value: result.cpk.formatted(4), tone: result.capabilityTone),
                        AnalysisMetric(title: "Pp", value: result.pp.formatted(4), tone: result.performanceTone),
                        AnalysisMetric(title: "Ppk", value: result.ppk.formatted(4), tone: result.performanceTone)
                    ])
                }

                MetrologySectionPanel(title: "专业判断", subtitle: "结合 Cpk / Ppk 给出当前过程能力建议。") {
                    AnalysisNarrativeCard(
                        title: result.summary,
                        message: result.capabilityAdvice,
                        tone: result.heroTone
                    )
                }

                MetrologySectionPanel(title: "风险等级", subtitle: "按当前能力指数给出风险分级，便于现场快速判断。") {
                    AnalysisNarrativeCard(
                        title: result.riskLevelTitle,
                        message: result.riskLevelDescription,
                        tone: result.riskTone
                    )
                }

                MetrologySectionPanel(title: "建议动作", subtitle: "根据当前结果给出优先处理动作。") {
                    AnalysisActionChecklist(actions: result.recommendedActions, tone: result.heroTone)
                }

                MetrologySectionPanel(title: "说明卡", subtitle: "帮助理解 Cpk / Ppk 与当前样本结构。") {
                    AnalysisExplanationCard(lines: result.explanationNotes, tone: .neutral)
                }
            }
        }
    }

    private var grrCard: some View {
        MetrologySectionPanel(title: "量具 GRR（交叉型）", subtitle: "每行格式：零件、检验员、重复次数、测量值。") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    TextField("零件数", text: $viewModel.grrPartsText)
                        .keyboardType(.numberPad)
                        .metrologyInput()

                    TextField("检验员数", text: $viewModel.grrOperatorsText)
                        .keyboardType(.numberPad)
                        .metrologyInput()

                    TextField("重复次数", text: $viewModel.grrRepeatsText)
                        .keyboardType(.numberPad)
                        .metrologyInput()
                }

                AnalysisTextEditor(
                    placeholder: "示例行：P1, O1, 1, 10.01",
                    text: $viewModel.grrDataText,
                    minHeight: 138
                )

                HStack(spacing: 10) {
                    Button("示例") {
                        metrologyDismissKeyboard()
                        viewModel.fillGRRExample()
                    }
                    .buttonStyle(MetrologySecondaryButtonStyle())
                    .frame(maxWidth: .infinity)

                    Button("计算 GRR") {
                        metrologyDismissKeyboard()
                        viewModel.calculateGRR()
                    }
                    .buttonStyle(MetrologyPrimaryButtonStyle())
                    .frame(maxWidth: .infinity)

                    Button("清空") {
                        metrologyDismissKeyboard()
                        viewModel.clearGRRInputs()
                    }
                    .buttonStyle(MetrologySecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var grrResultCard: some View {
        if let result = viewModel.grrResult {
            VStack(spacing: 10) {
                AnalysisResultHeroCard(
                    eyebrow: "GRR",
                    title: result.summary,
                    subtitle: result.analysisAdvice,
                    tone: result.heroTone,
                    highlights: [
                        AnalysisHighlight(title: "%GRR", value: result.percentGRR.formatted(2) + "%"),
                        AnalysisHighlight(title: "ndc", value: result.ndc.map(String.init) ?? "-"),
                        AnalysisHighlight(title: "零件", value: "\(result.partCount)")
                    ]
                )

                MetrologySectionPanel(title: "GRR 结果", subtitle: "量具重复性、再现性和总变差统一展示。") {
                    AnalysisMetricGrid(items: [
                        AnalysisMetric(title: "零件数", value: "\(result.partCount)", tone: .neutral),
                        AnalysisMetric(title: "检验员数", value: "\(result.operatorCount)", tone: .neutral),
                        AnalysisMetric(title: "重复次数", value: "\(result.repeatCount)", tone: .neutral),
                        AnalysisMetric(title: "EV", value: result.ev.formatted(6), tone: .normal),
                        AnalysisMetric(title: "AV", value: result.av.formatted(6), tone: .normal),
                        AnalysisMetric(title: "PV", value: result.pv.formatted(6), tone: .normal),
                        AnalysisMetric(title: "GRR", value: result.grr.formatted(6), tone: result.grrTone),
                        AnalysisMetric(title: "TV", value: result.tv.formatted(6), tone: .normal),
                        AnalysisMetric(title: "%GRR", value: result.percentGRR.formatted(2) + "%", tone: result.grrTone),
                        AnalysisMetric(title: "ndc", value: result.ndc.map(String.init) ?? "-", tone: .neutral)
                    ])
                }

                MetrologySectionPanel(title: "专业判断", subtitle: "按量具系统优劣给出当前 GRR 结论与建议。") {
                    AnalysisNarrativeCard(
                        title: result.summary,
                        message: result.analysisAdvice,
                        tone: result.heroTone
                    )
                }

                MetrologySectionPanel(title: "风险等级", subtitle: "综合 %GRR 与 ndc 判断当前量具系统风险。") {
                    AnalysisNarrativeCard(
                        title: result.riskLevelTitle,
                        message: result.riskLevelDescription,
                        tone: result.riskTone
                    )
                }

                MetrologySectionPanel(title: "建议动作", subtitle: "根据 GRR 结果列出优先处置动作。") {
                    AnalysisActionChecklist(actions: result.recommendedActions, tone: result.heroTone)
                }

                MetrologySectionPanel(title: "说明卡", subtitle: "帮助理解 EV / AV / PV / ndc 的业务含义。") {
                    AnalysisExplanationCard(lines: result.explanationNotes, tone: .neutral)
                }
            }
        }
    }

    private var hintLine: some View {
        MetrologyStatusBanner(message: viewModel.hint, tone: .neutral)
    }
}

private struct AnalysisTextEditor: View {
    let placeholder: String
    @Binding var text: String
    var minHeight: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }

            TextEditor(text: $text)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(MetrologyPalette.textPrimary)
                .scrollContentBackground(.hidden)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .frame(minHeight: minHeight)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(hex: 0xD6E2F2), lineWidth: 1)
        )
    }
}

private struct AnalysisMetricGrid: View {
    let items: [AnalysisMetric]
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(items) { item in
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                        .lineLimit(1)
                    Text(item.value)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(item.tone.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(item.tone.background)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(item.tone.stroke, lineWidth: 1)
                )
            }
        }
    }
}

private struct AnalysisHighlight: Identifiable {
    let id = UUID()
    let title: String
    let value: String
}

private struct AnalysisResultHeroCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let tone: MetrologyPillTone
    let highlights: [AnalysisHighlight]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetrologyPageHeroCard(
                eyebrow: eyebrow,
                title: title,
                subtitle: subtitle,
                accent: tone
            ) {
                VStack(alignment: .trailing, spacing: 8) {
                    ForEach(highlights) { item in
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(MetrologyPalette.textSecondary)
                            Text(item.value)
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(tone.tint)
                        }
                    }
                }
            }
        }
    }
}

private struct AnalysisNarrativeCard: View {
    let title: String
    let message: String
    let tone: MetrologyPillTone

    var bodyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(tone.tint)
                    .frame(width: 8, height: 8)
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tone.tint)
            }

            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tone.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tone.stroke, lineWidth: 1)
        )
    }

    var body: some View { bodyView }
}

private struct AnalysisActionChecklist: View {
    let actions: [String]
    let tone: MetrologyPillTone

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(tone.tint)
                        .frame(width: 7, height: 7)
                        .padding(.top, 5)

                    Text(action)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if index < actions.count - 1 {
                    Divider().overlay(tone.stroke)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tone.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tone.stroke, lineWidth: 1)
        )
    }
}

private struct AnalysisExportSummaryCard: View {
    let title: String
    let summary: String
    let badge: String
    let notes: [String]
    let tone: MetrologyPillTone

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MetrologyPalette.textPrimary)

                    Text(summary)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(badge)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tone.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(tone.strongBackground)
                    )
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(tone.tint)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)

                        Text(note)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(MetrologyPalette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(tone.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(tone.stroke, lineWidth: 1)
        )
    }
}

private struct AnalysisHierarchyStage: Identifiable {
    let id = UUID()
    let step: String
    let title: String
    let message: String
}

private struct AnalysisHierarchyCard: View {
    let title: String
    let tone: MetrologyPillTone
    let stages: [AnalysisHierarchyStage]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)

            VStack(spacing: 8) {
                ForEach(stages) { stage in
                    HStack(alignment: .top, spacing: 10) {
                        Text(stage.step)
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundStyle(tone.tint)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 6)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(tone.strongBackground)
                            )

                        VStack(alignment: .leading, spacing: 3) {
                            Text(stage.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(MetrologyPalette.textPrimary)

                            Text(stage.message)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(MetrologyPalette.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }

                    if stage.id != stages.last?.id {
                        Divider()
                            .overlay(MetrologyPalette.stroke)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MetrologyPalette.stroke, lineWidth: 1)
        )
    }
}

private struct AnalysisExplanationCard: View {
    let lines: [String]
    let tone: MetrologyPillTone

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(tone.tint)
                        .padding(.top, 1)
                    Text(line)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(tone.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tone.stroke, lineWidth: 1)
        )
    }
}

private struct AnalysisMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tone: AnalysisMetricTone
}

enum AnalysisMetricTone {
    case normal
    case neutral
    case good
    case warning
    case danger

    var color: Color {
        switch self {
        case .normal: return MetrologyPalette.textPrimary
        case .neutral: return MetrologyPalette.textSecondary
        case .good: return MetrologyPalette.statusValid
        case .warning: return MetrologyPalette.statusWarning
        case .danger: return MetrologyPalette.statusExpired
        }
    }

    var background: Color {
        switch self {
        case .normal: return Color(hex: 0xF8FBFF)
        case .neutral: return Color(hex: 0xF5F9FF)
        case .good: return Color(hex: 0xECFDF5)
        case .warning: return Color(hex: 0xFFFBEB)
        case .danger: return Color(hex: 0xFEF2F2)
        }
    }

    var stroke: Color {
        switch self {
        case .normal: return Color(hex: 0xD9E5F5)
        case .neutral: return Color(hex: 0xDCE6F5)
        case .good: return Color(hex: 0xA7F3D0)
        case .warning: return Color(hex: 0xFCD34D)
        case .danger: return Color(hex: 0xFCA5A5)
        }
    }
}

@MainActor
final class DataAnalysisViewModel: ObservableObject {
    @Published var capabilityLSLText: String = ""
    @Published var capabilityUSLText: String = ""
    @Published var capabilitySubgroupText: String = ""
    @Published var capabilityDataText: String = ""

    @Published var grrPartsText: String = ""
    @Published var grrOperatorsText: String = ""
    @Published var grrRepeatsText: String = ""
    @Published var grrDataText: String = ""

    @Published var capabilityResult: CapabilityResult?
    @Published var grrResult: GrrResult?
    @Published var hint: String = "本地计算，不依赖后端。"
    @Published var errorMessage: String?

    func fillCapabilityExample() {
        capabilityLSLText = "9.80"
        capabilityUSLText = "10.20"
        capabilitySubgroupText = "4"
        capabilityDataText = """
        10.02, 10.05, 9.98, 10.11
        9.99, 10.00, 10.03, 10.06
        10.08, 10.01, 9.97, 10.04
        10.02, 10.00, 9.96, 10.05
        """
        hint = "已填充能力分析示例数据。"
    }

    func clearCapabilityInputs() {
        capabilityLSLText = ""
        capabilityUSLText = ""
        capabilitySubgroupText = ""
        capabilityDataText = ""
        capabilityResult = nil
        errorMessage = nil
        hint = "已清空能力分析输入数据。"
    }

    func calculateCapability() {
        do {
            let lsl = try AnalysisNumericParser.parseDouble(capabilityLSLText, field: "LSL")
            let usl = try AnalysisNumericParser.parseDouble(capabilityUSLText, field: "USL")
            let subgroup = try AnalysisNumericParser.parseOptionalInt(capabilitySubgroupText, field: "子组大小")
            let values = try AnalysisNumericParser.parseDoubles(capabilityDataText, field: "样本数据")
            let result = try CapabilityCalculator.calculate(
                values: values,
                lsl: lsl,
                usl: usl,
                subgroupSize: subgroup
            )
            capabilityResult = result
            hint = "能力分析完成：\(result.sampleCount) 个样本。"
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func fillGRRExample() {
        grrPartsText = "4"
        grrOperatorsText = "3"
        grrRepeatsText = "2"
        grrDataText = """
        P1,O1,1,10.02
        P1,O1,2,10.03
        P1,O2,1,10.05
        P1,O2,2,10.06
        P1,O3,1,10.04
        P1,O3,2,10.04
        P2,O1,1,9.98
        P2,O1,2,9.99
        P2,O2,1,10.00
        P2,O2,2,10.01
        P2,O3,1,9.99
        P2,O3,2,10.00
        P3,O1,1,10.10
        P3,O1,2,10.11
        P3,O2,1,10.13
        P3,O2,2,10.14
        P3,O3,1,10.12
        P3,O3,2,10.13
        P4,O1,1,9.92
        P4,O1,2,9.93
        P4,O2,1,9.95
        P4,O2,2,9.96
        P4,O3,1,9.94
        P4,O3,2,9.95
        """
        hint = "已填充 GRR 示例数据。"
    }

    func clearGRRInputs() {
        grrPartsText = ""
        grrOperatorsText = ""
        grrRepeatsText = ""
        grrDataText = ""
        grrResult = nil
        errorMessage = nil
        hint = "已清空 GRR 输入数据。"
    }

    func calculateGRR() {
        do {
            let expectedParts = try AnalysisNumericParser.parseOptionalInt(grrPartsText, field: "零件数")
            let expectedOperators = try AnalysisNumericParser.parseOptionalInt(grrOperatorsText, field: "检验员数")
            let expectedRepeats = try AnalysisNumericParser.parseOptionalInt(grrRepeatsText, field: "重复次数")
            let rows = try AnalysisNumericParser.parseGRRRows(grrDataText)

            let result = try GrrCalculator.calculate(
                rows: rows,
                expectedPartCount: expectedParts,
                expectedOperatorCount: expectedOperators,
                expectedRepeatCount: expectedRepeats
            )
            grrResult = result
            hint = "GRR 分析完成：%GRR \(result.percentGRR.formatted(2))%。"
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}

struct CapabilityResult {
    let sampleCount: Int
    let groupCount: Int
    let mean: Double
    let sigmaWithin: Double
    let sigmaOverall: Double
    let cp: Double
    let cpk: Double
    let pp: Double
    let ppk: Double

    var summary: String {
        if cpk >= 1.67 && ppk >= 1.67 { return "能力优秀" }
        if cpk >= 1.33 && ppk >= 1.33 { return "能力良好" }
        if cpk >= 1.00 && ppk >= 1.00 { return "能力一般" }
        return "能力偏低"
    }

    var summaryColor: Color {
        if cpk >= 1.67 && ppk >= 1.67 { return MetrologyPalette.statusValid }
        if cpk >= 1.33 && ppk >= 1.33 { return Color(hex: 0x0E9F6E) }
        if cpk >= 1.00 && ppk >= 1.00 { return MetrologyPalette.statusWarning }
        return MetrologyPalette.statusExpired
    }

    var capabilityTone: AnalysisMetricTone {
        if cpk >= 1.33 { return .good }
        if cpk >= 1.00 { return .warning }
        return .danger
    }

    var performanceTone: AnalysisMetricTone {
        if ppk >= 1.33 { return .good }
        if ppk >= 1.00 { return .warning }
        return .danger
    }

    var heroTone: MetrologyPillTone {
        if cpk >= 1.33 && ppk >= 1.33 { return .valid }
        if cpk >= 1.00 && ppk >= 1.00 { return .warning }
        return .expired
    }

    var capabilityAdvice: String {
        if cpk >= 1.67 && ppk >= 1.67 {
            return "当前过程能力充足，短期与长期表现都稳定，适合直接纳入正式结果查看与报告输出。"
        }
        if cpk >= 1.33 && ppk >= 1.33 {
            return "当前过程能力良好，建议继续保持过程控制，并定期复核波动来源。"
        }
        if cpk >= 1.00 && ppk >= 1.00 {
            return "当前过程能力处于临界可用区，建议重点关注均值偏移与整体波动。"
        }
        return "当前过程能力偏低，建议先排查设备、工艺或测量系统波动，再重新取样复测。"
    }

    var riskTone: MetrologyPillTone {
        if cpk >= 1.67 && ppk >= 1.67 { return .valid }
        if cpk >= 1.33 && ppk >= 1.33 { return .neutral }
        if cpk >= 1.00 && ppk >= 1.00 { return .warning }
        return .expired
    }

    var riskLevelTitle: String {
        if cpk >= 1.67 && ppk >= 1.67 { return "低风险" }
        if cpk >= 1.33 && ppk >= 1.33 { return "可控风险" }
        if cpk >= 1.00 && ppk >= 1.00 { return "中风险" }
        return "高风险"
    }

    var riskLevelDescription: String {
        if cpk >= 1.67 && ppk >= 1.67 { return "当前短期与长期能力都较充足，过程输出稳定，风险较低。" }
        if cpk >= 1.33 && ppk >= 1.33 { return "过程整体处于可控范围，建议保持监控并定期复核。" }
        if cpk >= 1.00 && ppk >= 1.00 { return "过程已接近能力下限，需要重点关注均值偏移与波动扩大。" }
        return "过程能力不足，继续放行会带来较高质量风险，建议优先整改。"
    }

    var recommendedActions: [String] {
        if cpk >= 1.67 && ppk >= 1.67 {
            return [
                "维持当前控制计划，按既定频率复核过程能力。",
                "保留本次样本与参数，作为后续能力趋势对比基线。"
            ]
        }
        if cpk >= 1.33 && ppk >= 1.33 {
            return [
                "继续监控关键工艺参数，避免均值漂移。",
                "定期复核特殊原因波动，保持长期能力稳定。"
            ]
        }
        if cpk >= 1.00 && ppk >= 1.00 {
            return [
                "优先排查均值偏移来源，必要时重新中心化工艺。",
                "增加抽样或缩短复测周期，防止能力继续下滑。"
            ]
        }
        return [
            "暂停直接用于正式判断，先排查设备、工艺或测量系统问题。",
            "整改后重新取样，并对比前后能力变化再决定是否放行。"
        ]
    }

    var explanationNotes: [String] {
        [
            "Cpk 反映过程中心与规格边界的短期能力，越高说明当前过程越稳。",
            "Ppk 反映长期整体能力，若明显低于 Cpk，通常意味着长期波动偏大。",
            groupCount > 1 ? "本次结果包含子组结构信息，可同时观察短期与长期波动。" : "本次结果基于连续单值样本，适合快速判断当前能力水平。"
        ]
    }

    var exportNotes: [String] {
        [
            "建议在导出中保留 Cpk / Ppk、样本数与风险等级，便于后续复核。",
            "当前判断：\(summary)，\(riskLevelDescription)",
            recommendedActions.first ?? "继续保持当前过程监控。"
        ]
    }
}

struct GrrResult {
    let partCount: Int
    let operatorCount: Int
    let repeatCount: Int
    let ev: Double
    let av: Double
    let pv: Double
    let grr: Double
    let tv: Double
    let percentGRR: Double
    let ndc: Int?

    var summary: String {
        if percentGRR <= 10 { return "量具系统优秀" }
        if percentGRR <= 30 { return "量具系统可接受" }
        return "量具系统需改进"
    }

    var summaryColor: Color {
        if percentGRR <= 10 { return MetrologyPalette.statusValid }
        if percentGRR <= 30 { return MetrologyPalette.statusWarning }
        return MetrologyPalette.statusExpired
    }

    var grrTone: AnalysisMetricTone {
        if percentGRR <= 10 { return .good }
        if percentGRR <= 30 { return .warning }
        return .danger
    }

    var heroTone: MetrologyPillTone {
        if percentGRR <= 10 { return .valid }
        if percentGRR <= 30 { return .warning }
        return .expired
    }

    var analysisAdvice: String {
        if percentGRR <= 10 {
            return "量具系统优秀，重复性与再现性对总变差影响较小，适合直接用于过程判断。"
        }
        if percentGRR <= 30 {
            return "量具系统可接受，建议结合 ndc 和实际业务风险判断是否继续优化。"
        }
        return "量具系统需改进，建议优先排查检验员差异、量具重复性和量具分辨率。"
    }

    var riskTone: MetrologyPillTone {
        if percentGRR <= 10 { return .valid }
        if percentGRR <= 30 { return .warning }
        return .expired
    }

    var riskLevelTitle: String {
        if percentGRR <= 10 { return "低风险" }
        if percentGRR <= 30 { return "中风险" }
        return "高风险"
    }

    var riskLevelDescription: String {
        if percentGRR <= 10 { return "量具系统对总变差影响较小，可直接支撑日常过程判断。" }
        if percentGRR <= 30 { return "量具系统处于可接受区，建议结合 ndc 和现场风险再决定是否继续使用。" }
        return "量具系统对总变差影响偏大，继续使用会放大判断误差，建议优先整改。"
    }

    var recommendedActions: [String] {
        if percentGRR <= 10 {
            return [
                "保持当前量具与作业方法，按周期复核 GRR。",
                "把本次结果作为量具系统稳定基线，后续持续跟踪。"
            ]
        }
        if percentGRR <= 30 {
            return [
                "结合 ndc 与业务风险评估是否需要进一步优化量具系统。",
                "优先检查检验员差异和重复测量一致性。"
            ]
        }
        return [
            "优先排查检验员差异、量具分辨率和量具自身重复性。",
            "整改后重新做交叉型 GRR，确认 %GRR 和 ndc 是否回到可接受区。"
        ]
    }

    var explanationNotes: [String] {
        [
            "EV 反映设备重复性，AV 反映检验员之间的再现性差异。",
            "%GRR 越低越好，通常 10% 以内较优，30% 以上需要重点关注。",
            "ndc 用于衡量量具区分不同零件差异的能力，越高越适合过程分析。"
        ]
    }

    var exportNotes: [String] {
        [
            "建议在导出中保留 %GRR、ndc 与风险等级，方便后续审核量具系统状态。",
            "当前判断：\(summary)，\(riskLevelDescription)",
            recommendedActions.first ?? "继续按周期复核量具系统。"
        ]
    }
}

private enum CapabilityCalculator {
    static func calculate(
        values: [Double],
        lsl: Double,
        usl: Double,
        subgroupSize: Int?
    ) throws -> CapabilityResult {
        guard values.count >= 2 else {
            throw AnalysisError("样本数量至少需要 2 个")
        }
        guard usl > lsl else {
            throw AnalysisError("USL 必须大于 LSL")
        }

        let mean = values.mean
        let overallSigma = values.sampleStdDev
        guard overallSigma > 0 else {
            throw AnalysisError("样本波动为 0，无法计算能力指数")
        }

        let withinSigma: Double
        let groupCount: Int

        if let subgroupSize, subgroupSize > 1 {
            guard values.count % subgroupSize == 0 else {
                throw AnalysisError("样本数量必须能被子组大小整除")
            }
            let d2 = try D2Constants.value(for: subgroupSize, context: "子组大小")
            let groups = values.chunked(into: subgroupSize)
            guard groups.count >= 2 else {
                throw AnalysisError("至少需要 2 个子组")
            }
            let averageRange = groups.map(\.range).mean
            withinSigma = averageRange / d2
            groupCount = groups.count
        } else {
            let movingRanges = values.adjacentMovingRanges
            guard !movingRanges.isEmpty else {
                throw AnalysisError("样本数量不足，无法计算移动极差")
            }
            let d2 = try D2Constants.value(for: 2, context: "移动极差")
            withinSigma = movingRanges.mean / d2
            groupCount = Swift.max(values.count - 1, 1)
        }

        guard withinSigma > 0 else {
            throw AnalysisError("组内波动为 0，无法计算 Cpk")
        }

        let specWidth = usl - lsl
        let cp = specWidth / (6 * withinSigma)
        let cpk = min((usl - mean) / (3 * withinSigma), (mean - lsl) / (3 * withinSigma))
        let pp = specWidth / (6 * overallSigma)
        let ppk = min((usl - mean) / (3 * overallSigma), (mean - lsl) / (3 * overallSigma))

        return CapabilityResult(
            sampleCount: values.count,
            groupCount: groupCount,
            mean: mean,
            sigmaWithin: withinSigma,
            sigmaOverall: overallSigma,
            cp: cp,
            cpk: cpk,
            pp: pp,
            ppk: ppk
        )
    }
}

private enum GrrCalculator {
    static func calculate(
        rows: [GRRInputRow],
        expectedPartCount: Int?,
        expectedOperatorCount: Int?,
        expectedRepeatCount: Int?
    ) throws -> GrrResult {
        guard !rows.isEmpty else {
            throw AnalysisError("GRR 数据不能为空")
        }

        let parts = Array(Set(rows.map(\.part))).sorted()
        let operators = Array(Set(rows.map(\.inspector))).sorted()

        guard parts.count >= 2 else {
            throw AnalysisError("GRR 至少需要 2 个零件")
        }
        guard operators.count >= 2 else {
            throw AnalysisError("GRR 至少需要 2 个检验员")
        }

        if let expectedPartCount, expectedPartCount != parts.count {
            throw AnalysisError("零件数不匹配：输入为 \(expectedPartCount)，数据识别为 \(parts.count)")
        }
        if let expectedOperatorCount, expectedOperatorCount != operators.count {
            throw AnalysisError("检验员数不匹配：输入为 \(expectedOperatorCount)，数据识别为 \(operators.count)")
        }

        var grouped: [String: [GRRInputRow]] = [:]
        for row in rows {
            grouped[row.groupKey, default: []].append(row)
        }

        for part in parts {
            for inspectorName in operators {
                let key = GRRInputRow.groupKey(part: part, inspector: inspectorName)
                if grouped[key] == nil {
                    throw AnalysisError("缺少组合数据：\(part) / \(inspectorName)")
                }
            }
        }

        let repeatCounts = Set(grouped.values.map(\.count))
        guard repeatCounts.count == 1, let repeats = repeatCounts.first else {
            throw AnalysisError("每个零件-检验员组合的重复次数必须一致")
        }
        guard repeats >= 2 else {
            throw AnalysisError("每个组合的重复次数至少为 2")
        }
        if let expectedRepeatCount, expectedRepeatCount != repeats {
            throw AnalysisError("重复次数不匹配：输入为 \(expectedRepeatCount)，数据识别为 \(repeats)")
        }

        let d2Repeat = try D2Constants.value(for: repeats, context: "重复次数")
        let d2Operator = try D2Constants.value(for: operators.count, context: "检验员数")
        let d2Part = try D2Constants.value(for: parts.count, context: "零件数")

        let orderedValuesByCell: [[Double]] = grouped.values.map { rows in
            rows.sorted { $0.trial < $1.trial }.map(\.value)
        }
        let rBar = orderedValuesByCell.map(\.range).mean
        let ev = rBar / d2Repeat

        let operatorMeans: [Double] = operators.map { name in
            rows.filter { $0.inspector == name }.map(\.value).mean
        }
        let xDiffOperator = operatorMeans.range
        let operatorCount = Double(operators.count)
        let partCount = Double(parts.count)
        let repeatCount = Double(repeats)

        let avRaw = pow(xDiffOperator / d2Operator, 2) - pow(ev, 2) / (partCount * repeatCount)
        let av = sqrt(Swift.max(avRaw, 0))

        let partMeans: [Double] = parts.map { name in
            rows.filter { $0.part == name }.map(\.value).mean
        }
        let xDiffPart = partMeans.range
        let pv = xDiffPart / d2Part

        let grr = sqrt(pow(ev, 2) + pow(av, 2))
        let tv = sqrt(pow(grr, 2) + pow(pv, 2))
        guard tv > 0 else {
            throw AnalysisError("总变差为 0，无法计算 %GRR")
        }

        let percentGRR = grr / tv * 100
        let ndcValue = grr > 0 ? Int(floor(1.41 * pv / grr)) : nil

        return GrrResult(
            partCount: parts.count,
            operatorCount: operators.count,
            repeatCount: repeats,
            ev: ev,
            av: av,
            pv: pv,
            grr: grr,
            tv: tv,
            percentGRR: percentGRR,
            ndc: ndcValue
        )
    }
}

private struct GRRInputRow {
    let part: String
    let inspector: String
    let trial: Int
    let value: Double

    var groupKey: String {
        Self.groupKey(part: part, inspector: inspector)
    }

    static func groupKey(part: String, inspector: String) -> String {
        "\(part)||\(inspector)"
    }
}

private enum AnalysisNumericParser {
    static func parseDouble(_ text: String, field: String) throws -> Double {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw AnalysisError("\(field) 不能为空")
        }
        guard let value = Double(trimmed) else {
            throw AnalysisError("\(field) 不是有效数字")
        }
        return value
    }

    static func parseOptionalInt(_ text: String, field: String) throws -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed), value > 0 else {
            throw AnalysisError("\(field) 必须是正整数")
        }
        return value
    }

    static func parseDoubles(_ text: String, field: String) throws -> [Double] {
        let pattern = "[-+]?(?:\\d*\\.\\d+|\\d+)(?:[eE][-+]?\\d+)?"
        let regex = try NSRegularExpression(pattern: pattern)
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        let values = matches.compactMap { match -> Double? in
            let fragment = nsText.substring(with: match.range)
            return Double(fragment)
        }
        guard !values.isEmpty else {
            throw AnalysisError("\(field) 未识别到有效数字")
        }
        return values
    }

    static func parseGRRRows(_ text: String) throws -> [GRRInputRow] {
        let rawLines = text.split(whereSeparator: \.isNewline).map { String($0) }
        var result: [GRRInputRow] = []

        for (index, lineRaw) in rawLines.enumerated() {
            let line = lineRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }

            let normalized = line
                .replacingOccurrences(of: "\u{FF0C}", with: ",")
                .replacingOccurrences(of: "\t", with: ",")
            let commaParts = normalized
                .split(separator: ",", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let parts: [String]
            if commaParts.count >= 4 {
                parts = commaParts
            } else {
                parts = normalized
                    .split(whereSeparator: \.isWhitespace)
                    .map(String.init)
            }

            guard parts.count >= 4 else {
                throw AnalysisError("第 \(index + 1) 行格式错误，需为：零件,检验员,重复,测量值")
            }

            let part = parts[0]
            let operatorName = parts[1]
            guard !part.isEmpty, !operatorName.isEmpty else {
                throw AnalysisError("第 \(index + 1) 行零件或检验员不能为空")
            }

            guard let trial = Int(parts[2]), trial > 0 else {
                throw AnalysisError("第 \(index + 1) 行重复序号必须是正整数")
            }

            guard let value = Double(parts[3]) else {
                throw AnalysisError("第 \(index + 1) 行测量值不是有效数字")
            }

            result.append(
                GRRInputRow(
                    part: part,
                    inspector: operatorName,
                    trial: trial,
                    value: value
                )
            )
        }

        if result.isEmpty {
            throw AnalysisError("GRR 数据未识别到有效行")
        }
        return result
    }
}

private struct D2Constants {
    private static let table: [Int: Double] = [
        2: 1.128, 3: 1.693, 4: 2.059, 5: 2.326,
        6: 2.534, 7: 2.704, 8: 2.847, 9: 2.970,
        10: 3.078, 11: 3.173, 12: 3.258, 13: 3.336,
        14: 3.407, 15: 3.472, 16: 3.532, 17: 3.588,
        18: 3.640, 19: 3.689, 20: 3.735, 21: 3.778,
        22: 3.819, 23: 3.858, 24: 3.895, 25: 3.931
    ]

    static func value(for n: Int, context: String) throws -> Double {
        guard let value = table[n] else {
            throw AnalysisError("\(context) 暂不支持 n=\(n)，请使用 2-25。")
        }
        return value
    }
}

private struct AnalysisError: LocalizedError {
    let message: String
    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

private extension Array where Element == Double {
    var mean: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }

    var range: Double {
        guard let minValue = min(), let maxValue = max() else { return 0 }
        return maxValue - minValue
    }

    var sampleStdDev: Double {
        guard count >= 2 else { return 0 }
        let avg = mean
        let variance = reduce(0) { $0 + pow($1 - avg, 2) } / Double(count - 1)
        return sqrt(Swift.max(variance, 0))
    }

    var adjacentMovingRanges: [Double] {
        guard count >= 2 else { return [] }
        var result: [Double] = []
        result.reserveCapacity(count - 1)
        for index in 1..<count {
            result.append(abs(self[index] - self[index - 1]))
        }
        return result
    }

    func chunked(into size: Int) -> [[Double]] {
        guard size > 0 else { return [] }
        var result: [[Double]] = []
        result.reserveCapacity(count / size)
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index..<end]))
            index = end
        }
        return result
    }
}

private extension Double {
    func formatted(_ digits: Int) -> String {
        if !isFinite {
            return "-"
        }
        return String(format: "%.\(digits)f", self)
    }
}

private extension Color {
    init(hex: Int, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}

