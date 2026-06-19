import SwiftUI
import AppKit

/// The stable, low-noise label shown in the menu bar. It also owns the task
/// that starts Flux's long-lived collection pipeline.
struct MenuBarLabel: View {
    var metrics: MetricsCollector
    var processes: ProcessCollector
    var history: HistoryStore
    var usage: AppUsageTracker
    var timeline: TimelineEngine

    var body: some View {
        Text("Flux")
        // Always present once the app launches, so this is where sampling,
        // history recording, timeline analysis, process enumeration, and
        // app-usage tracking kick off (whether or not the dashboard is open).
        .task {
            timeline.attach(history)
            usage.start(recording: history)
            processes.start()
            metrics.attachSources(processes: processes, usage: usage)
            metrics.start(recording: history, timeline: timeline)
        }
    }
}

/// The dropdown panel shown when the menu bar item is clicked: a compact
/// overview plus actions.
struct MenuBarView: View {
    @ObservedObject var metrics: MetricsCollector
    var processes: ProcessCollector
    @ObservedObject var usage: AppUsageTracker
    @Environment(\.openWindow) private var openWindow

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Flux")
                    .font(.system(.title3, design: .default, weight: .semibold))

                Spacer()

                HStack(spacing: 5) {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)
                    Text("Live")
                        .font(Theme.secondary.weight(.medium))
                        .foregroundStyle(Theme.textDim)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Theme.surfaceRaised.opacity(0.55), in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
            }
            .padding(.bottom, 14)

            LazyVGrid(columns: columns, spacing: 8) {
                metricTile(
                    "CPU",
                    icon: "cpu",
                    value: metrics.latest?.cpuPercentText ?? "—",
                    detail: metrics.latest?.topProcessName.map { "Top · \($0)" } ?? "System usage"
                )
                metricTile(
                    "Memory",
                    icon: "memorychip",
                    value: metrics.latest?.memoryPercentText ?? "—",
                    detail: metrics.latest?.memoryText ?? "Collecting…"
                )
                metricTile(
                    "Battery",
                    icon: "battery.100",
                    value: metrics.latest?.batteryText ?? "—",
                    detail: "Charge level"
                )
                metricTile(
                    "Network",
                    icon: "network",
                    value: metrics.latest.map { "↓ \($0.networkDownText)" } ?? "—",
                    detail: metrics.latest.map { "↑ \($0.networkUpText)" } ?? "Collecting…"
                )
            }

            HStack(spacing: 9) {
                Image(systemName: "app.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textDim)
                    .frame(width: 16)
                Text("Active app")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textDim)
                Spacer()
                Text(usage.current?.appName ?? "—")
                    .font(Theme.body.weight(.medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 4)
            .padding(.top, 13)

            Divider().overlay(Theme.border).padding(.vertical, 12)

            actionButton("Open Dashboard", icon: "rectangle.on.rectangle") {
                openWindow(id: "dashboard")
            }
            actionButton("Quit Flux", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(16)
        .frame(width: 300)
        .background(Theme.background)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .task {
            metrics.start()
            processes.start()
        }
    }

    private func metricTile(_ title: String, icon: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 14)
                Text(title)
                    .font(Theme.label)
                    .foregroundStyle(Theme.textDim)
            }

            Spacer(minLength: 8)

            Text(value)
                .font(.system(.title3, design: .default, weight: .semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(detail)
                .font(Theme.secondary)
                .foregroundStyle(Theme.textDim)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .padding(11)
        .frame(maxWidth: .infinity, minHeight: 92, maxHeight: 92, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        MenuBarActionButton(title: title, icon: icon, action: action)
    }
}

private struct MenuBarActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 18, alignment: .center)
                Text(title)
                    .font(Theme.body.weight(.medium))
                    .foregroundStyle(Theme.text)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
            .background(
                isHovering ? Theme.surfaceRaised.opacity(0.7) : Color.clear,
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.1)) {
                isHovering = hovering
            }
        }
    }
}
