import SwiftUI
import Charts

/// The main window: a grid of metric cards, a live CPU chart, and a sortable
/// process table. Styled with `Theme` (deep black, mint accents, system font).
struct DashboardView: View {
    @ObservedObject var metrics: MetricsCollector
    @ObservedObject var processes: ProcessCollector
    @ObservedObject var history: HistoryStore
    @ObservedObject var usage: AppUsageTracker
    @ObservedObject var timeline: TimelineEngine
    @ObservedObject var devServers: DevServerCollector

    @State private var chartRange: HistoryStore.Range = .fiveMinutes

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

                    chartsBlock
                    timelineSection
                    processSection
                    devServersSection
                    usageSection
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
            devServers.start()
        }
        .onDisappear { devServers.stop() }
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

    private var chartsBlock: some View {
        let data = history.snapshots(in: chartRange)
        return surface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("ACTIVITY").font(Theme.label).tracking(0.6).foregroundStyle(Theme.textDim)
                    Spacer()
                    Picker("Range", selection: $chartRange) {
                        ForEach(HistoryStore.Range.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                if data.count < 2 {
                    Text("Collecting…")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity, minHeight: 150)
                } else {
                    miniChart("CPU  ·  %", data, domain: 0...100) { $0.cpuUsage * 100 }
                    Divider().overlay(Theme.border)
                    miniChart("MEMORY  ·  %", data, domain: 0...100) { $0.memoryFraction * 100 }
                    Divider().overlay(Theme.border)
                    miniChart("NETWORK ↓  ·  MB/s", data, domain: 0...networkMax(data)) {
                        Double($0.networkDownBytesPerSec) / 1_048_576
                    }
                }
            }
        }
    }

    private func miniChart(
        _ label: String,
        _ data: [SystemSnapshot],
        domain: ClosedRange<Double>,
        value: @escaping (SystemSnapshot) -> Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(Theme.font(11, .medium)).tracking(0.6).foregroundStyle(Theme.textDim)
            Chart(data) { snapshot in
                AreaMark(
                    x: .value("Time", snapshot.timestamp),
                    y: .value(label, value(snapshot))
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Theme.accent.opacity(0.28), Theme.accent.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.monotone)

                LineMark(
                    x: .value("Time", snapshot.timestamp),
                    y: .value(label, value(snapshot))
                )
                .foregroundStyle(Theme.accent)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 1.8))
            }
            .chartYScale(domain: domain)
            .chartYAxis {
                AxisMarks(position: .leading) {
                    AxisGridLine().foregroundStyle(Theme.border)
                    AxisValueLabel().foregroundStyle(Theme.textDim).font(Theme.font(9, .regular))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(Theme.border.opacity(0.5))
                    AxisValueLabel(format: .dateTime.hour().minute())
                        .foregroundStyle(Theme.textDim).font(Theme.font(9, .regular))
                }
            }
            .frame(height: 96)
        }
    }

    private func networkMax(_ data: [SystemSnapshot]) -> Double {
        let peak = data.map { Double($0.networkDownBytesPerSec) / 1_048_576 }.max() ?? 1
        return Swift.max(1, peak * 1.2)
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
                            processRow(
                                process.name,
                                process.cpuPercentText,
                                process.memoryText,
                                dev: process.isDeveloperTool
                            )
                        }
                    }
                }
            }
        }
    }

    private func processRow(_ name: String, _ cpu: String, _ ram: String, header: Bool = false, dev: Bool = false) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(dev ? Theme.accent : Color.clear)
                .frame(width: 6, height: 6)
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

    // MARK: Dev servers

    private var devServersSection: some View {
        surface {
            VStack(alignment: .leading, spacing: 12) {
                Text("DEV SERVERS").font(Theme.label).tracking(0.6).foregroundStyle(Theme.textDim)

                if devServers.servers.isEmpty {
                    Text("No local servers listening")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    VStack(spacing: 8) {
                        ForEach(devServers.servers) { server in
                            HStack(spacing: 12) {
                                Text(":\(String(server.port))")
                                    .font(Theme.mono)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 70, alignment: .leading)
                                Text(server.command)
                                    .font(Theme.body)
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text("pid \(String(server.pid))")
                                    .font(Theme.mono)
                                    .foregroundStyle(Theme.textDim)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Timeline

    private var timelineSection: some View {
        surface {
            VStack(alignment: .leading, spacing: 12) {
                Text("TIMELINE").font(Theme.label).tracking(0.6).foregroundStyle(Theme.textDim)

                if timeline.events.isEmpty {
                    Text("No events yet — Flux flags CPU spikes, low battery, high memory, and network spikes")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    VStack(spacing: 10) {
                        ForEach(timeline.events.prefix(10)) { event in
                            HStack(spacing: 10) {
                                Image(systemName: icon(for: event.kind))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.message).font(Theme.body).foregroundStyle(Theme.text)
                                    Text(event.timestamp, format: .dateTime.hour().minute())
                                        .font(Theme.font(11, .regular)).foregroundStyle(Theme.textDim)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    private func icon(for kind: TimelineEngine.Event.Kind) -> String {
        switch kind {
        case .highCPU: return "cpu"
        case .highMemory: return "memorychip"
        case .lowBattery: return "battery.25"
        case .storageJump: return "internaldrive"
        case .networkSpike: return "network"
        case .longRunningProcess: return "clock"
        }
    }

    // MARK: App usage

    private var usageSection: some View {
        let items = history.usageToday(including: usage.current)
        return surface {
            VStack(alignment: .leading, spacing: 12) {
                Text("TODAY'S APP USAGE").font(Theme.label).tracking(0.6).foregroundStyle(Theme.textDim)

                if items.isEmpty {
                    Text("No activity tracked yet")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textDim)
                        .frame(maxWidth: .infinity, minHeight: 60)
                } else {
                    let peak = items.first?.duration ?? 1
                    VStack(spacing: 10) {
                        ForEach(items.prefix(8)) { item in
                            usageRow(item, peak: peak)
                        }
                    }
                }
            }
        }
    }

    private func usageRow(_ item: AppUsage, peak: TimeInterval) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(item.appName).font(Theme.body).foregroundStyle(Theme.text).lineLimit(1)
                Spacer()
                Text(item.durationText).font(Theme.mono).foregroundStyle(Theme.textDim)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.border)
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * CGFloat(item.duration / max(1, peak)))
                }
            }
            .frame(height: 4)
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
