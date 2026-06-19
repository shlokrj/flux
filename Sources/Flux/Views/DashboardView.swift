import SwiftUI

/// The main window: a grid of metric cards and a live, sortable process table,
/// plus a placeholder for the charts that arrive in Phase 2.
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

                processSection
            }
            .padding(24)
        }
        .frame(minWidth: 640, minHeight: 480)
        .task {
            metrics.start()
            processes.start()
        }
    }

    private func placeholderBox(_ title: String, note: String) -> some View {
        GroupBox(title) {
            Text(note)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120)
        }
    }

    private var processSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Top processes").font(.headline)
                    Spacer()
                    Picker("Sort", selection: $processes.sortKey) {
                        ForEach(ProcessCollector.SortKey.allCases) { key in
                            Text(key.rawValue).tag(key)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                ProcessRow(name: "Process", cpu: "CPU", memory: "RAM", isHeader: true)
                Divider()

                if processes.processes.isEmpty {
                    Text("Sampling…")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, minHeight: 80)
                } else {
                    ForEach(processes.sorted.prefix(12)) { process in
                        ProcessRow(
                            name: process.name,
                            cpu: process.cpuPercentText,
                            memory: process.memoryText
                        )
                    }
                }
            }
            .padding(6)
        }
    }
}

/// One row of the process table (also used, with `isHeader`, for the header).
private struct ProcessRow: View {
    let name: String
    let cpu: String
    let memory: String
    var isHeader = false

    var body: some View {
        HStack(spacing: 12) {
            Text(name)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(cpu)
                .frame(width: 70, alignment: .trailing)
            Text(memory)
                .frame(width: 90, alignment: .trailing)
        }
        .font(isHeader ? .caption.weight(.semibold) : .callout)
        .foregroundStyle(isHeader ? AnyShapeStyle(.secondary) : AnyShapeStyle(.primary))
        .monospacedDigit()
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
