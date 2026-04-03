import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ZStack {
            MetrologyPalette.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    if let message = viewModel.errorMessage {
                        Text(message)
                            .foregroundStyle(Color.red.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .metrologyCard()
                    }

                    MetricCard(title: "设备总数", value: viewModel.total, accent: MetrologyPalette.accent)
                    MetricCard(title: "本月到期", value: viewModel.dueThisMonth, accent: Color.orange)
                    MetricCard(title: "有效设备", value: viewModel.valid, accent: Color.green)
                    MetricCard(title: "失效/预警", value: viewModel.risk, accent: Color.red)
                }
                .padding(16)
                .padding(.bottom, 12)
            }
        }
        .navigationTitle("总览看板")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("刷新") {
                    Task { await viewModel.load() }
                }
            }
        }
        .task {
            await viewModel.load()
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("加载中...")
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(MetrologyPalette.surface)
                    )
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int64
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(MetrologyPalette.textSecondary)
            Text(formatCount(value))
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .metrologyCard()
    }

    private func formatCount(_ number: Int64) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
    }
}
