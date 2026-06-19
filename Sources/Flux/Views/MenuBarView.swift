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
        VStack(alignment: .leading, spacing: 10) {
            row("CPU", metrics.latest?.cpuPercentText ?? "—")
            row("Memory", metrics.latest?.memoryText ?? "—")
            row("Battery", metrics.latest?.batteryText ?? "—")
            row("Network", metrics.latest?.networkText ?? "—")
            row("Top App", metrics.latest?.activeAppBundleID ?? "—")

            Divider()

            Button("Open Dashboard") { openWindow(id: "dashboard") }
            Button("Quit Flux") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 260)
        .task {
            metrics.start()
            processes.start()
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).monospacedDigit()
        }
    }
}
