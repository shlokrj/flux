import SwiftUI
import AppKit

/// The dropdown panel shown when the menu bar item is clicked: a compact
/// overview plus actions.
struct MenuBarView: View {
    @ObservedObject var metrics: MetricsCollector
    var processes: ProcessCollector
    @ObservedObject var usage: AppUsageTracker
    let openDashboard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Flux")
                .font(.system(.headline, design: .default, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.bottom, 8)

            metricRow("CPU", icon: "cpu", value: metrics.latest?.cpuPercentText ?? "—")
            metricRow("Memory", icon: "memorychip", value: metrics.latest?.memoryText ?? "—")
            metricRow("Battery", icon: "battery.100", value: metrics.latest?.batteryText ?? "—")
            metricRow("Network", icon: "network", value: metrics.latest?.networkText ?? "—")
            metricRow("Active app", icon: "app.fill", value: usage.current?.appName ?? "—")

            Divider().overlay(Theme.border).padding(.vertical, 8)

            actionButton("Open Dashboard", icon: "rectangle.on.rectangle") {
                openDashboard()
            }
            actionButton("Quit Flux", icon: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 258)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .task {
            metrics.start()
            processes.start()
        }
    }

    private func metricRow(_ title: String, icon: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 16)
            Text(title)
                .font(Theme.body)
                .foregroundStyle(Theme.textDim)
            Spacer(minLength: 8)
            Text(value)
                .font(Theme.mono)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, minHeight: 27)
        .padding(.horizontal, 4)
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
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
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
