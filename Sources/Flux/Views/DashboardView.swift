import SwiftUI

/// The main window: a grid of metric cards plus placeholders for the live
/// charts and process table that arrive in Phase 2.
struct DashboardView: View {
    @ObservedObject var metrics: MetricsCollector
    @ObservedObject var processes: ProcessCollector
    @ObservedObject var history: HistoryStore

    private let columns = [GridItem(.adaptive(minimum: 170), spacing: 16)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Dashboard")
                    .font(.largeTitle.bold())

                LazyVGrid(columns: columns, spacing: 16) {
                    MetricCard(title: "CPU", value: metrics.latest?.cpuPercentText ?? "—", systemImage: "cpu")
                    MetricCard(title: "Memory", value: metrics.latest?.memoryText ?? "—", systemImage: "memorychip")
                    MetricCard(title: "Battery", value: metrics.latest?.batteryText ?? "—", systemImage: "battery.100")
                    MetricCard(title: "Network", value: metrics.latest?.networkText ?? "—", systemImage: "network")
                    MetricCard(title: "Storage", value: SystemInfo.diskText, systemImage: "internaldrive")
                    MetricCard(title: "Uptime", value: SystemInfo.uptimeText, systemImage: "clock")
                }

                // TODO(phase2): live CPU / memory / network charts (Swift Charts).
                placeholderBox("CPU over time", note: "Charts arrive in Phase 2")

                // TODO(phase2): top processes table, sortable via processes.sortKey.
                placeholderBox("Top processes", note: "Process table arrives in Phase 2")
            }
            .padding(24)
        }
        .frame(minWidth: 640, minHeight: 480)
        .task { metrics.start() }
    }

    private func placeholderBox(_ title: String, note: String) -> some View {
        GroupBox(title) {
            Text(note)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }
}

/// A single labelled metric card used in the dashboard grid.
private struct MetricCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        GroupBox {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                Spacer()
            }
            .padding(4)
        }
    }
}
