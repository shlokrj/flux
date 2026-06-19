import SwiftUI
import AppKit

/// The text shown in the menu bar itself: live CPU and RAM. This view is always
/// present once the app launches, so it also kicks off metric sampling.
struct MenuBarLabel: View {
    @ObservedObject var metrics: MetricsCollector
    var history: HistoryStore

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "gauge.medium")
            Text(text)
        }
        // Always present once the app launches, so this is where sampling +
        // history recording kick off (whether or not the dashboard is open).
        .task { metrics.start(recording: history) }
    }

    private var text: String {
        guard let latest = metrics.latest else { return "Flux" }
        return "\(latest.cpuPercentText) · \(latest.memoryPercentText)"
    }
}

/// The dropdown panel shown when the menu bar item is clicked: a compact
/// overview plus actions.
struct MenuBarView: View {
    @ObservedObject var metrics: MetricsCollector
    @ObservedObject var processes: ProcessCollector
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("FLUX")
                .font(Theme.font(12, .medium))
                .tracking(3)
                .foregroundStyle(Theme.accent)
                .padding(.bottom, 12)

            row("CPU", metrics.latest?.cpuPercentText ?? "—")
            row("Memory", metrics.latest?.memoryText ?? "—")
            row("Battery", metrics.latest?.batteryText ?? "—")
            row("Network", metrics.latest?.networkText ?? "—")

            Divider().overlay(Theme.border).padding(.vertical, 10)

            menuButton("Open Dashboard", "rectangle.on.rectangle") { openWindow(id: "dashboard") }
            menuButton("Quit Flux", "power") { NSApplication.shared.terminate(nil) }
        }
        .padding(14)
        .frame(width: 250)
        .background(Theme.background)
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .task {
            metrics.start()
            processes.start()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(Theme.body).foregroundStyle(Theme.textDim)
            Spacer()
            Text(value).font(Theme.mono).foregroundStyle(Theme.text)
        }
        .padding(.vertical, 3)
    }

    private func menuButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon).font(.system(size: 12)).foregroundStyle(Theme.accent)
                Text(title).font(Theme.body).foregroundStyle(Theme.text)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
    }
}
