import SwiftUI

struct SystemMaintenanceView: View {
    @StateObject private var viewModel = SystemMaintenanceViewModel()

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 10) {
                    if let errorMessage = viewModel.errorMessage, cmsContentIsEmpty {
                        MetrologyErrorStateView(
                            title: "系统维护配置加载失败",
                            message: errorMessage,
                            actionTitle: "重新加载",
                            action: {
                                Task { await viewModel.reload() }
                            }
                        )
                    }

                    thresholdCard
                    automationCard
                    statusLine
                    actionBar
                }
                .padding(.horizontal, MetrologyLayout.pageHorizontalPadding)
                .padding(.bottom, 18)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)

            if let errorMessage = viewModel.errorMessage {
                MetrologyNoticeDialog(
                    title: "提示",
                    message: errorMessage,
                    eyebrow: "Notice",
                    tone: .warning
                ) {
                    viewModel.errorMessage = nil
                }
            }
        }
        .overlay {
            if viewModel.isLoading {
                MetrologyLoadingCard(title: "加载中...")
            }
        }
        .navigationTitle("系统维护")
        .task {
            await viewModel.initialLoad()
        }
    }

    private var thresholdCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("校准到期预警天数")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)

            TextField("输入预警天数", text: $viewModel.warningDays)
                .keyboardType(.numberPad)
                .metrologyInput()

            Text("失效判定天数")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)
                .padding(.top, 4)

            TextField("输入失效天数", text: $viewModel.expiredDays)
                .keyboardType(.numberPad)
                .metrologyInput()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0xEEF4FF))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0xD5E2F2), lineWidth: 1)
        )
    }

    private var automationCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("每天 23:00 自动导出台账", isOn: $viewModel.autoExport)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MetrologyPalette.textPrimary)

            Text("台账导出文件: \(viewModel.ledgerExportPath)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)

            Toggle("每天 23:00 自动备份数据库", isOn: $viewModel.autoBackup)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(MetrologyPalette.textPrimary)
                .padding(.top, 6)

            Text("数据库备份文件: \(viewModel.databaseBackupPath)")
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(MetrologyPalette.textSecondary)

            Text("CMS 根目录")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MetrologyPalette.textPrimary)
                .padding(.top, 4)

            TextField("输入 CMS 根目录", text: $viewModel.cmsRootPath)
                .metrologyInput()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(hex: 0xECF9F2))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color(hex: 0xCFEADB), lineWidth: 1)
        )
    }

    private var statusLine: some View {
        MetrologyStatusBanner(
            message: viewModel.statusMessage.isEmpty ? "可在这里调整预警阈值、自动导出与备份策略。" : viewModel.statusMessage,
            tone: viewModel.errorMessage == nil ? .neutral : .expired,
            compact: true
        )
    }

    private var actionBar: some View {
        HStack(spacing: 10) {
            Button("保存") {
                metrologyDismissKeyboard()
                Task { await viewModel.save() }
            }
            .frame(maxWidth: .infinity, minHeight: 22)
            .buttonStyle(MetrologyPrimaryButtonStyle())
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0.45 : 1)

            Button("立即执行一次") {
                metrologyDismissKeyboard()
                Task { await viewModel.runMaintenance() }
            }
            .frame(maxWidth: .infinity, minHeight: 22)
            .buttonStyle(MetrologySecondaryButtonStyle())
            .disabled(viewModel.isLoading)
            .opacity(viewModel.isLoading ? 0.45 : 1)
        }
    }
}

@MainActor
final class SystemMaintenanceViewModel: ObservableObject {
    @Published var warningDays: String = "315"
    @Published var expiredDays: String = "360"
    @Published var autoExport: Bool = false
    @Published var autoBackup: Bool = false
    @Published var cmsRootPath: String = ""
    @Published var ledgerExportPath: String = "-"
    @Published var databaseBackupPath: String = "-"

    @Published private(set) var isLoading: Bool = false
    @Published var statusMessage: String = ""
    @Published var errorMessage: String?

    private var loaded = false
    private var latestSettings: SettingsDto?

    func initialLoad() async {
        guard !loaded else { return }
        loaded = true
        await load()
    }

    func reload() async {
        await load()
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let settings = try await APIClient.shared.settings()
            apply(settings: settings)
            statusMessage = ""
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
            statusMessage = ""
        }
    }

    func save() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let payload = SettingsDto(
                warningDays: Int(warningDays.trimmingCharacters(in: .whitespacesAndNewlines)) ?? latestSettings?.warningDays,
                expiredDays: Int(expiredDays.trimmingCharacters(in: .whitespacesAndNewlines)) ?? latestSettings?.expiredDays,
                autoLedgerExportEnabled: autoExport,
                databaseBackupEnabled: autoBackup,
                cmsRootPath: cmsRootPath.trimmingCharacters(in: .whitespacesAndNewlines),
                ledgerExportPath: latestSettings?.ledgerExportPath,
                databaseBackupPath: latestSettings?.databaseBackupPath
            )
            let saved = try await APIClient.shared.saveSettings(payload)
            apply(settings: saved)
            statusMessage = "系统维护配置已保存"
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    func runMaintenance() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let result = try await APIClient.shared.runMaintenanceNow()
            let message = result.message?.trimmingCharacters(in: .whitespacesAndNewlines)
            statusMessage = "执行结果：\(message?.isEmpty == false ? message! : "成功")"
            if let exportPath = result.ledgerExportPath, !exportPath.isEmpty {
                ledgerExportPath = exportPath
            }
            if let backupPath = result.databaseBackupPath, !backupPath.isEmpty {
                databaseBackupPath = backupPath
            }
        } catch {
            errorMessage = (error as? APIError)?.localizedDescription ?? error.localizedDescription
        }
    }

    private func apply(settings: SettingsDto) {
        latestSettings = settings
        warningDays = String(settings.warningDays ?? 315)
        expiredDays = String(settings.expiredDays ?? 360)
        autoExport = settings.autoLedgerExportEnabled == true
        autoBackup = settings.databaseBackupEnabled == true
        cmsRootPath = settings.cmsRootPath ?? ""
        ledgerExportPath = (settings.ledgerExportPath?.isEmpty == false) ? settings.ledgerExportPath! : "-"
        databaseBackupPath = (settings.databaseBackupPath?.isEmpty == false) ? settings.databaseBackupPath! : "-"
    }
}

private extension SystemMaintenanceView {
    var cmsContentIsEmpty: Bool {
        viewModel.cmsRootPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && viewModel.ledgerExportPath == "-"
            && viewModel.databaseBackupPath == "-"
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
