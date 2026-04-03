import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let message = viewModel.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                MetricCard(title: "设备总数", value: viewModel.total, color: .blue)
                MetricCard(title: "本月到期", value: viewModel.dueThisMonth, color: .orange)
                MetricCard(title: "有效设备", value: viewModel.valid, color: .green)
                MetricCard(title: "失效/预警", value: viewModel.risk, color: .red)
            }
            .padding(16)
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
            }
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: Int64
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
