import SwiftUI

/// The main window: a grid of metric cards and a live, sortable process table,
/// plus a placeholder for the chart that arrives next. Styled with `Theme`
/// (deep black, mint accents, DM Sans).
struct DashboardView: View {
    @ObservedObject var metrics: MetricsCollector
    @ObservedObject var processes: ProcessCollector
    @ObservedObject var history: HistoryStore

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 14)]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text("Dashboard")
                        .font(Theme.display)
                        .foregroundStyle(Theme.text)

                    LazyVGrid(columns: columns, spacing: 14) {
                        metricCard("CPU", metrics.latest?.cpuPercentText ?? "—", "cpu")
                        metricCard("Memory", metrics.latest?.memoryText ?? "—", "memorychip")
                        metricCard("Battery", metrics.latest?.batteryText ?? "—", "battery.100")
                        metricCard("Network", metrics.latest?.networkText ?? "—", "network")
                        metricCard("Storage", SystemInfo.diskText, "internaldrive")
                        metricCard("Uptime", SystemInfo.uptimeText, "clock")
                    }

                    chartPlaceholder
                    processSection
                }
                .padding(28)
                .font(Theme.body)
                .foregroundStyle(Theme.text)
            }
        }
        .frame(minWidth: 680, minHeight: 560)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .task {
            metrics.start()
            processes.start()
        }
    }

    // MARK: Cards

    private func metricCard(_ title: String, _ value: String, _ icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.accent)
                Text(title.uppercased())
                    .font(Theme.label)
                    .tracking(0.6)
                    .foregroundStyle(Theme.textDim)
            }
            Text(value)
                .font(Theme.font(22, .light))
                .foregroundStyle(Theme.text)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.border, lineWidth: 1))
    }

    private var chartPlaceholder: some View {
        surface {
            VStack(alignment: .leading, spacing: 12) {
                Text("CPU OVER TIME").font(Theme.label).tracking(0.6).foregroundStyle(Theme.textDim)
                Text("Live chart arrives next")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textDim)
                    .frame(maxWidth: .infinity, minHeight: 130)
            }
        }
    }

    // MARK: Process table

    private var processSection: some View {
        surface {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("TOP PROCESSES").font(Theme.label).tracking(0.6).foregroundStyle(Theme.textDim)
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

                VStack(spacing: 8) {
                    processRow("Process", "CPU", "RAM", header: true)
                    Divider().overlay(Theme.border)

                    if processes.processes.isEmpty {
                        Text("Sampling…")
                            .font(Theme.body)
                            .foregroundStyle(Theme.textDim)
                            .frame(maxWidth: .infinity, minHeight: 80)
                    } else {
                        ForEach(processes.sorted.prefix(12)) { process in
                            processRow(process.name, process.cpuPercentText, process.memoryText)
                        }
                    }
                }
            }
        }
    }

    private func processRow(_ name: String, _ cpu: String, _ ram: String, header: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(name)
                .font(header ? Theme.label : Theme.body)
                .foregroundStyle(header ? Theme.textDim : Theme.text)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(cpu)
                .font(header ? Theme.label : Theme.mono)
                .foregroundStyle(header ? Theme.textDim : Theme.accent)
                .frame(width: 60, alignment: .trailing)
            Text(ram)
                .font(header ? Theme.label : Theme.mono)
                .foregroundStyle(header ? Theme.textDim : Theme.text)
                .frame(width: 86, alignment: .trailing)
        }
    }

    // MARK: Building block

    private func surface<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.border, lineWidth: 1))
    }
}
