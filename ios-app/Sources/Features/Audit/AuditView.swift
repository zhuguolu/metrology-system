import Foundation
import SwiftUI

struct AuditView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = AuditViewModel()

    @State private var detailSheetItem: AuditDetailSheetItem?
    @State private var rejectSheetItem: AuditRejectSheetItem?

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                if viewModel.isAdmin {
                    Picker("\u{5ba1}\u{6838}\u{6a21}\u{5f0f}", selection: $viewModel.mode) {
                        Text(AuditListMode.pending.title).tag(AuditListMode.pending)
                        Text(AuditListMode.my.title).tag(AuditListMode.my)
                        Text(AuditListMode.history.title).tag(AuditListMode.history)
                    }
                    .pickerStyle(.segmented)
                }

                if viewModel.mode == .history {
                    historyFilterPanel
                }

                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.mode == .history, !viewModel.historyHint.isEmpty {
                    Text(viewModel.historyHint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if viewModel.mode == .history,
                   let fallbackHint = viewModel.historyFallbackHint,
                   !fallbackHint.isEmpty {
                    Text(fallbackHint)
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                List {
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
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)

                if viewModel.mode == .history {
                    historyPagerBar
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .navigationTitle("\u{6570}\u{636e}\u{5ba1}\u{6838}")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("\u{5237}\u{65b0}") {
                        Task { await viewModel.loadCurrent() }
                    }
                }
            }
            .task {
                viewModel.configure(role: appState.session?.role, username: appState.session?.username)
                await viewModel.loadCurrent()
            }
            .onChange(of: sessionIdentity) { _ in
                viewModel.configure(role: appState.session?.role, username: appState.session?.username)
                Task { await viewModel.loadCurrent() }
            }
            .onChange(of: viewModel.mode) { _ in
                Task { await viewModel.loadCurrent() }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView("\u{52a0}\u{8f7d}\u{4e2d}\u{2e}\u{2e}\u{2e}")
                        .padding(14)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
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
        VStack(spacing: 8) {
            TextField(
                "\u{5173}\u{952e}\u{8bcd}\u{ff1a}\u{8bbe}\u{5907}\u{540d}\u{79f0}\u{2f}\u{8ba1}\u{91cf}\u{7f16}\u{53f7}\u{2f}\u{63d0}\u{4ea4}\u{4eba}",
                text: $viewModel.historyKeyword
            )
            .textFieldStyle(.roundedBorder)

            HStack(spacing: 8) {
                Picker("\u{72b6}\u{6001}", selection: $viewModel.historyStatusFilter) {
                    Text("\u{5168}\u{90e8}\u{72b6}\u{6001}").tag("")
                    Text("\u{5f85}\u{5ba1}\u{6279}").tag("PENDING")
                    Text("\u{5df2}\u{901a}\u{8fc7}").tag("APPROVED")
                    Text("\u{5df2}\u{9a73}\u{56de}").tag("REJECTED")
                }
                .pickerStyle(.menu)

                Picker("\u{7c7b}\u{578b}", selection: $viewModel.historyTypeFilter) {
                    Text("\u{5168}\u{90e8}\u{7c7b}\u{578b}").tag("")
                    Text("\u{65b0}\u{589e}").tag("CREATE")
                    Text("\u{4fee}\u{6539}").tag("UPDATE")
                    Text("\u{5220}\u{9664}").tag("DELETE")
                }
                .pickerStyle(.menu)

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Button("\u{67e5}\u{8be2}") {
                    Task { await viewModel.applyHistoryFilters() }
                }
                .buttonStyle(.borderedProminent)

                Button("\u{91cd}\u{7f6e}") {
                    Task { await viewModel.resetHistoryFilters() }
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)
            }
        }
    }

    private var historyPagerBar: some View {
        HStack(spacing: 12) {
            Button("\u{4e0a}\u{4e00}\u{9875}") {
                Task { await viewModel.prevHistoryPage() }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.historyPage <= 1 || viewModel.isLoading)

            Text("\u{7b2c} \(viewModel.historyPage) / \(viewModel.historyTotalPages) \u{9875}")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("\u{4e0b}\u{4e00}\u{9875}") {
                Task { await viewModel.nextHistoryPage() }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.historyPage >= viewModel.historyTotalPages || viewModel.isLoading)
        }
        .padding(.bottom, 8)
    }
}

private struct AuditRowCard: View {
    let item: AuditRecordDto
    let showActionButtons: Bool
    let onTap: () -> Void
    let onApprove: () -> Void
    let onReject: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(translateType(item.type))
                    .font(.headline)
                Spacer()
                Text(translateStatus(item.status))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor.opacity(0.14))
                    .foregroundStyle(statusColor)
                    .clipShape(Capsule())
            }

            Text("\u{5bf9}\u{8c61}: \(translateEntityType(item.entityType)) / ID: \(item.entityId.map(String.init) ?? "-")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("\u{63d0}\u{4ea4}\u{4eba}: \(item.submittedBy ?? "-")   \u{63d0}\u{4ea4}\u{65f6}\u{95f4}: \(item.submittedAt ?? "-")")
                .font(.caption)
                .foregroundStyle(.secondary)

            if showActionButtons {
                HStack(spacing: 10) {
                    Button("\u{901a}\u{8fc7}") { onApprove() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    Button("\u{9a73}\u{56de}") { onReject() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
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

private struct AuditDetailView: View {
    let record: AuditRecordDto
    @Environment(\.dismiss) private var dismiss
    @State private var compareMode: AuditCompareMode = .field

    private var diffRows: [AuditDiffRow] {
        buildAuditDiffRows(record: record)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("\u{57fa}\u{672c}\u{4fe1}\u{606f}") {
                    AuditDetailRow(label: "\u{7c7b}\u{578b}", value: translateType(record.type))
                    AuditDetailRow(label: "\u{5bf9}\u{8c61}", value: translateEntityType(record.entityType))
                    AuditDetailRow(label: "\u{5bf9}\u{8c61}\u{49}\u{44}", value: record.entityId.map(String.init) ?? "-")
                    AuditDetailRow(label: "\u{72b6}\u{6001}", value: translateStatus(record.status))
                    AuditDetailRow(label: "\u{63d0}\u{4ea4}\u{4eba}", value: record.submittedBy ?? "-")
                    AuditDetailRow(label: "\u{63d0}\u{4ea4}\u{65f6}\u{95f4}", value: record.submittedAt ?? "-")
                    AuditDetailRow(label: "\u{5ba1}\u{6279}\u{4eba}", value: record.approvedBy ?? "-")
                    AuditDetailRow(label: "\u{5ba1}\u{6279}\u{65f6}\u{95f4}", value: record.approvedAt ?? "-")
                    AuditDetailRow(label: "\u{5907}\u{6ce8}", value: record.remark ?? "-")
                    AuditDetailRow(label: "\u{9a73}\u{56de}\u{539f}\u{56e0}", value: record.rejectReason ?? "-")
                }

                Section("\u{5bf9}\u{6bd4}\u{65b9}\u{5f0f}") {
                    Picker("\u{5bf9}\u{6bd4}\u{65b9}\u{5f0f}", selection: $compareMode) {
                        Text("\u{5b57}\u{6bb5}\u{5bf9}\u{6bd4}").tag(AuditCompareMode.field)
                        Text("\u{539f}\u{6587}\u{5bf9}\u{6bd4}").tag(AuditCompareMode.raw)
                    }
                    .pickerStyle(.segmented)
                }

                if compareMode == .field {
                    Section("\u{5b57}\u{6bb5}\u{5bf9}\u{6bd4}\u{ff08}\(diffRows.count) \u{9879}\u{ff09}") {
                        if diffRows.isEmpty {
                            Text("\u{672a}\u{68c0}\u{6d4b}\u{5230}\u{53ef}\u{5c55}\u{793a}\u{7684}\u{5dee}\u{5f02}")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(diffRows) { row in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(row.label)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\u{539f}\u{59cb}\u{503c}")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(row.originalDisplay)
                                            .font(.footnote)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(8)
                                            .background(Color.red.opacity(row.changeStyle == .added ? 0.04 : 0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\u{53d8}\u{66f4}\u{503c}")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(row.newDisplay)
                                            .font(.footnote)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding(8)
                                            .background(Color.green.opacity(row.changeStyle == .removed ? 0.04 : 0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                } else {
                    Section("\u{539f}\u{6587}\u{5bf9}\u{6bd4}") {
                        AuditRawCompareCard(
                            title: "\u{539f}\u{59cb}\u{6570}\u{636e}",
                            text: prettyAuditJSON(record.originalData)
                        )
                        AuditRawCompareCard(
                            title: "\u{53d8}\u{66f4}\u{6570}\u{636e}",
                            text: prettyAuditJSON(record.newData)
                        )
                    }
                }
            }
            .navigationTitle("\u{5ba1}\u{6838}\u{8be6}\u{60c5}")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("\u{5173}\u{95ed}") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct AuditRejectReasonSheet: View {
    let record: AuditRecordDto
    let onSubmit: (String?) -> Void
    let onCancel: () -> Void

    @State private var reason: String = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("\u{8bb0}\u{5f55}\u{49}\u{44}: \(record.id.map(String.init) ?? "-")")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextEditor(text: $reason)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
            }
            .padding(14)
            .navigationTitle("\u{9a73}\u{56de}\u{539f}\u{56e0}")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("\u{53d6}\u{6d88}") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\u{63d0}\u{4ea4}") {
                        let text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSubmit(text.isEmpty ? nil : text)
                    }
                }
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

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
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
            .background(Color(.secondarySystemBackground))
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
    case "cycle":
        if let cycle = Int(text) {
            if cycle == 6 { return "\u{534a}\u{5e74}" }
            if cycle == 12 { return "\u{4e00}\u{5e74}" }
            return "\(cycle)\u{4e2a}\u{6708}"
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
        return "\u{65b0}\u{589e}"
    case "UPDATE":
        return "\u{4fee}\u{6539}"
    case "DELETE":
        return "\u{5220}\u{9664}"
    default:
        return fallbackAuditText(value)
    }
}

private func translateEntityType(_ value: String?) -> String {
    let code = (value ?? "").uppercased()
    switch code {
    case "DEVICE":
        return "\u{8bbe}\u{5907}"
    case "CALIBRATION":
        return "\u{6821}\u{51c6}"
    case "USER":
        return "\u{7528}\u{6237}"
    case "DEPARTMENT":
        return "\u{90e8}\u{95e8}"
    default:
        return fallbackAuditText(value)
    }
}

private func translateStatus(_ value: String?) -> String {
    let code = (value ?? "").uppercased()
    switch code {
    case "PENDING":
        return "\u{5f85}\u{5ba1}\u{6279}"
    case "APPROVED":
        return "\u{5df2}\u{901a}\u{8fc7}"
    case "REJECTED":
        return "\u{5df2}\u{9a73}\u{56de}"
    case "NORMAL":
        return "\u{6b63}\u{5e38}"
    case "FAULT":
        return "\u{6545}\u{969c}"
    case "SCRAP":
        return "\u{62a5}\u{5e9f}"
    default:
        return fallbackAuditText(value)
    }
}

private func translateValidity(_ value: String?) -> String {
    let code = (value ?? "").uppercased()
    switch code {
    case "VALID":
        return "\u{6709}\u{6548}"
    case "WARNING", "EXPIRING", "NEAR_EXPIRY":
        return "\u{5373}\u{5c06}\u{8fc7}\u{671f}"
    case "EXPIRED", "INVALID":
        return "\u{5931}\u{6548}"
    default:
        return fallbackAuditText(value)
    }
}

private func translateCalibrationResult(_ value: String?) -> String {
    let code = (value ?? "").uppercased()
    switch code {
    case "QUALIFIED":
        return "\u{5408}\u{683c}"
    case "UNQUALIFIED":
        return "\u{4e0d}\u{5408}\u{683c}"
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
