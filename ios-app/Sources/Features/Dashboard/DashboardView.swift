import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var distributionDetail: DistributionDetail?

    private let metricColumns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    heroSection
                    headerRow

                    LazyVGrid(columns: metricColumns, spacing: 10) {
                        DashboardMetricCard(
                            title: "设备总数",
                            value: viewModel.total,
                            accent: MetrologyPalette.navActive,
                            icon: "books.vertical.fill",
                            background: Color(hex: 0xEEF4FF)
                        )
                        DashboardMetricCard(
                            title: "本月到期",
                            value: viewModel.dueThisMonth,
                            accent: MetrologyPalette.statusWarning,
                            icon: "calendar",
                            background: Color(hex: 0xFFF7E8)
                        )
                        DashboardMetricCard(
                            title: "有效设备",
                            value: viewModel.valid,
                            accent: MetrologyPalette.statusValid,
                            icon: "checkmark.seal.fill",
                            background: Color(hex: 0xECFDF5)
                        )
                        DashboardMetricCard(
                            title: "失效/预警",
                            value: viewModel.risk,
                            accent: MetrologyPalette.statusExpired,
                            icon: "exclamationmark.triangle.fill",
                            background: Color(hex: 0xFEF2F2)
                        )
                    }

                    trendSection
                    distributionSection
                    departmentSection
                }
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 14)
            }
        }
        .navigationTitle("总览看板")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
        .overlay {
            ZStack {
                if viewModel.isLoading {
                    MetrologyLoadingCard(title: "加载中...")
                }

                if let distributionDetail {
                    DashboardDistributionDetailDialog(
                        detail: distributionDetail,
                        ratioText: ratioText(distributionDetail.value, distributionDetail.total),
                        formattedValue: formatCount(distributionDetail.value),
                        formattedTotal: formatCount(distributionDetail.total)
                    ) {
                        self.distributionDetail = nil
                    }
                }
            }
        }
    }

    private var heroSection: some View {
        MetrologyPageHeroCard(
            eyebrow: "Dashboard",
            title: "总览看板",
            subtitle: "把设备规模、校准趋势、有效性分布和部门统计收拢到同一页，适合日常巡检与汇总查看。",
            accent: .neutral
        ) {
            VStack(alignment: .trailing, spacing: 8) {
                Text("有效占比")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)

                Text(ratioText(viewModel.valid, max(viewModel.total, 0)))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(MetrologyPalette.statusValid)

                Text("总设备 \(formatCount(viewModel.total)) 台")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(hex: 0xA7F3D0), lineWidth: 1)
            )
        }
    }

    private var headerRow: some View {
        HStack(spacing: 10) {
            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                MetrologyStatusBanner(message: errorMessage, tone: .expired, compact: true)
            } else {
                MetrologyStatusBanner(message: viewModel.hintText, tone: .neutral, compact: true)
            }

            Button("刷新") {
                Task { await viewModel.load() }
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(MetrologyPalette.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .buttonStyle(MetrologySecondaryButtonStyle())
        }
    }

    private var trendSection: some View {
        MetrologySectionPanel(title: "校准趋势", subtitle: "近 6 个月的月度变化。") {
            HStack {
                Spacer(minLength: 8)
                Text("近 6 个月")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.navActive)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill(Color(hex: 0xE9F1FF)))
            }

            if viewModel.trend.isEmpty {
                MetrologyEmptyStateView(
                    icon: "chart.bar",
                    title: "暂无趋势数据",
                    message: "当前没有可展示的趋势结果，请稍后再试。"
                )
            } else {
                DashboardTrendChartView(points: viewModel.trend)
                    .frame(height: 260)
            }
        }
    }

    private var distributionSection: some View {
        MetrologySectionPanel(title: "设备有效性分布", subtitle: "点击圆环或右侧标签可查看占比。") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 24) {
                    distributionChart
                    distributionLegend
                }
                VStack(spacing: 10) {
                    distributionChart
                    distributionLegend
                }
            }
        }
    }

    private var distributionChart: some View {
        DashboardDonutChart(
            valid: viewModel.valid,
            warning: viewModel.warning,
            expired: viewModel.expired
        ) { segment in
            switch segment {
            case .valid:
                showDistributionDetail(title: "\u{6709}\u{6548}", value: viewModel.valid)
            case .warning:
                showDistributionDetail(title: "\u{5373}\u{5C06}\u{8FC7}\u{671F}", value: viewModel.warning)
            case .expired:
                showDistributionDetail(title: "\u{5931}\u{6548}", value: viewModel.expired)
            }
        }
        .frame(
            minWidth: 184,
            idealWidth: 210,
            maxWidth: 240,
            minHeight: 184,
            idealHeight: 210,
            maxHeight: 240
        )
    }

    private var distributionLegend: some View {
        VStack(alignment: .leading, spacing: 10) {
            legendRow(
                color: MetrologyPalette.statusValid,
                title: "\u{6709}\u{6548}"
            ) {
                showDistributionDetail(title: "\u{6709}\u{6548}", value: viewModel.valid)
            }
            legendRow(
                color: MetrologyPalette.statusWarning,
                title: "\u{5373}\u{5C06}\u{8FC7}\u{671F}"
            ) {
                showDistributionDetail(title: "\u{5373}\u{5C06}\u{8FC7}\u{671F}", value: viewModel.warning)
            }
            legendRow(
                color: MetrologyPalette.statusExpired,
                title: "\u{5931}\u{6548}"
            ) {
                showDistributionDetail(title: "\u{5931}\u{6548}", value: viewModel.expired)
            }
        }
        .padding(.leading, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var departmentSection: some View {
        MetrologySectionPanel(title: "\u{90E8}\u{95E8}\u{8BBE}\u{5907}\u{7EDF}\u{8BA1}", subtitle: "\u{6309}\u{90E8}\u{95E8}\u{67E5}\u{770B}\u{6709}\u{6548}\u{3001}\u{9884}\u{8B66}\u{4E0E}\u{5931}\u{6548}\u{5206}\u{5E03}\u{3002}") {
            HStack {
                Spacer(minLength: 8)
                Text("\u{6309}\u{90E8}\u{95E8}")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.navActive)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill(Color(hex: 0xE9F1FF)))
            }

            if viewModel.deptStats.isEmpty {
                MetrologyEmptyStateView(
                    icon: "building.2",
                    title: "暂无部门统计数据",
                    message: "当前还没有可展示的部门分布结果，请稍后再试。"
                )
            } else {
                ForEach(viewModel.deptStats) { item in
                    DashboardDeptStatCard(item: item)
                }
            }
        }
    }

    private func legendRow(
        color: Color,
        title: String,
        onTap: (() -> Void)? = nil
    ) -> some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
    }

    private func ratioText(_ value: Int64, _ total: Int64) -> String {
        guard total > 0 else { return "0%" }
        return String(format: "%.1f%%", (Double(value) * 100.0) / Double(total))
    }

    private func showDistributionDetail(title: String, value: Int64) {
        distributionDetail = DistributionDetail(
            title: title,
            value: value,
            total: max(viewModel.total, 0)
        )
    }

    private func formatCount(_ number: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

private struct DistributionDetail: Identifiable {
    let id = UUID()
    let title: String
    let value: Int64
    let total: Int64
}

private struct DashboardDistributionDetailDialog: View {
    let detail: DistributionDetail
    let ratioText: String
    let formattedValue: String
    let formattedTotal: String
    let onClose: () -> Void

    private var tone: MetrologyPillTone {
        switch detail.title {
        case "有效":
            return .valid
        case "即将过期":
            return .warning
        case "失效":
            return .expired
        default:
            return .neutral
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.24).ignoresSafeArea()

            VStack(alignment: .leading, spacing: 12) {
                Text("DISTRIBUTION")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(tone.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(tone.strongBackground)
                    )

                Text("设备有效性分布 · \(detail.title)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)

                VStack(spacing: 10) {
                    MetrologyStatusBanner(message: "数量：\(formattedValue) 台", tone: tone)
                    MetrologyStatusBanner(message: "占比：\(ratioText)", tone: .neutral)
                    MetrologyStatusBanner(message: "总数：\(formattedTotal) 台", tone: .neutral)
                }

                Button("关闭", action: onClose)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .buttonStyle(MetrologyPrimaryButtonStyle())
            }
            .padding(14)
            .frame(maxWidth: 360)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(hex: 0xF6FAFF)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(hex: 0xD5E2F2), lineWidth: 1)
            )
            .shadow(color: Color(hex: 0x456B96, alpha: 0.22), radius: 14, x: 0, y: 6)
            .padding(.horizontal, 20)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
        .zIndex(1000)
        .preferredColorScheme(.light)
    }
}

private struct DashboardMetricCard: View {
    let title: String
    let value: Int64
    let accent: Color
    let icon: String
    let background: Color

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.95))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                Text(formatCount(value))
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: 0xD5E2F2), lineWidth: 1)
        )
    }

    private func formatCount(_ number: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}

private struct DashboardTrendChartView: View {
    let points: [DashboardTrendPoint]
    @State private var revealProgress: Double = 0

    private var axisMax: Int64 {
        let rawMax = max(points.map(\.value).max() ?? 0, 10)
        return niceMax(rawMax)
    }

    var body: some View {
        GeometryReader { proxy in
            let left: CGFloat = 34
            let top: CGFloat = 16
            let right: CGFloat = 10
            let bottom: CGFloat = 34
            let chartWidth = max(proxy.size.width - left - right, 1)
            let chartHeight = max(proxy.size.height - top - bottom, 1)
            let rows = 5
            let slotWidth = chartWidth / CGFloat(max(points.count, 1))
            let barWidth = slotWidth * 0.68

            ZStack {
                ForEach(0...rows, id: \.self) { row in
                    let ratio = CGFloat(row) / CGFloat(rows)
                    let y = top + chartHeight * (1 - ratio)
                    Path { path in
                        path.move(to: CGPoint(x: left, y: y))
                        path.addLine(to: CGPoint(x: left + chartWidth, y: y))
                    }
                    .stroke(Color(hex: 0xDDE6F3), lineWidth: 1)

                    Text("\(Int((Double(axisMax) * Double(ratio)).rounded()))")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(MetrologyPalette.textMuted)
                        .position(x: left - 16, y: y)
                }

                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    let centerX = left + CGFloat(index) * slotWidth + slotWidth / 2
                    let heightRatio = Double(point.value) / Double(max(axisMax, 1))
                    let barHeight = CGFloat(heightRatio * revealProgress) * chartHeight
                    let safeBarHeight = max(barHeight, point.value > 0 ? 1 : 0)
                    let barTop = top + chartHeight - safeBarHeight

                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: 0x4E8BFF), MetrologyPalette.navActive],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: barWidth, height: safeBarHeight)
                        .position(x: centerX, y: barTop + safeBarHeight / 2)

                    let animatedValue = Int64((Double(point.value) * revealProgress).rounded())
                    Text("\(animatedValue)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MetrologyPalette.navActive)
                        .position(x: centerX, y: max(barTop - 10, 10))

                    Text(point.label)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(MetrologyPalette.textSecondary)
                        .position(x: centerX, y: top + chartHeight + 20)
                }
            }
        }
        .onAppear {
            animateReveal()
        }
        .onChange(of: points.map(\.value)) { _ in
            animateReveal()
        }
    }

    private func animateReveal() {
        revealProgress = 0
        withAnimation(.easeOut(duration: 0.7)) {
            revealProgress = 1
        }
    }

    private func niceMax(_ value: Int64) -> Int64 {
        guard value > 0 else { return 10 }
        var base: Int64 = 1
        while base <= value / 10 {
            base *= 10
        }
        let normalized = Double(value) / Double(base)
        let factor: Int64
        if normalized <= 1 {
            factor = 1
        } else if normalized <= 2 {
            factor = 2
        } else if normalized <= 5 {
            factor = 5
        } else {
            factor = 10
        }
        return factor * base
    }
}

private enum DashboardDonutSegment {
    case valid
    case warning
    case expired
}

private struct DashboardDonutChart: View {
    let valid: Int64
    let warning: Int64
    let expired: Int64
    let onSegmentTap: (DashboardDonutSegment) -> Void

    @State private var revealProgress: Double = 0

    private var total: Int64 { max(valid + warning + expired, 0) }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let ringWidth = max(size * 0.16, 20)
            let gap = 2.8 / 360.0

            ZStack {
                Circle()
                    .stroke(Color(hex: 0xEAF2FF), lineWidth: ringWidth)

                if total > 0 {
                    let segments = [
                        (value: valid, color: MetrologyPalette.statusValid, segment: DashboardDonutSegment.valid),
                        (value: warning, color: MetrologyPalette.statusWarning, segment: DashboardDonutSegment.warning),
                        (value: expired, color: MetrologyPalette.statusExpired, segment: DashboardDonutSegment.expired)
                    ]

                    ForEach(Array(segments.enumerated()), id: \.offset) { index, segment in
                        let range = trimRange(
                            for: index,
                            segments: segments,
                            gap: gap,
                            progress: revealProgress
                        )
                        if range.to > range.from {
                            Circle()
                                .trim(from: range.from, to: range.to)
                                .stroke(segment.color, style: StrokeStyle(lineWidth: ringWidth, lineCap: .butt))
                                .rotationEffect(.degrees(-90))
                        }
                    }
                }

                VStack(spacing: 4) {
                    let animatedTotal = Int64((Double(total) * revealProgress).rounded())
                    Text("\(animatedTotal)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                    Text("\u{8BBE}\u{5907}\u{603B}\u{6570}")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(MetrologyPalette.textMuted)
                }
            }
            .frame(width: size, height: size)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .contentShape(Rectangle())
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        guard let segment = resolveSegment(at: value.location, in: proxy.size) else { return }
                        onSegmentTap(segment)
                    }
            )
        }
        .onAppear {
            animateReveal()
        }
        .onChange(of: total) { _ in
            animateReveal()
        }
    }

    private func animateReveal() {
        revealProgress = 0
        withAnimation(.easeOut(duration: 0.76)) {
            revealProgress = 1
        }
    }

    private func trimRange(
        for index: Int,
        segments: [(value: Int64, color: Color, segment: DashboardDonutSegment)],
        gap: Double,
        progress: Double
    ) -> (from: Double, to: Double) {
        let safeTotal = Double(max(total, 1))
        var start: Double = 0
        for i in 0..<index {
            start += Double(segments[i].value) / safeTotal
        }
        let fullSweep = Double(segments[index].value) / safeTotal
        let animatedSweep = fullSweep * progress
        let from = start + (gap / 2)
        let to = max(from, start + animatedSweep - (gap / 2))
        return (from, to)
    }

    private func resolveSegment(at location: CGPoint, in size: CGSize) -> DashboardDonutSegment? {
        let total = valid + warning + expired
        guard total > 0 else { return nil }

        let diameter = min(size.width, size.height)
        let radius = diameter * 0.35
        let ringWidth = max(diameter * 0.16, 20)
        let tolerance = max(diameter * 0.06, 12)

        let cx = size.width / 2
        let cy = size.height / 2
        let dx = location.x - cx
        let dy = location.y - cy
        let distance = hypot(dx, dy)

        let outer = radius + (ringWidth / 2) + tolerance
        let inner = max(radius - (ringWidth / 2) - tolerance, 0)
        guard distance <= outer && distance >= inner else { return nil }

        let angleFromTop = normalizeAngle((atan2(dy, dx) * 180 / .pi) + 90)
        let gapDegrees = 2.8
        let safeTotal = Double(total)

        var start = -90.0
        let validSweep = Double(valid) / safeTotal * 360
        if matchesSegment(
            angleFromTop: angleFromTop,
            startFromRight: start,
            fullSweep: validSweep,
            gap: gapDegrees,
            progress: revealProgress
        ) {
            return .valid
        }
        start += validSweep

        let warningSweep = Double(warning) / safeTotal * 360
        if matchesSegment(
            angleFromTop: angleFromTop,
            startFromRight: start,
            fullSweep: warningSweep,
            gap: gapDegrees,
            progress: revealProgress
        ) {
            return .warning
        }
        start += warningSweep

        let expiredSweep = Double(expired) / safeTotal * 360
        if matchesSegment(
            angleFromTop: angleFromTop,
            startFromRight: start,
            fullSweep: expiredSweep,
            gap: gapDegrees,
            progress: revealProgress
        ) {
            return .expired
        }

        return nil
    }

    private func matchesSegment(
        angleFromTop: Double,
        startFromRight: Double,
        fullSweep: Double,
        gap: Double,
        progress: Double
    ) -> Bool {
        guard fullSweep > 0 else { return false }
        let animatedSweep = fullSweep * progress
        let visibleSweep = max(animatedSweep - gap, 0)
        guard visibleSweep > 0 else { return false }
        let segmentStart = normalizeAngle(startFromRight + (gap / 2) + 90)
        return isAngleInSweep(angle: angleFromTop, start: segmentStart, sweep: visibleSweep)
    }

    private func isAngleInSweep(angle: Double, start: Double, sweep: Double) -> Bool {
        let normalizedAngle = normalizeAngle(angle)
        let normalizedStart = normalizeAngle(start)
        let end = normalizeAngle(normalizedStart + sweep)
        if normalizedStart <= end {
            return normalizedAngle >= normalizedStart && normalizedAngle <= end
        }
        return normalizedAngle >= normalizedStart || normalizedAngle <= end
    }

    private func normalizeAngle(_ angle: Double) -> Double {
        var normalized = angle.truncatingRemainder(dividingBy: 360)
        if normalized < 0 {
            normalized += 360
        }
        return normalized
    }
}

private struct DashboardDeptStatCard: View {
    let item: DashboardDeptStat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\u{603B}\u{6570} \(formatCount(item.total))")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.navActive)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule(style: .continuous).fill(Color(hex: 0xE9F1FF)))
            }

            HStack(spacing: 8) {
                chip(title: "\u{6709}\u{6548}", value: item.valid, tint: MetrologyPalette.statusValid, bg: Color(hex: 0xECFDF5))
                chip(title: "\u{9884}\u{8B66}", value: item.warning, tint: MetrologyPalette.statusWarning, bg: Color(hex: 0xFFFBEB))
                chip(title: "\u{5931}\u{6548}", value: item.expired, tint: MetrologyPalette.statusExpired, bg: Color(hex: 0xFEF2F2))
            }

            HStack(spacing: 10) {
                ProgressView(value: Double(item.validRate), total: 100)
                    .tint(MetrologyPalette.statusValid)
                Text("\u{6709}\u{6548}\u{5360}\u{6BD4} \(item.validRate)%")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: 0xD5E2F2), lineWidth: 1)
        )
    }

    private func chip(title: String, value: Int64, tint: Color, bg: Color) -> some View {
        Text("\(title) \(formatCount(value))")
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule(style: .continuous).fill(bg))
    }

    private func formatCount(_ number: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
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
