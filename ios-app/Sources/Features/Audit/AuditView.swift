import Foundation
import SwiftUI

struct AuditView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AuditViewModel()

    @State private var detailSheetItem: AuditDetailSheetItem?
    @State private var rejectSheetItem: AuditRejectSheetItem?
    @State private var historyFilterDebounceTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    heroSection

                    if viewModel.isAdmin {
                        modePills
                    }

                    if viewModel.mode == .history {
                        historyFilterPanel
                    }

                    if let message = viewModel.errorMessage {
                        noticePill(message: message, tone: .expired)
                    }

                    if viewModel.mode == .history, !viewModel.historyHint.isEmpty {
                        noticePill(message: viewModel.historyHint, tone: .neutral)
                    }

                    if viewModel.mode == .history,
                       let fallbackHint = viewModel.historyFallbackHint,
                       !fallbackHint.isEmpty {
                        noticePill(message: fallbackHint, tone: .warning)
                    }

                    auditListPanel
                }
                .padding(.horizontal, MetrologyLayout.pageHorizontalPadding)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .task {
            viewModel.configure(role: appState.session?.role, username: appState.session?.username)
            await viewModel.loadCurrent()
        }
        .onChange(of: sessionIdentity) {
            viewModel.configure(role: appState.session?.role, username: appState.session?.username)
            Task { await viewModel.loadCurrent() }
        }
        .onChange(of: viewModel.mode) {
            historyFilterDebounceTask?.cancel()
            Task { await viewModel.loadCurrent() }
        }
        .onChange(of: viewModel.historyKeyword) { _, _ in
            scheduleHistoryKeywordFilter()
        }
        .sheet(item: $detailSheetItem) { item in
            AuditDetailView(record: item.record)
        }
        .sheet(item: $rejectSheetItem) { item in
            AuditRejectReasonSheet(
                record: item.record,
                onSubmit: { reason in
                    Task {
                        await viewModel.reject(item.record, reason: reason)
                        rejectSheetItem = nil
                    }
                },
                onCancel: {
                    rejectSheetItem = nil
                }
            )
        }
    }

    private var heroSection: some View {
        MetrologyPageHeroCard(
            eyebrow: "Audit",
            title: "数据审核",
            subtitle: "集中处理待审批、我的申请与历史记录，审批详情保持只显示真实变更项。",
            accent: modeTone
        ) {
            VStack(alignment: .trailing, spacing: 8) {
                Text("当前")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)

                Text("\(viewModel.items.count)")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(modeTone.tint)

                Text(viewModel.mode.title)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)
            }
                    .padding(.horizontal, MetrologyLayout.pageHorizontalPadding)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(modeTone.stroke.opacity(0.8), lineWidth: 1)
            )
        }
    }

    private var modePills: some View {
        HStack(spacing: 8) {
            modePill(.pending, tone: .warning, compact: false)
            modePill(.my, tone: .neutral, compact: false)
            modePill(.history, tone: .muted, compact: false)
        }
    }

    private func modePill(_ mode: AuditListMode, tone: MetrologyPillTone, compact: Bool) -> some View {
        MetrologyInteractivePill(
            title: mode.title,
            value: modeSubtitle(for: mode),
            tone: tone,
            isSelected: viewModel.mode == mode,
            compact: compact
        ) {
            guard viewModel.mode != mode else { return }
            viewModel.mode = mode
        }
    }

    private func modeSubtitle(for mode: AuditListMode) -> String {
        switch mode {
        case .pending:
            return "待处理"
        case .my:
            return "我的申请"
        case .history:
            return "可检索"
        }
    }

    private func noticePill(message: String, tone: MetrologyPillTone) -> some View {
        MetrologyStatusBanner(message: message, tone: tone)
    }

    private var sessionIdentity: String {
        let username = appState.session?.username ?? ""
        let role = appState.session?.role ?? ""
        return "\(username)|\(role)"
    }

    private var auditRows: [AuditListRow] {
        var duplicated: [String: Int] = [:]
        return viewModel.items.map { item in
            let base = baseAuditRowID(item)
            let count = duplicated[base, default: 0]
            duplicated[base] = count + 1
            let id = count == 0 ? base : "\(base)#\(count)"
            return AuditListRow(id: id, item: item)
        }
    }

    private func baseAuditRowID(_ item: AuditRecordDto) -> String {
        if let id = item.id {
            return "id:\(id)"
        }
        let entityId = item.entityId.map(String.init) ?? ""
        return "tmp:\(item.type ?? "")|\(item.entityType ?? "")|\(entityId)|\(item.submittedAt ?? "")|\(item.submittedBy ?? "")"
    }

    private var historyFilterPanel: some View {
        MetrologySectionPanel(
            title: "历史筛选",
            subtitle: "支持按状态、类型和关键词快速检索历史审批记录。"
        ) {
            VStack(spacing: 8) {
                TextField(
                    "关键词：设备名称/计量编号/提交人",
                    text: $viewModel.historyKeyword
                )
                .metrologyInput()

                HStack(spacing: 8) {
                    Menu {
                        Button("全部状态") { applyHistoryStatusFilter("") }
                        Button("待审批") { applyHistoryStatusFilter("PENDING") }
                        Button("已通过") { applyHistoryStatusFilter("APPROVED") }
                        Button("已驳回") { applyHistoryStatusFilter("REJECTED") }
                    } label: {
                        MetrologySelectField(
                            title: "状态",
                            value: historyStatusLabel(viewModel.historyStatusFilter),
                            compact: true
                        )
                    }

                    Menu {
                        Button("全部类型") { applyHistoryTypeFilter("") }
                        Button("新增") { applyHistoryTypeFilter("CREATE") }
                        Button("修改") { applyHistoryTypeFilter("UPDATE") }
                        Button("删除") { applyHistoryTypeFilter("DELETE") }
                    } label: {
                        MetrologySelectField(
                            title: "类型",
                            value: historyTypeLabel(viewModel.historyTypeFilter),
                            compact: true
                        )
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func applyHistoryStatusFilter(_ value: String) {
        let resolved = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard viewModel.historyStatusFilter != resolved else { return }
        viewModel.historyStatusFilter = resolved
        Task { await viewModel.applyHistoryFilters() }
    }

    private func applyHistoryTypeFilter(_ value: String) {
        let resolved = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard viewModel.historyTypeFilter != resolved else { return }
        viewModel.historyTypeFilter = resolved
        Task { await viewModel.applyHistoryFilters() }
    }

    private func scheduleHistoryKeywordFilter() {
        historyFilterDebounceTask?.cancel()
        guard viewModel.mode == .history else { return }
        historyFilterDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard !Task.isCancelled else { return }
            await viewModel.applyHistoryFilters()
        }
    }

    private func historyStatusLabel(_ value: String) -> String {
        switch value {
        case "PENDING":
            return "待审批"
        case "APPROVED":
            return "已通过"
        case "REJECTED":
            return "已驳回"
        default:
            return "全部状态"
        }
    }

    private func historyTypeLabel(_ value: String) -> String {
        switch value {
        case "CREATE":
            return "新增"
        case "UPDATE":
            return "修改"
        case "DELETE":
            return "删除"
        default:
            return "全部类型"
        }
    }

    private var historyPagerBar: some View {
        HStack(spacing: 12) {
            Button("上一页") {
                Task { await viewModel.prevHistoryPage() }
            }
            .buttonStyle(MetrologySecondaryButtonStyle())
            .disabled(viewModel.historyPage <= 1 || viewModel.isLoading)
            .opacity((viewModel.historyPage <= 1 || viewModel.isLoading) ? 0.45 : 1)

            Text("第 \(viewModel.historyPage) / \(viewModel.historyTotalPages) 页")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(MetrologyPalette.textSecondary)
                .frame(maxWidth: .infinity)

            Button("下一页") {
                Task { await viewModel.nextHistoryPage() }
            }
            .buttonStyle(MetrologyPrimaryButtonStyle())
            .disabled(viewModel.historyPage >= viewModel.historyTotalPages || viewModel.isLoading)
            .opacity((viewModel.historyPage >= viewModel.historyTotalPages || viewModel.isLoading) ? 0.45 : 1)
        }
    }

    private var auditListPanel: some View {
        MetrologySectionPanel(
            title: auditPanelTitle,
            subtitle: auditPanelSubtitle
        ) {
            VStack(spacing: 0) {
                if auditRows.isEmpty {
                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        MetrologyErrorStateView(
                            title: "审核记录加载失败",
                            message: errorMessage,
                            actionTitle: "重新加载",
                            action: {
                                Task { await viewModel.loadCurrent() }
                            }
                        )
                    } else {
                        MetrologyEmptyStateView(
                            icon: "tray",
                            title: "暂无审核记录",
                            message: "当前模式下还没有匹配数据，可以切换标签或调整历史筛选条件。"
                        )
                        .metrologyCard()
                    }
                } else {
                    ForEach(auditRows) { row in
                        AuditRowCard(
                            item: row.item,
                            showActionButtons: viewModel.isAdmin && viewModel.mode == .pending,
                            onTap: {
                                Task {
                                    if let detail = await viewModel.loadDetail(row.item) {
                                        detailSheetItem = AuditDetailSheetItem(record: detail)
                                    }
                                }
                            },
                            onApprove: {
                                Task { await viewModel.approve(row.item) }
                            },
                            onReject: {
                                rejectSheetItem = AuditRejectSheetItem(record: row.item)
                            }
                        )
                    }
                }

                if viewModel.mode == .history {
                    historyPagerBar
                        .padding(.top, 8)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private var modeTone: MetrologyPillTone {
        switch viewModel.mode {
        case .pending:
            return .warning
        case .my:
            return .neutral
        case .history:
            return .muted
        }
    }

    private var auditPanelTitle: String {
        switch viewModel.mode {
        case .pending:
            return "待审批记录"
        case .my:
            return "我的申请"
        case .history:
            return "审批历史"
        }
    }

    private var auditPanelSubtitle: String {
        switch viewModel.mode {
        case .pending:
            return "支持直接查看详情、通过或驳回，适合快速收口当前待审批任务。"
        case .my:
            return "集中查看自己提交的申请，便于跟踪审批进度与结果。"
        case .history:
            return "历史记录支持筛选与翻页，详情仅显示真实变更项。"
        }
    }
}

private struct AuditRowCard: View {
    let item: AuditRecordDto
    let showActionButtons: Bool
    let onTap: () -> Void
    let onApprove: () -> Void
    let onReject: () -> Void

    private var valueFont: Font {
        .system(size: 12, weight: .bold)
    }

    private var submittedByText: String {
        fallbackAuditText(item.submittedBy)
    }

    private var submittedAtText: String {
        auditTimeToMinute(item.submittedAt)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AUDIT")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(statusColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule(style: .continuous)
                                .fill(statusColor.opacity(0.12))
                        )

                    Text(translateType(item.type))
                        .font(.system(size: 15.5, weight: .black, design: .rounded))
                        .foregroundStyle(MetrologyPalette.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()

                Text(translateStatus(item.status))
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 11)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.16))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(statusColor.opacity(0.28), lineWidth: 1)
                    )
            }

                Text("对象: \(translateEntityType(item.entityType)) / ID: \(item.entityId.map(String.init) ?? "-")")
                .font(valueFont)
                .foregroundStyle(MetrologyPalette.textSecondary)
                .padding(.top, 8)
                .lineLimit(1)

                Text("提交人: \(submittedByText)")
                .font(valueFont)
                .foregroundStyle(MetrologyPalette.textSecondary)
                .padding(.top, 3)
                .lineLimit(1)

                Text("记录时间: \(submittedAtText)")
                .font(valueFont)
                .foregroundStyle(MetrologyPalette.textSecondary)
                .padding(.top, 3)
                .lineLimit(1)

            if showActionButtons {
                HStack(spacing: 10) {
                    Button("通过") { onApprove() }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MetrologyPalette.navActive)
                        .frame(minWidth: 56, minHeight: 28)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(hex: 0x2563EB, alpha: 0.13))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(hex: 0x2563EB, alpha: 0.40), lineWidth: 1)
                        )

                    Button("驳回") { onReject() }
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(MetrologyPalette.statusExpired)
                        .frame(minWidth: 56, minHeight: 28)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(hex: 0xDC2626, alpha: 0.12))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color(hex: 0xDC2626, alpha: 0.35), lineWidth: 1)
                        )

                    Spacer(minLength: 0)
                }
                .padding(.top, 6)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(hex: 0xF6FAFF)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: 0xD5E2F2), lineWidth: 1)
        )
        .shadow(color: Color(hex: 0x7A95B8, alpha: 0.12), radius: 8, x: 0, y: 4)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }

    private var statusColor: Color {
        switch (item.status ?? "").uppercased() {
        case "APPROVED":
            return .green
        case "REJECTED":
            return .red
        case "PENDING":
            return .orange
        default:
            return .gray
        }
    }
}

struct AuditDetailView: View {
    let record: AuditRecordDto
    @Environment(\.dismiss) private var dismiss
    @State private var compareMode: AuditCompareMode = .field

    private var diffRows: [AuditDiffRow] {
        buildAuditDiffRows(record: record)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    heroSection

                    if let bannerMessage {
                        MetrologyStatusBanner(message: bannerMessage, tone: bannerTone, compact: true)
                    }

                    MetrologySectionPanel(title: "基本信息", subtitle: "审批状态、提交人与审批信息统一展示。") {
                        VStack(spacing: 10) {
                            AuditDetailRow(label: "类型", value: translateType(record.type))
                            AuditDetailRow(label: "对象", value: translateEntityType(record.entityType))
                            AuditDetailRow(label: "对象 ID", value: record.entityId.map(String.init) ?? "-")
                            AuditDetailRow(label: "状态", value: translateStatus(record.status), tone: statusTone)
                            AuditDetailRow(label: "提交人", value: record.submittedBy ?? "-")
                            AuditDetailRow(label: "提交时间", value: auditTimeToMinute(record.submittedAt))
                            AuditDetailRow(label: "审批人", value: record.approvedBy ?? "-")
                            AuditDetailRow(label: "审批时间", value: auditTimeToMinute(record.approvedAt))
                            AuditDetailRow(label: "备注", value: record.remark ?? "-")
                            AuditDetailRow(label: "驳回原因", value: record.rejectReason ?? "-")
                        }
                    }

                    MetrologySectionPanel(title: "对比方式", subtitle: "字段对比仅保留真实变更项，原文对比便于快速复核。") {
                        Picker("对比方式", selection: $compareMode) {
                            Text("字段对比").tag(AuditCompareMode.field)
                            Text("原文对比").tag(AuditCompareMode.raw)
                        }
                        .pickerStyle(.segmented)
                    }

                    if compareMode == .field {
                        MetrologySectionPanel(title: "变更字段", subtitle: "共 \(diffRows.count) 项真实变更") {
                            if diffRows.isEmpty {
                                MetrologyEmptyStateView(
                                    icon: "checkmark.seal",
                                    title: "没有可展示的变更",
                                    message: "当前审批详情没有检测到可展示的字段差异。"
                                )
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(diffRows) { row in
                                        AuditDiffCard(row: row)
                                    }
                                }
                            }
                        }
                    } else {
                        MetrologySectionPanel(title: "原文对比", subtitle: "保留原始 JSON 视图，便于追查完整上下文。") {
                            AuditRawCompareCard(
                                title: "原始数据",
                                text: prettyAuditJSON(record.originalData)
                            )
                            AuditRawCompareCard(
                                title: "变更数据",
                                text: prettyAuditJSON(record.newData)
                            )
                        }
                    }
                }
                .padding(12)
                .padding(.bottom, 102)
            }
            .scrollIndicators(.hidden)

            VStack(spacing: 0) {
                Divider().overlay(Color(hex: 0xD5E2F2))
                MetrologySaveCancelRow(
                    cancelTitle: "关闭",
                    saveTitle: compareMode == .field ? "切换原文" : "切换字段",
                    onCancel: { dismiss() },
                    onSave: {
                        compareMode = compareMode == .field ? .raw : .field
                    }
                )
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(MetrologyPalette.background)
            }
        }
    }

    private var heroSection: some View {
        MetrologyPageHeroCard(
            eyebrow: "Audit Detail",
            title: auditTitle,
            subtitle: "审批详情仅保留真实变更项，适合快速复核当前申请的变更范围。",
            accent: statusTone
        ) {
            VStack(alignment: .trailing, spacing: 8) {
                Text("当前状态")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                Text(translateStatus(record.status))
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(statusTone.tint)
                Text("变更项 \(diffRows.count)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)
            }
        }
    }

    private var statusTone: MetrologyPillTone {
        switch (record.status ?? "").uppercased() {
        case "APPROVED": return .valid
        case "REJECTED": return .expired
        case "PENDING": return .warning
        default: return .neutral
        }
    }

    private var auditTitle: String {
        "\(translateType(record.type))申请 · \(translateStatus(record.status))"
    }

    private var bannerMessage: String? {
        let reject = record.rejectReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !reject.isEmpty {
            return "驳回原因：\(reject)"
        }
        let remark = record.remark?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !remark.isEmpty {
            return "备注：\(remark)"
        }
        return nil
    }

    private var bannerTone: MetrologyPillTone {
        let reject = record.rejectReason?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return reject.isEmpty ? .neutral : .expired
    }
}

private struct AuditRejectReasonSheet: View {
    let record: AuditRecordDto
    let onSubmit: (String?) -> Void
    let onCancel: () -> Void

    @State private var reason: String = ""

    var body: some View {
        ZStack(alignment: .bottom) {
            MetrologyFormSheetScaffold(
                eyebrow: "Reject",
                title: "驳回申请",
                subtitle: "填写驳回原因后提交，审批记录会保留该说明。",
                accent: .expired,
                bannerMessage: "留空也可提交，系统会按“无驳回原因”处理。",
                bannerTone: .warning
            ) {
                MetrologySectionPanel(title: "审批信息", subtitle: "确认记录后再填写驳回原因。") {
                    VStack(spacing: 10) {
                        AuditDetailRow(label: "记录 ID", value: record.id.map(String.init) ?? "-")
                        AuditDetailRow(label: "类型", value: translateType(record.type))
                        AuditDetailRow(label: "对象", value: translateEntityType(record.entityType))
                    }
                }

                MetrologySectionPanel(title: "驳回原因", subtitle: "建议写明不通过原因，方便申请人快速修正。") {
                    TextEditor(text: $reason)
                        .frame(minHeight: 140)
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(MetrologyPalette.stroke, lineWidth: 1)
                        )
                }
            }

            VStack(spacing: 0) {
                Divider().overlay(Color(hex: 0xD5E2F2))
                MetrologySaveCancelRow(
                    cancelTitle: "取消",
                    saveTitle: "提交驳回",
                    onCancel: { onCancel() },
                    onSave: {
                        let text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSubmit(text.isEmpty ? nil : text)
                    }
                )
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(MetrologyPalette.background)
            }
        }
    }
}

private struct AuditDetailSheetItem: Identifiable {
    let id = UUID()
    let record: AuditRecordDto
}

private struct AuditRejectSheetItem: Identifiable {
    let id = UUID()
    let record: AuditRecordDto
}

private struct AuditListRow: Identifiable {
    let id: String
    let item: AuditRecordDto
}

private struct AuditDetailRow: View {
    let label: String
    let value: String
    var tone: MetrologyPillTone? = nil

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            if let tone, value != "-" {
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tone.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(tone.background)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(tone.stroke, lineWidth: 1)
                    )
            } else {
                Text(value)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}

private struct AuditDiffCard: View {
    let row: AuditDiffRow

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(row.label)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)

            VStack(alignment: .leading, spacing: 4) {
                Text("修改前")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                Text(row.originalDisplay)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.red.opacity(row.changeStyle == .added ? 0.04 : 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("修改后")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MetrologyPalette.textSecondary)
                Text(row.newDisplay)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(MetrologyPalette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.green.opacity(row.changeStyle == .removed ? 0.04 : 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color(hex: 0xD5E2F2), lineWidth: 1)
        )
    }
}

private struct AuditRawCompareCard: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .padding(8)
            .background(MetrologyPalette.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}

private enum AuditCompareMode {
    case field
    case raw
}

private struct AuditDiffRow: Identifiable {
    let key: String
    let label: String
    let originalValue: String
    let newValue: String
    let changeStyle: AuditChangeStyle

    var id: String { key }
    var originalDisplay: String { originalValue.isEmpty ? "-" : originalValue }
    var newDisplay: String { newValue.isEmpty ? "-" : newValue }
}

private enum AuditChangeStyle {
    case added
    case removed
    case changed
}

private func auditTimeToMinute(_ value: String?) -> String {
    let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !raw.isEmpty else { return "-" }

    var normalized = raw.replacingOccurrences(of: "T", with: " ")
    normalized = normalized.replacingOccurrences(of: "/", with: "-")

    if let dotIndex = normalized.firstIndex(of: ".") {
        normalized = String(normalized[..<dotIndex])
    }
    if let zIndex = normalized.firstIndex(of: "Z") {
        normalized = String(normalized[..<zIndex])
    }
    normalized = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.count >= 16 {
        return String(normalized.prefix(16))
    }
    return normalized
}

private func buildAuditDiffRows(record: AuditRecordDto) -> [AuditDiffRow] {
    let oldObject = parseAuditObject(record.originalData)
    let newObject = parseAuditObject(record.newData)
    let type = (record.type ?? "").uppercased()

    if oldObject.isEmpty && newObject.isEmpty {
        let oldRaw = record.originalData?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let newRaw = record.newData?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if oldRaw != newRaw {
            return [
                AuditDiffRow(
                    key: "raw",
                    label: "\u{539f}\u{6587}\u{5185}\u{5bb9}",
                    originalValue: oldRaw,
                    newValue: newRaw,
                    changeStyle: .changed
                )
            ]
        }
        return []
    }

    switch type {
    case "UPDATE":
        let keys = sortAuditKeys(Array(newObject.keys).filter { !auditSkipFields.contains($0) })
        return keys.compactMap { key in
            guard let newRaw = newObject[key], !(newRaw is NSNull) else { return nil }
            let oldValue = normalizeAuditFieldValue(key: key, value: oldObject[key])
            let newValue = normalizeAuditFieldValue(key: key, value: newRaw)
            if comparableAuditValue(oldValue) == comparableAuditValue(newValue) {
                return nil
            }
            return AuditDiffRow(
                key: key,
                label: auditFieldLabel(key),
                originalValue: oldValue,
                newValue: newValue,
                changeStyle: .changed
            )
        }
    case "CREATE":
        let keys = sortAuditKeys(Array(newObject.keys).filter { !auditSkipFields.contains($0) })
        return keys.compactMap { key in
            guard hasAuditDisplayValue(newObject[key]) else { return nil }
            return AuditDiffRow(
                key: key,
                label: auditFieldLabel(key),
                originalValue: "",
                newValue: normalizeAuditFieldValue(key: key, value: newObject[key]),
                changeStyle: .added
            )
        }
    case "DELETE":
        let keys = sortAuditKeys(Array(oldObject.keys).filter { !auditSkipFields.contains($0) })
        return keys.compactMap { key in
            guard hasAuditDisplayValue(oldObject[key]) else { return nil }
            return AuditDiffRow(
                key: key,
                label: auditFieldLabel(key),
                originalValue: normalizeAuditFieldValue(key: key, value: oldObject[key]),
                newValue: "",
                changeStyle: .removed
            )
        }
    default:
        let keys = sortAuditKeys(Array(Set(oldObject.keys).union(newObject.keys)).filter { !auditSkipFields.contains($0) })
        return keys.compactMap { key in
            let oldValue = normalizeAuditFieldValue(key: key, value: oldObject[key])
            let newValue = normalizeAuditFieldValue(key: key, value: newObject[key])
            if comparableAuditValue(oldValue) == comparableAuditValue(newValue) {
                return nil
            }
            return AuditDiffRow(
                key: key,
                label: auditFieldLabel(key),
                originalValue: oldValue,
                newValue: newValue,
                changeStyle: .changed
            )
        }
    }
}

private func parseAuditObject(_ raw: String?) -> [String: Any] {
    guard let raw else { return [:] }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return [:] }
    guard let json = try? JSONSerialization.jsonObject(with: data) else { return [:] }
    return json as? [String: Any] ?? [:]
}

private func normalizeAuditFieldValue(key: String, value: Any?) -> String {
    guard let value, !(value is NSNull) else { return "-" }
    let text = stringifyAuditValue(value)
    if text.isEmpty || text.lowercased() == "null" {
        return "-"
    }

    switch key {
    case "type":
        return translateType(text)
    case "entityType":
        return translateEntityType(text)
    case "status":
        return translateStatus(text)
    case "validity":
        return translateValidity(text)
    case "calibrationResult", "result":
        return translateCalibrationResult(text)
    case "submittedAt", "approvedAt":
        return auditTimeToMinute(text)
    case "cycle":
        if let cycle = Int(text) {
        if cycle == 6 { return "半年" }
        if cycle == 12 { return "一年" }
        return "\(cycle)个月"
        }
        return text
    default:
        return text
    }
}

private func stringifyAuditValue(_ value: Any) -> String {
    if let text = value as? String {
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let boolValue = value as? Bool {
        return boolValue ? "\u{662f}" : "\u{5426}"
    }
    if let number = value as? NSNumber {
        return number.stringValue
    }
    if let dict = value as? [String: Any],
       let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
       let jsonText = String(data: data, encoding: .utf8) {
        return jsonText
    }
    if let array = value as? [Any] {
        return array.map { stringifyAuditValue($0) }.joined(separator: ", ")
    }
    return "\(value)"
}

private func hasAuditDisplayValue(_ value: Any?) -> Bool {
    guard let value, !(value is NSNull) else { return false }
    let text = stringifyAuditValue(value)
    return !text.isEmpty && text.lowercased() != "null"
}

private func comparableAuditValue(_ value: String) -> String? {
    let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if normalized.isEmpty || normalized == "-" || normalized.lowercased() == "null" {
        return nil
    }
    return normalized
}

private func prettyAuditJSON(_ raw: String?) -> String {
    guard let raw else { return "-" }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return "-" }
    guard let json = try? JSONSerialization.jsonObject(with: data),
          let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
          let text = String(data: pretty, encoding: .utf8) else {
        return trimmed
    }
    return text
}

private func sortAuditKeys(_ keys: [String]) -> [String] {
    keys.sorted {
        let leftOrder = auditFieldSortOrder[$0] ?? Int.max
        let rightOrder = auditFieldSortOrder[$1] ?? Int.max
        if leftOrder != rightOrder {
            return leftOrder < rightOrder
        }
        return auditFieldLabel($0) < auditFieldLabel($1)
    }
}

private func auditFieldLabel(_ key: String) -> String {
    auditFieldLabels[key] ?? key
}

private func translateType(_ value: String?) -> String {
    let code = (value ?? "").uppercased()
    switch code {
    case "CREATE":
            return "新增"
    case "UPDATE":
            return "修改"
    case "DELETE":
            return "删除"
    default:
        return fallbackAuditText(value)
    }
}

private func translateEntityType(_ value: String?) -> String {
    let code = (value ?? "").uppercased()
    switch code {
    case "DEVICE":
            return "设备"
    case "CALIBRATION":
            return "校准"
    case "USER":
            return "用户"
    case "DEPARTMENT":
            return "部门"
    default:
        return fallbackAuditText(value)
    }
}

private func translateStatus(_ value: String?) -> String {
    let code = (value ?? "").uppercased()
    switch code {
    case "PENDING":
            return "待审批"
    case "APPROVED":
            return "已通过"
    case "REJECTED":
            return "已驳回"
    case "NORMAL":
            return "正常"
    case "FAULT":
            return "故障"
    case "SCRAP":
            return "报废"
    default:
        return fallbackAuditText(value)
    }
}

private func translateValidity(_ value: String?) -> String {
    let code = (value ?? "").uppercased()
    switch code {
    case "VALID":
            return "有效"
    case "WARNING", "EXPIRING", "NEAR_EXPIRY":
            return "即将过期"
    case "EXPIRED", "INVALID":
            return "失效"
    default:
        return fallbackAuditText(value)
    }
}

private func translateCalibrationResult(_ value: String?) -> String {
    let code = (value ?? "").uppercased()
    switch code {
    case "QUALIFIED":
            return "合格"
    case "UNQUALIFIED":
            return "不合格"
    default:
        return fallbackAuditText(value)
    }
}

private func fallbackAuditText(_ value: String?) -> String {
    let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return text.isEmpty ? "-" : text
}

private let auditSkipFields: Set<String> = [
    "id",
    "nextCalDate",
    "nextDate",
    "validity",
    "daysPassed"
]

private let auditFieldLabels: [String: String] = [
    "name": "\u{8bbe}\u{5907}\u{540d}\u{79f0}",
    "metricNo": "\u{8ba1}\u{91cf}\u{7f16}\u{53f7}",
    "meteringNo": "\u{8ba1}\u{91cf}\u{7f16}\u{53f7}",
    "assetNo": "\u{8d44}\u{4ea7}\u{7f16}\u{53f7}",
    "serialNo": "\u{51fa}\u{5382}\u{7f16}\u{53f7}",
    "abcClass": "\u{41}\u{42}\u{43}\u{5206}\u{7c7b}",
    "dept": "\u{90e8}\u{95e8}",
    "location": "\u{8bbe}\u{5907}\u{4f4d}\u{7f6e}",
    "responsiblePerson": "\u{8d23}\u{4efb}\u{4eba}",
    "useStatus": "\u{4f7f}\u{7528}\u{72b6}\u{6001}",
    "status": "\u{72b6}\u{6001}",
    "cycle": "\u{68c0}\u{5b9a}\u{5468}\u{671f}",
    "calDate": "\u{4e0a}\u{6b21}\u{6821}\u{51c6}",
    "nextDate": "\u{4e0b}\u{6b21}\u{6821}\u{51c6}",
    "calibrationResult": "\u{6821}\u{51c6}\u{7ed3}\u{679c}",
    "remark": "\u{5907}\u{6ce8}",
    "manufacturer": "\u{5236}\u{9020}\u{5382}",
    "model": "\u{8bbe}\u{5907}\u{578b}\u{53f7}",
    "purchaseDate": "\u{91c7}\u{8d2d}\u{65e5}\u{671f}",
    "purchasePrice": "\u{91c7}\u{8d2d}\u{4ef7}\u{683c}",
    "graduationValue": "\u{5206}\u{5ea6}\u{503c}",
    "testRange": "\u{6d4b}\u{8bd5}\u{8303}\u{56f4}",
    "allowableError": "\u{5141}\u{8bb8}\u{8bef}\u{5dee}",
    "serviceLife": "\u{4f7f}\u{7528}\u{5e74}\u{9650}",
    "entityType": "\u{5bf9}\u{8c61}\u{7c7b}\u{578b}",
    "type": "\u{64cd}\u{4f5c}\u{7c7b}\u{578b}",
    "submittedBy": "\u{63d0}\u{4ea4}\u{4eba}",
    "submittedAt": "\u{63d0}\u{4ea4}\u{65f6}\u{95f4}",
    "approvedBy": "\u{5ba1}\u{6279}\u{4eba}",
    "approvedAt": "\u{5ba1}\u{6279}\u{65f6}\u{95f4}",
    "rejectReason": "\u{9a73}\u{56de}\u{539f}\u{56e0}"
]

private let auditFieldSortOrder: [String: Int] = [
    "name": 1,
    "metricNo": 2,
    "meteringNo": 2,
    "assetNo": 3,
    "serialNo": 4,
    "abcClass": 5,
    "dept": 6,
    "location": 7,
    "responsiblePerson": 8,
    "useStatus": 9,
    "status": 10,
    "cycle": 11,
    "calDate": 12,
    "nextDate": 13,
    "calibrationResult": 14,
    "remark": 15,
    "manufacturer": 16,
    "model": 17,
    "purchaseDate": 18,
    "purchasePrice": 19,
    "graduationValue": 20,
    "testRange": 21,
    "allowableError": 22,
    "serviceLife": 23
]

private extension Color {
    init(hex: Int, alpha: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }
}
