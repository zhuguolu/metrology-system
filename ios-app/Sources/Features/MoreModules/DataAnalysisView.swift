import Foundation
import SwiftUI

struct DataAnalysisView: View {
    @StateObject private var viewModel = DataAnalysisViewModel()

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    capabilityCard
                    capabilityResultCard
                    grrCard
                    grrResultCard
                    hintLine
                }
                .padding(.horizontal, 12)
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

    private var capabilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("过程能力指数")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)

            Text("输入样本与规格上下限，计算 Cp/Cpk/Pp/Ppk")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)

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
                placeholder: "样本数据（支持换行/逗号/空格）\n示例：10.02, 10.05, 9.98, 10.11",
                text: $viewModel.capabilityDataText,
                minHeight: 108
            )

            HStack(spacing: 10) {
                Button("计算能力指数") {
                    metrologyDismissKeyboard()
                    viewModel.calculateCapability()
                }
                .buttonStyle(MetrologyPrimaryButtonStyle())
                .frame(maxWidth: .infinity)

                Button("填充示例") {
                    metrologyDismissKeyboard()
                    viewModel.fillCapabilityExample()
                }
                .buttonStyle(MetrologySecondaryButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .metrologyCard()
    }

    @ViewBuilder
    private var capabilityResultCard: some View {
        if let result = viewModel.capabilityResult {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("能力结果")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                    Spacer(minLength: 0)
                    Text(result.summary)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(result.summaryColor)
                }

                AnalysisMetricGrid(items: [
                    AnalysisMetric(title: "样本数", value: "\(result.sampleCount)", tone: .neutral),
                    AnalysisMetric(title: "子组数", value: "\(result.groupCount)", tone: .neutral),
                    AnalysisMetric(title: "平均值", value: result.mean.formatted(4), tone: .normal),
                    AnalysisMetric(title: "组内σ", value: result.sigmaWithin.formatted(6), tone: .normal),
                    AnalysisMetric(title: "整体σ", value: result.sigmaOverall.formatted(6), tone: .normal),
                    AnalysisMetric(title: "Cp", value: result.cp.formatted(4), tone: result.capabilityTone),
                    AnalysisMetric(title: "Cpk", value: result.cpk.formatted(4), tone: result.capabilityTone),
                    AnalysisMetric(title: "Pp", value: result.pp.formatted(4), tone: result.performanceTone),
                    AnalysisMetric(title: "Ppk", value: result.ppk.formatted(4), tone: result.performanceTone)
                ])
            }
            .padding(10)
            .metrologyCard()
        }
    }

    private var grrCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("量具 GRR（交叉型）")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)

            Text("行格式：零件,检验员,重复,测量值")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)

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
                placeholder: "示例行：P1,O1,1,10.01",
                text: $viewModel.grrDataText,
                minHeight: 138
            )

            HStack(spacing: 10) {
                Button("计算 GRR") {
                    metrologyDismissKeyboard()
                    viewModel.calculateGRR()
                }
                .buttonStyle(MetrologyPrimaryButtonStyle())
                .frame(maxWidth: .infinity)

                Button("填充示例") {
                    metrologyDismissKeyboard()
                    viewModel.fillGRRExample()
                }
                .buttonStyle(MetrologySecondaryButtonStyle())
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .metrologyCard()
    }

    @ViewBuilder
    private var grrResultCard: some View {
        if let result = viewModel.grrResult {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("GRR 结果")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                    Spacer(minLength: 0)
                    Text(result.summary)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(result.summaryColor)
                }

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
            .padding(10)
            .metrologyCard()
        }
    }

    private var hintLine: some View {
        HStack(spacing: 8) {
            Text(viewModel.hint)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
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

private struct AnalysisMetric: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let tone: AnalysisMetricTone
}

private enum AnalysisMetricTone {
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

private struct CapabilityResult {
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
}

private struct GrrResult {
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

