import SwiftUI
import Charts

/// The main window: live metrics, activity charts, a derived timeline, app
/// usage, running processes, and local development servers.
struct DashboardView: View {
    private enum ActivityMetric: String, CaseIterable, Identifiable {
        case cpu = "CPU"
        case memory = "Memory"
        case network = "Network"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .cpu: return "cpu"
            case .memory: return "memorychip"
            case .network: return "arrow.down"
            }
        }
    }

    private struct MetricItem: Identifiable {
        let title: String
        let value: String
        let icon: String

        var id: String { title }
    }

    @ObservedObject var metrics: MetricsCollector
    @ObservedObject var processes: ProcessCollector
    @ObservedObject var history: HistoryStore
    @ObservedObject var usage: AppUsageTracker
    @ObservedObject var timeline: TimelineEngine
    @ObservedObject var devServers: DevServerCollector

    @State private var chartRange: HistoryStore.Range = .fiveMinutes
    @State private var activityMetric: ActivityMetric = .cpu

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    overviewRow
                    insightsRow
                    detailsRow
                }
                .padding(20)
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

    // MARK: Overview

    private var header: some View {
        HStack(alignment: .center) {
            Text("Flux")
                .font(.system(.title2, design: .default, weight: .semibold))

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 7, height: 7)
                Text("Live")
                    .font(Theme.secondary.weight(.medium))
                    .foregroundStyle(Theme.textDim)
            }
        }
    }

    private var metricItems: [MetricItem] {
        [
            MetricItem(title: "CPU", value: metrics.latest?.cpuPercentText ?? "—", icon: "cpu"),
            MetricItem(title: "Memory", value: metrics.latest?.memoryText ?? "—", icon: "memorychip"),
            MetricItem(title: "Battery", value: metrics.latest?.batteryText ?? "—", icon: "battery.100"),
            MetricItem(title: "Network", value: metrics.latest?.networkText ?? "—", icon: "network"),
            MetricItem(title: "Storage", value: SystemInfo.diskText, icon: "internaldrive"),
            MetricItem(title: "Uptime", value: SystemInfo.uptimeText, icon: "clock")
        ]
    }

    private var overviewRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                systemSummary
                    .frame(minWidth: 260, idealWidth: 280, maxWidth: 300)
                activityBlock
                    .frame(minWidth: 420, maxWidth: .infinity)
            }

            VStack(spacing: 12) {
                systemSummary
                activityBlock
            }
        }
    }

    private var systemSummary: some View {
        surface {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeader("System", icon: "gauge.with.dots.needle.50percent")

                VStack(spacing: 0) {
                    ForEach(Array(metricItems.enumerated()), id: \.element.id) { index, item in
                        metricRow(item)

                        if index < metricItems.count - 1 {
                            Divider().overlay(Theme.border.opacity(0.7))
                        }
                    }
                }
            }
        }
    }

    private func metricRow(_ item: MetricItem) -> some View {
        HStack(spacing: 9) {
            Image(systemName: item.icon)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(Theme.accent)
                .frame(width: 16)
            Text(item.title)
                .foregroundStyle(Theme.textDim)
            Spacer(minLength: 8)
            Text(item.value)
                .font(Theme.mono)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.vertical, 7)
    }

    private var activityBlock: some View {
        let data = history.snapshots(in: chartRange)
        return surface {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Activity", icon: "chart.xyaxis.line") {
                    Picker("Range", selection: $chartRange) {
                        ForEach(HistoryStore.Range.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                Picker("Metric", selection: $activityMetric) {
                    ForEach(ActivityMetric.allCases) { metric in
                        Label(metric.rawValue, systemImage: metric.icon).tag(metric)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)

                if data.count < 2 {
                    emptyState("Collecting system activity…", icon: "waveform.path.ecg")
                        .frame(height: 180)
                } else {
                    activityChart(data)
                }
            }
        }
    }

    private func activityChart(_ data: [SystemSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(activityMetric.rawValue)
                    .font(Theme.label)
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Text(activityCurrentText)
                    .font(Theme.mono.weight(.medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Chart(data) { snapshot in
                AreaMark(
                    x: .value("Time", snapshot.timestamp),
                    y: .value(activityMetric.rawValue, activityValue(snapshot))
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
                    y: .value(activityMetric.rawValue, activityValue(snapshot))
                )
                .foregroundStyle(Theme.accent)
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
            .chartYScale(domain: activityDomain(data))
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(Theme.border.opacity(0.7))
                    AxisValueLabel().foregroundStyle(Theme.textDim).font(Theme.secondary)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 2)) {
                    AxisGridLine().foregroundStyle(Theme.border.opacity(0.4))
                    AxisValueLabel(format: .dateTime.hour().minute())
                        .foregroundStyle(Theme.textDim).font(Theme.secondary)
                }
            }
            .chartXScale(range: .plotDimension(padding: 6))
            .frame(height: 160)
        }
        .padding(.top, 2)
    }

    private var activityCurrentText: String {
        switch activityMetric {
        case .cpu:
            return metrics.latest?.cpuPercentText ?? "—"
        case .memory:
            return "\(Int((metrics.latest?.memoryFraction ?? 0) * 100))%"
        case .network:
            return metrics.latest?.networkText.components(separatedBy: " ").prefix(3).joined(separator: " ") ?? "—"
        }
    }

    private func activityValue(_ snapshot: SystemSnapshot) -> Double {
        switch activityMetric {
        case .cpu: return snapshot.cpuUsage * 100
        case .memory: return snapshot.memoryFraction * 100
        case .network: return Double(snapshot.networkDownBytesPerSec) / 1_048_576
        }
    }

    private func activityDomain(_ data: [SystemSnapshot]) -> ClosedRange<Double> {
        switch activityMetric {
        case .cpu, .memory: return 0...100
        case .network: return 0...networkMax(data)
        }
    }

    private func networkMax(_ data: [SystemSnapshot]) -> Double {
        let peak = data.map { Double($0.networkDownBytesPerSec) / 1_048_576 }.max() ?? 1
        return Swift.max(1, peak * 1.2)
    }

    // MARK: Process table

    private var detailsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                processSection
                    .frame(minWidth: 500, maxWidth: .infinity)
                devServersSection
                    .frame(minWidth: 290, idealWidth: 330, maxWidth: 380)
            }

            VStack(spacing: 12) {
                processSection
                devServersSection
            }
        }
    }

    private var processSection: some View {
        surface {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Top processes", icon: "list.bullet.rectangle") {
                    Picker("Sort", selection: $processes.sortKey) {
                        ForEach(ProcessCollector.SortKey.allCases) { key in
                            Text(key.rawValue).tag(key)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                VStack(spacing: 0) {
                    processRow("Process", "CPU", "RAM", header: true)
                        .padding(.bottom, 6)

                    if processes.processes.isEmpty {
                        emptyState("Sampling running processes…", icon: "gearshape.2")
                            .frame(minHeight: 100)
                    } else {
                        ForEach(processes.sorted.prefix(8)) { process in
                            Divider().overlay(Theme.border.opacity(0.6))
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
                .frame(width: 72, alignment: .trailing)
            Text(ram)
                .font(header ? Theme.label : Theme.mono)
                .foregroundStyle(header ? Theme.textDim : Theme.text)
                .frame(width: 96, alignment: .trailing)
        }
        .padding(.vertical, header ? 3 : 7)
    }

    // MARK: Dev servers

    private var devServersSection: some View {
        let servers = Array(devServers.servers.prefix(6))
        return surface {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Development servers", icon: "server.rack")

                if servers.isEmpty {
                    emptyState("No local servers are listening", icon: "network.slash")
                        .frame(minHeight: 72)
                } else {
                    VStack(spacing: 0) {
                        ForEach(servers) { server in
                            HStack(spacing: 9) {
                                Text(":\(String(server.port))")
                                    .font(Theme.mono)
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 58, alignment: .leading)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(server.command)
                                        .font(Theme.body)
                                        .foregroundStyle(Theme.text)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    if let project = server.projectName {
                                        HStack(spacing: 4) {
                                            Image(systemName: "folder").font(.system(size: 9))
                                            Text(server.gitBranch.map { "\(project) · \($0)" } ?? project)
                                                .lineLimit(1)
                                        }
                                        .font(Theme.secondary)
                                        .foregroundStyle(Theme.textDim)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 7)

                            if server.id != servers.last?.id {
                                Divider().overlay(Theme.border.opacity(0.6))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Timeline

    private var insightsRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                timelineSection.frame(minWidth: 360, maxWidth: .infinity)
                usageSection.frame(minWidth: 360, maxWidth: .infinity)
            }

            VStack(spacing: 12) {
                timelineSection
                usageSection
            }
        }
    }

    private var timelineSection: some View {
        surface {
            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Timeline", icon: "clock.arrow.circlepath")

                if timeline.events.isEmpty {
                    emptyState(
                        "Notable CPU, memory, battery, and network changes will appear here.",
                        icon: "sparkles"
                    )
                    .frame(minHeight: 72)
                } else {
                    VStack(spacing: 0) {
                        ForEach(timeline.events.prefix(6)) { event in
                            HStack(spacing: 10) {
                                Image(systemName: icon(for: event.kind))
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(event.message).font(Theme.body).foregroundStyle(Theme.text)
                                    Text(event.timestamp, format: .dateTime.hour().minute())
                                        .font(Theme.secondary).foregroundStyle(Theme.textDim)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)

                            if event.id != timeline.events.prefix(6).last?.id {
                                Divider().overlay(Theme.border.opacity(0.6))
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
                sectionHeader("Today's app usage", icon: "hourglass")

                if items.isEmpty {
                    emptyState("App activity will appear as you work", icon: "app.dashed")
                        .frame(minHeight: 72)
                } else {
                    let peak = items.first?.duration ?? 1
                    VStack(spacing: 9) {
                        ForEach(items.prefix(6)) { item in
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
                    Capsule().fill(Theme.border.opacity(0.7))
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * CGFloat(item.duration / max(1, peak)))
                }
            }
            .frame(height: 3)
        }
    }

    // MARK: Building block

    private func sectionHeader<Trailing: View>(
        _ title: String,
        icon: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 16)
            Text(title)
                .font(Theme.sectionTitle)
            Spacer()
            trailing()
        }
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        sectionHeader(title, icon: icon) { EmptyView() }
    }

    private func emptyState(_ message: String, icon: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(Theme.accent.opacity(0.8))
            Text(message)
                .font(Theme.body)
                .foregroundStyle(Theme.textDim)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func surface<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }
}
